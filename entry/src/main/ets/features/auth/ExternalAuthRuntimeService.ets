import { AppRoute } from '../../app/AppRoute';
import { UrlService } from '../../services/UrlService';
import { StorageService, StoredServerInfo } from '../../services/StorageService';
import { ExternalBusService } from '../../services/ExternalBusService';
import { Localization } from '../../shared/i18n/Localization';

export interface ExternalAuthRuntimeState {
  haBaseUrl: string;
  haAccessToken: string;
  trustServer: boolean;
  dashboardAuthProvided: boolean;
  dashboardUrl: string;
  dashboardBridgeReady: boolean;
  message: string;
  step: AppRoute;
}

export interface ExternalAuthRuntimeCallbacks {
  isWebMounted: () => boolean;
  runScript: (script: string) => void;
  refreshAccessToken: (baseUrl: string) => Promise<boolean>;
  loadAccessToken: (baseUrl: string, forceRefresh: boolean) => Promise<string>;
  currentServerInfo: () => StoredServerInfo;
  applyServerInfo: (info: StoredServerInfo) => void;
  openCompanionSettings: () => void;
  openAssistSettings: () => void;
  openAssistConversation: (payload: Object | string) => void;
}

export class ExternalAuthRuntimeService {
  static invokeExternalAuthCallback(
    callback: string,
    success: boolean,
    callbacks: ExternalAuthRuntimeCallbacks,
    token: string = ''
  ): void {
    if (!callback || !callbacks.isWebMounted()) {
      return;
    }
    callbacks.runScript(ExternalBusService.buildExternalAuthCallbackScript(callback, success, token));
  }

  static sendExternalBusConfigResponse(messageId: number, callbacks: ExternalAuthRuntimeCallbacks): void {
    if (!callbacks.isWebMounted()) {
      return;
    }
    callbacks.runScript(ExternalBusService.buildConfigResponseScript(messageId));
  }

  static handleExternalBus(
    payload: Object | string,
    state: ExternalAuthRuntimeState,
    callbacks: ExternalAuthRuntimeCallbacks
  ): void {
    const type = ExternalBusService.type(payload);
    if (type === 'config/get') {
      ExternalAuthRuntimeService.sendExternalBusConfigResponse(ExternalBusService.id(payload), callbacks);
      return;
    }
    if (type === 'config_screen/show') {
      callbacks.openCompanionSettings();
      return;
    }
    if (type === 'assist/settings') {
      callbacks.openAssistSettings();
      return;
    }
    if (type === 'assist/show') {
      callbacks.openAssistConversation(payload);
      return;
    }
    if (!state.trustServer && ExternalBusService.isServerCommandType(type)) {
      state.message = Localization.t('external_server_untrusted');
      return;
    }
    if (type === 'connection-status' || type === 'haptic') {
      return;
    }
    if (type.length > 0) {
      state.message = Localization.format('external_event_unhandled', 'type', type);
    }
  }

  static handleExternalGetAuth(
    payload: Object | string,
    state: ExternalAuthRuntimeState,
    callbacks: ExternalAuthRuntimeCallbacks
  ): void {
    const callback = ExternalBusService.callbackName(payload);
    const force = ExternalBusService.forceRefresh(payload);
    const baseUrl = UrlService.normalizeBaseUrl(state.dashboardUrl) || UrlService.normalizeBaseUrl(state.haBaseUrl);
    if (!baseUrl) {
      ExternalAuthRuntimeService.invokeExternalAuthCallback(callback, false, callbacks);
      return;
    }
    const finish = (accessToken: string): void => {
      const token = accessToken.trim();
      if (token) {
        state.dashboardAuthProvided = true;
        state.message = Localization.t('external_auth_providing_token');
        ExternalAuthRuntimeService.invokeExternalAuthCallback(callback, true, callbacks, token);
        setTimeout((): void => {
          if (state.step === AppRoute.DASHBOARD && state.dashboardAuthProvided) {
            state.message = Localization.t('dashboard_visible');
          }
        }, 2500);
      } else {
        ExternalAuthRuntimeService.invokeExternalAuthCallback(callback, false, callbacks);
      }
    };
    callbacks.loadAccessToken(baseUrl, force)
      .then((token: string): void => finish(token))
      .catch((): void => finish(state.haAccessToken));
  }

  static handleExternalRevokeAuth(
    payload: Object | string,
    state: ExternalAuthRuntimeState,
    callbacks: ExternalAuthRuntimeCallbacks
  ): void {
    const callback = ExternalBusService.callbackName(payload);
    callbacks.applyServerInfo(StorageService.applyLogin(callbacks.currentServerInfo(), state.haBaseUrl, '', ''));
    state.dashboardUrl = '';
    state.dashboardBridgeReady = false;
    state.dashboardAuthProvided = false;
    state.step = AppRoute.WELCOME;
    state.message = Localization.t('external_auth_revoked');
    ExternalAuthRuntimeService.invokeExternalAuthCallback(callback, true, callbacks);
  }
}
