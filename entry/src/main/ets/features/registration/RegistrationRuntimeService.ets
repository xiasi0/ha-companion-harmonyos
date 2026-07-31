import common from '@ohos.app.ability.common';
import { AppRoute } from '../../app/AppRoute';
import { UrlService } from '../../services/UrlService';
import { HaMobileAppRegistrationInfo } from '../../services/HaApiService';
import { MobileAppIdentityStore } from '../../services/MobileAppIdentityStore';
import { ServerManager } from '../../services/ServerManager';
import { StorageService, StoredServerInfo } from '../../services/StorageService';
import { Localization } from '../../shared/i18n/Localization';
import { HarmonyPushTokenService } from '../pushkit/HarmonyPushTokenService';
import { MobileAppRegistrationService } from './MobileAppRegistrationService';

export interface RegistrationRuntimeState {
  haBaseUrl: string;
  haAccessToken: string;
  haWebhookId: string;
  haMobileAppDeviceId: string;
  deviceName: string;
  loading: boolean;
  message: string;
  step: AppRoute;
}

export interface RegistrationRuntimeCallbacks {
  currentServerInfo: () => StoredServerInfo;
  applyServerInfo: (info: StoredServerInfo) => void;
  refreshAccessToken: (baseUrl: string) => Promise<boolean>;
  syncPublicSensors: (reason: string) => void;
  stringifyError: (err: Error | string | number | boolean | Object | ArrayBuffer) => string;
  context: () => common.Context;
}

export class RegistrationRuntimeService {
  static hasRegisteredCurrentDevice(state: RegistrationRuntimeState): boolean {
    return state.haWebhookId.trim().length > 0;
  }

  static async ensureMobileAppDeviceId(
    state: RegistrationRuntimeState,
    callbacks: RegistrationRuntimeCallbacks
  ): Promise<string> {
    const deviceId = await MobileAppIdentityStore.getOrCreateDeviceId(callbacks.context(), state.haMobileAppDeviceId);
    state.haMobileAppDeviceId = deviceId;
    return deviceId;
  }

  static applyRegistrationInfo(
    info: HaMobileAppRegistrationInfo,
    callbacks: RegistrationRuntimeCallbacks
  ): void {
    callbacks.applyServerInfo(
      StorageService.applyRegistration(
        callbacks.currentServerInfo(),
        info.webhookId,
        info.webhookSecret,
        info.cloudhookUrl,
        info.remoteUiUrl
      )
    );
  }

  static async registerCurrentDevice(
    state: RegistrationRuntimeState,
    callbacks: RegistrationRuntimeCallbacks,
    connectionBaseUrl: string = ''
  ): Promise<void> {
    const baseUrl = UrlService.normalizeBaseUrl(
      connectionBaseUrl.trim().length > 0 ? connectionBaseUrl : state.haBaseUrl
    );
    const token = state.haAccessToken.trim();
    const deviceName = state.deviceName.trim();
    if (baseUrl.length === 0 || token.length === 0) {
      throw new Error(Localization.t('registration_missing_server_or_token'));
    }
    if (deviceName.length === 0) {
      throw new Error(Localization.t('registration_enter_device_name'));
    }
    const deviceId = await RegistrationRuntimeService.ensureMobileAppDeviceId(state, callbacks);
    const pushKitToken = await HarmonyPushTokenService.ensureToken();
    const serverId = await RegistrationRuntimeService.ensureCurrentServerId(callbacks);
    const registration = await MobileAppRegistrationService.registerDevice(
      baseUrl,
      token,
      MobileAppRegistrationService.buildRequest(deviceName, deviceId, pushKitToken),
      async (): Promise<string> => {
        const refreshed = await callbacks.refreshAccessToken(baseUrl);
        return refreshed ? state.haAccessToken.trim() : '';
      }
    );
    RegistrationRuntimeService.applyRegistrationInfo(registration, callbacks);
    if (serverId.length > 0) {
      await MobileAppIdentityStore.setRegistrationAppId(callbacks.context(), serverId, MobileAppRegistrationService.APP_ID);
    }
  }

  private static async ensureCurrentServerId(callbacks: RegistrationRuntimeCallbacks): Promise<string> {
    const context = callbacks.context();
    const currentId = ServerManager.getActiveServerIdSync(context);
    if (currentId.length > 0) {
      return currentId;
    }
    const info = callbacks.currentServerInfo();
    if (!StorageService.hasLogin(info)) {
      return '';
    }
    const saved = await ServerManager.saveActiveServerInfo(context, info);
    return saved.id.trim();
  }

  static async ensureCurrentDeviceRegistered(
    state: RegistrationRuntimeState,
    callbacks: RegistrationRuntimeCallbacks,
    reason: string,
    connectionBaseUrl: string = ''
  ): Promise<boolean> {
    if (!StorageService.hasLogin(callbacks.currentServerInfo()) ||
      RegistrationRuntimeService.hasRegisteredCurrentDevice(state)) {
      return false;
    }
    await RegistrationRuntimeService.registerCurrentDevice(state, callbacks, connectionBaseUrl);
    callbacks.syncPublicSensors(reason);
    return true;
  }

  static completeDeviceRegistration(
    state: RegistrationRuntimeState,
    callbacks: RegistrationRuntimeCallbacks
  ): void {
    const value = state.deviceName.trim();
    if (value.length === 0) {
      return;
    }
    callbacks.applyServerInfo(StorageService.applyDeviceName(callbacks.currentServerInfo(), value));
    if (RegistrationRuntimeService.hasRegisteredCurrentDevice(state)) {
      state.step = AppRoute.LOCAL_FIRST;
      return;
    }
    state.loading = true;
    state.message = Localization.t('registration_registering_device');
    RegistrationRuntimeService.ensureCurrentDeviceRegistered(state, callbacks, 'device_registered')
      .then((): void => {
        state.step = AppRoute.LOCAL_FIRST;
        state.message = '';
      })
      .catch((error: Error | string | number | boolean | Object | ArrayBuffer): void => {
        state.message = callbacks.stringifyError(error);
      })
      .finally((): void => {
        state.loading = false;
      });
  }
}
