import common from '@ohos.app.ability.common';
import { NetworkHttpMethod, NetworkService, NetworkWebSocket } from '../../services/NetworkService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HaEntityParser } from '../../services/HaEntityParser';
import { AuthService } from '../../services/AuthService';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { MobileAppIdentityStore } from '../../services/MobileAppIdentityStore';
import { ServerManager } from '../../services/ServerManager';
import { StorageService, StoredServerInfo } from '../../services/StorageService';
import { CardFormService } from '../cards/CardFormService';
import { CardRuntimeRepository } from '../cards/CardRuntimeRepository';
import { HomeAssistantNotificationAdapter } from '../notifications/HomeAssistantNotificationAdapter';
import { NotificationService } from '../notifications/NotificationService';
import { HarmonyPushTokenService } from '../pushkit/HarmonyPushTokenService';
import { MobileAppRegistrationService } from '../registration/MobileAppRegistrationService';
import { LongRunningTaskService } from './LongRunningTaskService';

const DOMAIN = 0x0000;
const TAG = 'HABackgroundConnection';

type JsonValue = Object | string | number | boolean | null;
type JsonRecord = Record<string, JsonValue>;

interface BackgroundConnection {
  serverInstanceId: string;
  baseUrl: string;
  accessToken: string;
  refreshToken: string;
}

interface WebhookPostResult {
  responseCode: number;
  body: string;
}

interface PushRegistrationData {
  app_data: Record<string, string | number | boolean>;
}

interface PushRegistrationRequest {
  type: string;
  data: PushRegistrationData;
}

interface SupportedFeatures {
  coalesce_messages: number;
}

interface SupportedFeaturesRequest {
  id: number;
  type: string;
  features: SupportedFeatures;
}

export class HaBackgroundConnectionService {
  private static client: NetworkWebSocket | undefined = undefined;
  private static context: common.Context | undefined = undefined;
  private static running = false;
  private static subscribed = false;
  private static pushSubscribed = false;
  private static initialRefreshDone = false;
  private static stopping = false;
  private static reconnectTimer: number = -1;
  private static messageId = 1;
  private static pushSubscribeId = -1;
  private static serverInstanceId: string = '';
  private static requiresLongRunning = false;
  private static subscribedEntityIds: string[] = [];
  private static subscribedEntityIdsLoadedAt = 0;

  static async start(context: common.Context, requiresLongRunning: boolean = false): Promise<void> {
    HaBackgroundConnectionService.context = context;
    HaBackgroundConnectionService.requiresLongRunning = requiresLongRunning;
    if (HaBackgroundConnectionService.running) {
      return;
    }
    if (requiresLongRunning) {
      await LongRunningTaskService.ensureActive(context as common.UIAbilityContext);
    }
    const connection = await HaBackgroundConnectionService.resolveConnection(context);
    if (connection.baseUrl.length === 0 || connection.accessToken.length === 0) {
      hilog.warn(DOMAIN, TAG, 'skip start: missing connection');
      return;
    }
    hilog.info(DOMAIN, TAG, 'start websocket, requiresLongRunning=%{public}s', requiresLongRunning ? 'true' : 'false');
    HaBackgroundConnectionService.stopping = false;
    HaBackgroundConnectionService.running = true;
    HaBackgroundConnectionService.initialRefreshDone = false;
    HaBackgroundConnectionService.serverInstanceId = connection.serverInstanceId;
    await HaBackgroundConnectionService.reloadBoundEntityIds(context, connection.serverInstanceId);
    HaBackgroundConnectionService.connect(connection.baseUrl, connection.accessToken);
  }

  static async ensureRunning(context: common.Context, requiresLongRunning: boolean = false): Promise<void> {
    if (!HaBackgroundConnectionService.running ||
      !HaBackgroundConnectionService.client ||
      !HaBackgroundConnectionService.subscribed ||
      !HaBackgroundConnectionService.pushSubscribed ||
      HaBackgroundConnectionService.requiresLongRunning !== requiresLongRunning) {
      await HaBackgroundConnectionService.restart(context, requiresLongRunning);
    }
  }

  static async restart(context: common.Context, requiresLongRunning: boolean = false): Promise<void> {
    HaBackgroundConnectionService.stop();
    await HaBackgroundConnectionService.start(context, requiresLongRunning);
  }

  static stop(): void {
    HaBackgroundConnectionService.stopping = true;
    HaBackgroundConnectionService.running = false;
    HaBackgroundConnectionService.subscribed = false;
    HaBackgroundConnectionService.pushSubscribed = false;
    HaBackgroundConnectionService.initialRefreshDone = false;
    HaBackgroundConnectionService.serverInstanceId = '';
    HaBackgroundConnectionService.requiresLongRunning = false;
    HaBackgroundConnectionService.subscribedEntityIds = [];
    HaBackgroundConnectionService.subscribedEntityIdsLoadedAt = 0;
    HaBackgroundConnectionService.clearReconnect();
    const current = HaBackgroundConnectionService.client;
    HaBackgroundConnectionService.client = undefined;
    if (current) {
      current.close().catch((): void => {});
    }
  }

  private static connect(baseUrl: string, accessToken: string): void {
    const client = NetworkService.createWebSocket();
    HaBackgroundConnectionService.client = client;
    HaBackgroundConnectionService.subscribed = false;
    HaBackgroundConnectionService.pushSubscribed = false;
    client.on('message', (err: Error, data: string | ArrayBuffer): void => {
      if (err) {
        HaBackgroundConnectionService.scheduleReconnect();
        return;
      }
      HaBackgroundConnectionService.handleMessage(client, baseUrl, accessToken, data);
    });
    client.on('error', (): void => {
      HaBackgroundConnectionService.scheduleReconnect();
    });
    client.on('close', (): void => {
      HaBackgroundConnectionService.scheduleReconnect();
    });
    client.connect(HaBackgroundConnectionService.webSocketUrl(baseUrl), {
      pingInterval: 60,
      pongTimeout: 30
    }).catch((err: Error): void => {
      hilog.warn(DOMAIN, TAG, 'connect failed: %{public}s', err.message);
      HaBackgroundConnectionService.scheduleReconnect();
    });
  }

  private static handleMessage(client: NetworkWebSocket, baseUrl: string, accessToken: string, data: string | ArrayBuffer): void {
    const text = typeof data === 'string' ? data : '';
    if (text.length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(text) as Object | Array<Object>;
      if (Array.isArray(parsed)) {
        for (let i = 0; i < parsed.length; i++) {
          const message = HaBackgroundConnectionService.jsonRecord(parsed[i]);
          if (message) {
            HaBackgroundConnectionService.handleMessageRecord(client, baseUrl, accessToken, message);
          }
        }
        return;
      }
      const message = HaBackgroundConnectionService.jsonRecord(parsed);
      if (message) {
        HaBackgroundConnectionService.handleMessageRecord(client, baseUrl, accessToken, message);
      }
    } catch (err) {
      const error = err as Error;
      hilog.warn(DOMAIN, TAG, 'message parse failed: %{public}s', error.message);
    }
  }

  private static handleMessageRecord(
    client: NetworkWebSocket,
    baseUrl: string,
    accessToken: string,
    message: JsonRecord
  ): void {
    const type = message['type'];
    if (type === 'auth_required') {
      client.send(JSON.stringify({
        'type': 'auth',
        'access_token': accessToken
      })).catch((): void => {
        HaBackgroundConnectionService.scheduleReconnect();
      });
      return;
    }
    if (type === 'auth_ok') {
      HaBackgroundConnectionService.sendSupportedFeatures(client);
      HaBackgroundConnectionService.subscribeStateChanged(client);
      HaBackgroundConnectionService.updatePushRegistration(baseUrl).then((needsReregistration: boolean): void => {
        if (needsReregistration) {
          HaBackgroundConnectionService.reregisterMobileAppForPush().finally((): void => {
            HaBackgroundConnectionService.subscribePushNotifications(client);
          });
          return;
        }
        HaBackgroundConnectionService.subscribePushNotifications(client);
      }).catch((err: Error): void => {
        hilog.warn(DOMAIN, TAG, 'push registration update failed: %{public}s', err.message);
        HaBackgroundConnectionService.subscribePushNotifications(client);
      });
      return;
    }
    if (type === 'result') {
      HaBackgroundConnectionService.handleResult(message);
      return;
    }
    if (type === 'auth_invalid') {
      hilog.warn(DOMAIN, TAG, 'auth invalid');
      HaBackgroundConnectionService.stop();
      return;
    }
    if (type === 'event') {
      const event = HaBackgroundConnectionService.objectField(message, 'event');
      const pushEvent = event ? HaBackgroundConnectionService.pushNotificationPayload(event) : null;
      if (pushEvent) {
        HaBackgroundConnectionService.handlePushNotificationEvent(client, pushEvent).catch((err: Error): void => {
          hilog.warn(DOMAIN, TAG, 'push notification failed: %{public}s', err.message);
        });
        return;
      }
      HaBackgroundConnectionService.handleStateEvent(message).catch((err: Error): void => {
        hilog.warn(DOMAIN, TAG, 'state event failed: %{public}s', err.message);
      });
    }
  }

  private static subscribeStateChanged(client: NetworkWebSocket): void {
    client.send(JSON.stringify({
      'id': HaBackgroundConnectionService.nextId(),
      'type': 'subscribe_events',
      'event_type': 'state_changed'
    })).catch((): void => {
      HaBackgroundConnectionService.scheduleReconnect();
    });
    HaBackgroundConnectionService.subscribed = true;
    HaBackgroundConnectionService.refreshRegisteredFormsOnce();
  }

  private static sendSupportedFeatures(client: NetworkWebSocket): void {
    const request: SupportedFeaturesRequest = {
      id: HaBackgroundConnectionService.nextId(),
      type: 'supported_features',
      features: {
        coalesce_messages: 1
      }
    };
    client.send(JSON.stringify(request)).catch((): void => {});
  }

  private static subscribePushNotifications(client: NetworkWebSocket): void {
    const webhookId = AppStorage.get<string>('haWebhookId') ?? '';
    if (webhookId.trim().length === 0) {
      hilog.warn(DOMAIN, TAG, 'skip push notification channel: missing webhook id');
      HaBackgroundConnectionService.pushSubscribed = false;
      return;
    }
    const id = HaBackgroundConnectionService.nextId();
    HaBackgroundConnectionService.pushSubscribeId = id;
    hilog.info(DOMAIN, TAG, 'subscribe push notification channel');
    client.send(JSON.stringify({
      'id': id,
      'type': 'mobile_app/push_notification_channel',
      'webhook_id': webhookId.trim(),
      'support_confirm': true
    })).then((): void => {
      HaBackgroundConnectionService.pushSubscribed = true;
    }).catch((): void => {
      HaBackgroundConnectionService.pushSubscribed = false;
      HaBackgroundConnectionService.scheduleReconnect();
    });
  }

  private static handleResult(message: JsonRecord): void {
    const rawId = message['id'];
    const id = typeof rawId === 'number' ? rawId : -1;
    if (id !== HaBackgroundConnectionService.pushSubscribeId) {
      return;
    }
    const success = message['success'] === true;
    if (success) {
      HaBackgroundConnectionService.pushSubscribed = true;
      hilog.info(DOMAIN, TAG, 'push notification channel subscribed');
      return;
    }
    const error = HaBackgroundConnectionService.objectField(message, 'error');
    hilog.warn(DOMAIN, TAG, 'push notification channel rejected: %{public}s', JSON.stringify(error ?? message));
    HaBackgroundConnectionService.pushSubscribed = false;
  }

  private static async updatePushRegistration(baseUrl: string): Promise<boolean> {
    const webhookId = AppStorage.get<string>('haWebhookId') ?? '';
    if (webhookId.trim().length === 0) {
      return false;
    }
    const urls = HaBackgroundConnectionService.webhookUrls(baseUrl, webhookId.trim());
    let lastError = '';
    const pushKitToken = await HarmonyPushTokenService.ensureToken();
    const body: PushRegistrationRequest = {
      type: 'update_registration',
      data: {
        app_data: MobileAppRegistrationService.appData(pushKitToken)
      }
    };
    for (let i = 0; i < urls.length; i++) {
      const result = await HaBackgroundConnectionService.postWebhook(urls[i], body);
      if (result.responseCode >= 200 && result.responseCode < 300) {
        if (result.body.trim().length === 0) {
          hilog.warn(DOMAIN, TAG, 'push registration returned empty body, reregistering mobile app');
          return true;
        }
        hilog.info(DOMAIN, TAG, 'push registration updated');
        return false;
      }
      lastError = `${result.responseCode}:${result.body}`;
    }
    throw new Error(lastError.length > 0 ? lastError : 'update_registration failed');
  }

  private static async reregisterMobileAppForPush(): Promise<void> {
    const context = HaBackgroundConnectionService.context;
    if (!context || HaBackgroundConnectionService.serverInstanceId.length === 0) {
      return;
    }
    const active = await ServerManager.getActiveServer(context);
    if (!active || active.id !== HaBackgroundConnectionService.serverInstanceId ||
      !StorageService.hasLogin(active.info)) {
      return;
    }
    const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, active.id);
    if (!policy.allowed || policy.baseUrl.length === 0) {
      return;
    }
    await HaBackgroundConnectionService.ensureMobileAppRegistration(context, active.id, active.info, true, policy.baseUrl);
  }

  private static refreshRegisteredFormsOnce(): void {
    if (HaBackgroundConnectionService.initialRefreshDone) {
      return;
    }
    const context = HaBackgroundConnectionService.context;
    if (!context) {
      return;
    }
    HaBackgroundConnectionService.initialRefreshDone = true;
    CardFormService.refreshRegisteredForms(context).catch((err: Error): void => {
      hilog.warn(DOMAIN, TAG, 'initial card refresh failed: %{public}s', err.message);
    });
  }

  private static async handleStateEvent(message: JsonRecord): Promise<void> {
    const context = HaBackgroundConnectionService.context;
    if (!context) {
      return;
    }
    const event = HaBackgroundConnectionService.objectField(message, 'event');
    const data = event ? HaBackgroundConnectionService.objectField(event, 'data') : null;
    if (!data) {
      return;
    }
    const rawEntityId = data['entity_id'];
    const newState = HaBackgroundConnectionService.objectField(data, 'new_state');
    if (typeof rawEntityId !== 'string' || rawEntityId.length === 0 || !newState) {
      return;
    }
    if (!HaBackgroundConnectionService.isBoundEntity(rawEntityId) &&
      !await HaBackgroundConnectionService.reloadAndCheckBoundEntity(context, rawEntityId)) {
      return;
    }
    if (rawEntityId.startsWith('light.')) {
      await HaBackgroundConnectionService.syncLight(context, rawEntityId, newState);
      return;
    }
    if (rawEntityId.startsWith('media_player.')) {
      await HaBackgroundConnectionService.syncMedia(context, rawEntityId, newState);
      return;
    }
    if (rawEntityId.startsWith('camera.') || rawEntityId.startsWith('image.')) {
      await HaBackgroundConnectionService.syncCamera(context, rawEntityId, newState);
      return;
    }
    if (rawEntityId.startsWith('climate.')) {
      await HaBackgroundConnectionService.syncClimate(context, rawEntityId, newState);
    }
  }

  private static async handlePushNotificationEvent(client: NetworkWebSocket, event: JsonRecord): Promise<void> {
    const context = HaBackgroundConnectionService.context;
    if (!context) {
      return;
    }
    const payload = HomeAssistantNotificationAdapter.fromPayload(
      event,
      'websocket',
      HaBackgroundConnectionService.serverInstanceId
    );
    if (!payload) {
      return;
    }
    await NotificationService.publishHomeAssistantNotification(context, payload);
    const confirmId = HaBackgroundConnectionService.stringField(event, 'hass_confirm_id');
    if (confirmId.length > 0) {
      HaBackgroundConnectionService.confirmPushNotification(client, confirmId);
    }
  }

  private static confirmPushNotification(client: NetworkWebSocket, confirmId: string): void {
    const webhookId = AppStorage.get<string>('haWebhookId') ?? '';
    if (webhookId.trim().length === 0) {
      return;
    }
    client.send(JSON.stringify({
      'id': HaBackgroundConnectionService.nextId(),
      'type': 'mobile_app/push_notification_confirm',
      'webhook_id': webhookId.trim(),
      'confirm_id': confirmId
    })).catch((err: Error): void => {
      hilog.warn(DOMAIN, TAG, 'push notification confirm failed: %{public}s', err.message);
    });
  }

  private static pushNotificationPayload(event: JsonRecord): JsonRecord | null {
    if (HaBackgroundConnectionService.hasPushNotificationFields(event)) {
      return event;
    }
    const data = HaBackgroundConnectionService.objectField(event, 'data');
    if (data && HaBackgroundConnectionService.hasPushNotificationFields(data)) {
      return data;
    }
    return null;
  }

  private static hasPushNotificationFields(value: JsonRecord): boolean {
    const message = value['message'];
    const title = value['title'];
    const body = value['body'];
    const confirmId = value['hass_confirm_id'];
    const aps = value['aps'];
    const notification = value['notification'];
    return typeof message === 'string' || typeof title === 'string' || typeof body === 'string' ||
      typeof confirmId === 'string' || (aps !== null && typeof aps === 'object') ||
      (notification !== null && typeof notification === 'object');
  }

  private static async syncLight(context: common.Context, entityId: string, newState: JsonRecord): Promise<void> {
    const rawState = newState['state'];
    const state = typeof rawState === 'string' && (rawState === 'on' || rawState === 'off') ? rawState : 'unknown';
    await CardRuntimeRepository.syncLightState(context, entityId, state);
  }

  private static async syncMedia(context: common.Context, entityId: string, newState: JsonRecord): Promise<void> {
    await CardRuntimeRepository.syncMediaState(context, entityId, HaEntityParser.parseMediaPlayerStateObject(newState));
  }

  private static async syncCamera(context: common.Context, entityId: string, newState: JsonRecord): Promise<void> {
    await CardRuntimeRepository.syncCameraState(context, entityId, HaEntityParser.parseCameraStateObject(newState));
  }

  private static async syncClimate(context: common.Context, entityId: string, newState: JsonRecord): Promise<void> {
    await CardRuntimeRepository.syncClimateState(context, entityId, HaEntityParser.parseClimateStateObject(newState));
  }

  private static isMissingFormError(err: Error): boolean {
    const message = err.message ?? JSON.stringify(err);
    return message.includes('16501001') ||
      message.includes('does not exist') ||
      message.includes('not exist such form') ||
      message.includes('formInfo not find');
  }

  private static scheduleReconnect(): void {
    if (HaBackgroundConnectionService.stopping || !HaBackgroundConnectionService.running) {
      return;
    }
    if (HaBackgroundConnectionService.reconnectTimer >= 0) {
      return;
    }
    const current = HaBackgroundConnectionService.client;
    HaBackgroundConnectionService.client = undefined;
    HaBackgroundConnectionService.subscribed = false;
    HaBackgroundConnectionService.pushSubscribed = false;
    HaBackgroundConnectionService.initialRefreshDone = false;
    HaBackgroundConnectionService.subscribedEntityIds = [];
    HaBackgroundConnectionService.subscribedEntityIdsLoadedAt = 0;
    if (current) {
      current.close().catch((): void => {});
    }
    HaBackgroundConnectionService.reconnectTimer = setTimeout((): void => {
      HaBackgroundConnectionService.reconnectTimer = -1;
      const context = HaBackgroundConnectionService.context;
      if (!context || HaBackgroundConnectionService.stopping) {
        return;
      }
      const restart = (): Promise<void> => {
        HaBackgroundConnectionService.running = false;
        return HaBackgroundConnectionService.start(context, HaBackgroundConnectionService.requiresLongRunning);
      };
      if (!HaBackgroundConnectionService.requiresLongRunning) {
        restart().catch((err: Error): void => {
          hilog.warn(DOMAIN, TAG, 'reconnect failed: %{public}s', err.message);
        });
        return;
      }
      LongRunningTaskService.ensureActive(context as common.UIAbilityContext)
        .then((): Promise<void> => {
          HaBackgroundConnectionService.running = false;
          return HaBackgroundConnectionService.start(context, true);
        })
        .catch((err: Error): void => {
          hilog.warn(DOMAIN, TAG, 'reconnect failed: %{public}s', err.message);
        });
    }, 10000);
  }

  private static clearReconnect(): void {
    if (HaBackgroundConnectionService.reconnectTimer < 0) {
      return;
    }
    clearTimeout(HaBackgroundConnectionService.reconnectTimer);
    HaBackgroundConnectionService.reconnectTimer = -1;
  }

  private static async resolveConnection(context: common.Context): Promise<BackgroundConnection> {
    const active = await ServerManager.getActiveServer(context);
    if (active && StorageService.hasLogin(active.info)) {
      const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, active.id);
      if (!policy.allowed || policy.baseUrl.length === 0) {
        hilog.warn(DOMAIN, TAG, 'skip start: connection blocked by security policy, reason=%{public}s', policy.reason);
        return {
          serverInstanceId: '',
          baseUrl: '',
          accessToken: '',
          refreshToken: ''
        };
      }
      return HaBackgroundConnectionService.refreshConnectionIfPossible(context, active.id, active.info, policy.baseUrl);
    }
    return {
      serverInstanceId: '',
      baseUrl: '',
      accessToken: '',
      refreshToken: ''
    };
  }

  private static async refreshConnectionIfPossible(
    context: common.Context,
    serverInstanceId: string,
    info: StoredServerInfo,
    connectionBaseUrl: string
  ): Promise<BackgroundConnection> {
    if (info.refreshToken.trim().length === 0) {
      const registeredInfo = await HaBackgroundConnectionService.ensureMobileAppRegistration(
        context,
        serverInstanceId,
        info,
        false,
        connectionBaseUrl
      );
      return {
        serverInstanceId: serverInstanceId.trim(),
        baseUrl: connectionBaseUrl.trim(),
        accessToken: registeredInfo.accessToken.trim(),
        refreshToken: ''
      };
    }
    const refreshed = await AuthService.refreshAccessToken(connectionBaseUrl, info.refreshToken);
    if (!refreshed.success || refreshed.accessToken.trim().length === 0) {
      hilog.warn(DOMAIN, TAG, 'skip start: refresh token failed');
      return {
        serverInstanceId: '',
        baseUrl: '',
        accessToken: '',
        refreshToken: ''
      };
    }
    const nextRefreshToken = refreshed.refreshToken.trim().length > 0 ? refreshed.refreshToken.trim() : info.refreshToken;
    let nextInfo = StorageService.applyRefresh(
      info,
      refreshed.accessToken.trim(),
      nextRefreshToken,
      StorageService.accessTokenExpiresAt(refreshed.expiresIn)
    );
    await ServerManager.saveActiveServerInfo(context, nextInfo);
    nextInfo = await HaBackgroundConnectionService.ensureMobileAppRegistration(
      context,
      serverInstanceId,
      nextInfo,
      false,
      connectionBaseUrl
    );
    return {
      serverInstanceId: serverInstanceId.trim(),
      baseUrl: connectionBaseUrl.trim(),
      accessToken: nextInfo.accessToken,
      refreshToken: nextInfo.refreshToken
    };
  }

  private static nextId(): number {
    const id = HaBackgroundConnectionService.messageId;
    HaBackgroundConnectionService.messageId += 1;
    return id;
  }

  private static webSocketUrl(baseUrl: string): string {
    const normalized = baseUrl.replace(/\/+$/, '');
    if (normalized.startsWith('https://')) {
      return `wss://${normalized.slice('https://'.length)}/api/websocket`;
    }
    if (normalized.startsWith('http://')) {
      return `ws://${normalized.slice('http://'.length)}/api/websocket`;
    }
    return `${normalized}/api/websocket`;
  }

  private static webhookUrls(baseUrl: string, webhookId: string): string[] {
    const normalized = baseUrl.replace(/\/+$/, '');
    return [`${normalized}/api/webhook/${webhookId}`];
  }

  private static async postWebhook(url: string, body: Object): Promise<WebhookPostResult> {
    const resp = await NetworkService.requestText(url, {
      method: NetworkHttpMethod.POST,
      header: {
        'Content-Type': 'application/json'
      },
      extraData: JSON.stringify(body),
      connectTimeout: 10000,
      readTimeout: 10000
    });
    return {
      responseCode: resp.responseCode,
      body: resp.body
    };
  }

  private static async ensureMobileAppRegistration(
    context: common.Context,
    serverInstanceId: string,
    info: StoredServerInfo,
    force: boolean = false,
    connectionBaseUrl: string = ''
  ): Promise<StoredServerInfo> {
    const storedAppId = await MobileAppIdentityStore.getRegistrationAppId(context, serverInstanceId);
    if (!force && info.webhookId.trim().length > 0 && storedAppId === MobileAppRegistrationService.APP_ID) {
      return info;
    }
    const deviceName = info.deviceName.trim().length > 0 ?
      info.deviceName.trim() :
      MobileAppRegistrationService.defaultDeviceName();
    const deviceId = await MobileAppIdentityStore.getOrCreateDeviceId(context, info.mobileAppDeviceId);
    try {
      const pushKitToken = await HarmonyPushTokenService.ensureToken();
      const registration = await MobileAppRegistrationService.registerDevice(
        connectionBaseUrl.trim().length > 0 ? connectionBaseUrl.trim() : info.baseUrl,
        info.accessToken,
        MobileAppRegistrationService.buildRequest(deviceName, deviceId, pushKitToken),
        async (): Promise<string> => {
          if (info.refreshToken.trim().length === 0) {
            return '';
          }
          const refreshed = await AuthService.refreshAccessToken(
            connectionBaseUrl.trim().length > 0 ? connectionBaseUrl.trim() : info.baseUrl,
            info.refreshToken
          );
          return refreshed.success ? refreshed.accessToken.trim() : '';
        }
      );
      const registeredInfo = StorageService.applyRegistration({
        baseUrl: info.baseUrl,
        accessToken: info.accessToken,
        refreshToken: info.refreshToken,
        accessTokenExpiresAt: info.accessTokenExpiresAt,
        deviceName,
        mobileAppDeviceId: deviceId,
        webhookId: '',
        webhookSecret: '',
        cloudhookUrl: '',
        remoteUiUrl: ''
      }, registration.webhookId, registration.webhookSecret, registration.cloudhookUrl, registration.remoteUiUrl);
      await ServerManager.saveActiveServerInfo(context, registeredInfo);
      await MobileAppIdentityStore.setRegistrationAppId(context, serverInstanceId, MobileAppRegistrationService.APP_ID);
      hilog.info(DOMAIN, TAG, 'mobile app registered for local push, server=%{public}s', serverInstanceId);
      return registeredInfo;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'mobile app registration failed: %{public}s', (err as Error).message);
      return info;
    }
  }

  private static objectField(source: JsonRecord, key: string): JsonRecord | null {
    const value = source[key];
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as JsonRecord;
    }
    return null;
  }

  private static stringField(source: JsonRecord, key: string): string {
    const value = source[key];
    return typeof value === 'string' ? value.trim() : '';
  }

  private static isBoundEntity(entityId: string): boolean {
    if (HaBackgroundConnectionService.subscribedEntityIds.length === 0) {
      return false;
    }
    return HaBackgroundConnectionService.subscribedEntityIds.includes(entityId);
  }

  private static async reloadAndCheckBoundEntity(context: common.Context, entityId: string): Promise<boolean> {
    if (Date.now() - HaBackgroundConnectionService.subscribedEntityIdsLoadedAt < 30000) {
      return false;
    }
    await HaBackgroundConnectionService.reloadBoundEntityIds(context, ServerManager.getActiveServerIdSync(context));
    return HaBackgroundConnectionService.isBoundEntity(entityId);
  }

  private static async reloadBoundEntityIds(context: common.Context, serverInstanceId: string): Promise<void> {
    HaBackgroundConnectionService.subscribedEntityIds = await CardRuntimeRepository.listBoundEntityIds(context, serverInstanceId);
    HaBackgroundConnectionService.subscribedEntityIdsLoadedAt = Date.now();
  }

  private static jsonRecord(value: Object | null): JsonRecord | null {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as JsonRecord;
    }
    return null;
  }

}
