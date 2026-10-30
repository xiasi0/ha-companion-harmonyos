import common from '@ohos.app.ability.common';
import commonEventManager from '@ohos.commonEventManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { wantAgent, Want, WantAgent } from '@kit.AbilityKit';
import { HaApiService } from '../../services/HaApiService';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { ServerAuthRepository } from '../../services/ServerAuthRepository';
import { ServerManager } from '../../services/ServerManager';
import { StorageService } from '../../services/StorageService';
import { LocalNotificationPayload, NotificationAction } from './NotificationModels';

const DOMAIN = 0x0000;
const TAG = 'HANotificationAction';

export class NotificationActionService {
  static readonly EVENT: string = 'io.homeassistant.companion.notification.action';
  static readonly URL_ACTION: string = 'io.homeassistant.companion.notification.url';
  static readonly PENDING_URI_KEY: string = 'notificationPendingUri';
  static readonly PENDING_SERVER_INSTANCE_ID_KEY: string = 'notificationPendingServerInstanceId';
  static readonly PENDING_TICK_KEY: string = 'notificationPendingUriTick';
  private static readonly BUNDLE_NAME: string = 'io.homeassistant.companion';
  private static readonly ENTRY_ABILITY_NAME: string = 'EntryAbility';
  private static subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;
  private static subscribed: boolean = false;

  static async createWantAgent(
    notificationId: number,
    payload: LocalNotificationPayload,
    action: NotificationAction
  ): Promise<WantAgent> {
    const isUrlAction = NotificationActionService.isUrlAction(action);
    const target: Want = isUrlAction
      ? {
          bundleName: NotificationActionService.BUNDLE_NAME,
          abilityName: NotificationActionService.ENTRY_ABILITY_NAME,
          action: NotificationActionService.URL_ACTION,
          parameters: {
            uri: action.uri,
            serverInstanceId: payload.serverInstanceId ?? ''
          }
        }
      : {
          action: NotificationActionService.EVENT,
          parameters: {
            notificationId: `${notificationId}`,
            serverInstanceId: payload.serverInstanceId ?? '',
            action: action.key,
            dataJson: JSON.stringify(action.data)
          }
        };
    const request: wantAgent.WantAgentInfo = {
      wants: [target],
      actionType: isUrlAction ? wantAgent.OperationType.START_ABILITY : wantAgent.OperationType.SEND_COMMON_EVENT,
      requestCode: NotificationActionService.requestCode(notificationId, action.key),
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(request);
  }

  static isUrlAction(action: NotificationAction): boolean {
    const key = action.key.trim().toUpperCase();
    return key === 'URI' || key === 'URL';
  }

  static requestFromWant(want: Want): boolean {
    if (want.action !== NotificationActionService.URL_ACTION || !want.parameters) {
      return false;
    }
    const uri = NotificationActionService.stringValue(want.parameters['uri']);
    if (uri.length === 0) {
      return false;
    }
    const serverInstanceId = NotificationActionService.stringValue(want.parameters['serverInstanceId']);
    AppStorage.setOrCreate<string>(NotificationActionService.PENDING_SERVER_INSTANCE_ID_KEY, serverInstanceId);
    AppStorage.setOrCreate<string>(NotificationActionService.PENDING_URI_KEY, uri);
    const currentTick = AppStorage.get<number>(NotificationActionService.PENDING_TICK_KEY) ?? 0;
    AppStorage.setOrCreate<number>(NotificationActionService.PENDING_TICK_KEY, currentTick + 1);
    return true;
  }

  static start(context: common.Context): void {
    if (NotificationActionService.subscribed) {
      return;
    }
    NotificationActionService.subscribed = true;
    commonEventManager.createSubscriber({
      events: [NotificationActionService.EVENT],
      publisherBundleName: NotificationActionService.BUNDLE_NAME
    }).then((subscriber: commonEventManager.CommonEventSubscriber): Promise<void> => {
      NotificationActionService.subscriber = subscriber;
      return commonEventManager.subscribeToEvent(subscriber, (data: commonEventManager.CommonEventData): void => {
        NotificationActionService.handleEvent(context, data).catch((error: Error): void => {
          hilog.warn(DOMAIN, TAG, 'handle notification action failed: %{public}s', error.message);
        });
      });
    }).catch((error: Error): void => {
      NotificationActionService.subscribed = false;
      NotificationActionService.subscriber = undefined;
      hilog.warn(DOMAIN, TAG, 'subscribe notification action failed: %{public}s', error.message);
    });
  }

  private static async handleEvent(
    context: common.Context,
    event: commonEventManager.CommonEventData
  ): Promise<void> {
    const parameters = event.parameters;
    if (!parameters) {
      return;
    }
    const action = NotificationActionService.stringValue(parameters['action']);
    if (action.length === 0) {
      return;
    }
    const requestedServerId = NotificationActionService.stringValue(parameters['serverInstanceId']);
    const serverId = await NotificationActionService.resolveServerId(context, requestedServerId);
    if (serverId.length === 0) {
      return;
    }
    const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, serverId);
    if (!policy.allowed || policy.baseUrl.length === 0) {
      return;
    }
    const session = await ServerAuthRepository.loadFreshWithBaseUrl(context, serverId, policy.baseUrl);
    if (session.accessToken.length === 0 || session.baseUrl.length === 0) {
      return;
    }
    const data = NotificationActionService.parseData(
      NotificationActionService.stringValue(parameters['dataJson'])
    );
    data['action'] = action;
    await HaApiService.fireEvent(
      session.baseUrl,
      session.accessToken,
      'mobile_app_notification_action',
      data
    );
  }

  private static async resolveServerId(context: common.Context, requested: string): Promise<string> {
    const normalized = requested.trim();
    if (normalized.length > 0) {
      const info = await ServerManager.getServerInfo(context, normalized);
      if (StorageService.hasCredentials(info)) {
        return normalized;
      }
    }
    const active = await ServerManager.getActiveServer(context);
    return active ? active.id.trim() : '';
  }

  private static parseData(value: string): Record<string, string> {
    if (value.length === 0) {
      return {};
    }
    try {
      const parsed = JSON.parse(value) as Record<string, Object | string | number | boolean | null>;
      const result: Record<string, string> = {};
      const keys = Object.keys(parsed);
      for (let i = 0; i < keys.length; i++) {
        const item = parsed[keys[i]];
        if (typeof item === 'string') {
          result[keys[i]] = item;
        } else if (typeof item === 'number' || typeof item === 'boolean') {
          result[keys[i]] = `${item}`;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  private static stringValue(value: Object | string | number | boolean | null | undefined): string {
    if (typeof value === 'string') {
      return value.trim();
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return `${value}`;
    }
    return '';
  }

  private static requestCode(notificationId: number, action: string): number {
    let hash = notificationId | 0;
    for (let i = 0; i < action.length; i++) {
      hash = ((hash << 5) - hash + action.charCodeAt(i)) | 0;
    }
    return Math.abs(hash % 2147483647);
  }
}
