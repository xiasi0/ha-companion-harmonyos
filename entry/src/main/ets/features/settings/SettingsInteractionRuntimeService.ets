import common from '@ohos.app.ability.common';
import { SettingsItem, SettingsItemType } from '../../models/SettingsItem';
import { AppRoute } from '../../app/AppRoute';
import { AppSettingsStore } from '../../services/AppSettingsStore';
import { UrlService } from '../../services/UrlService';
import { StorageService, StoredServerInfo } from '../../services/StorageService';
import { Localization } from '../../shared/i18n/Localization';
import { HaBackgroundConnectionService } from '../background/HaBackgroundConnectionService';
import { LongRunningTaskService } from '../background/LongRunningTaskService';
import { AppLockRuntimeService } from '../security/AppLockRuntimeService';
import { SettingsSummaryService } from './SettingsSummaryService';
import { SettingsActionDecision, SettingsActionKind, SettingsRouteService } from './SettingsRouteService';

export interface SettingsInteractionCallbacks {
  context: () => common.Context;
  currentServerInfo: () => StoredServerInfo;
  applyServerInfo: (info: StoredServerInfo) => void;
  updateServerName: (name: string, info: StoredServerInfo) => void;
  syncServerNameToHomeAssistant: (name: string, info: StoredServerInfo) => void;
  setStep: (route: AppRoute) => void;
  setMessage: (message: string) => void;
  refreshSettingsState: () => void;
  applyWindowPreferences: () => void;
  applyDashboardPreferences: () => void;
  refreshCards: () => void;
  ignoreAppLockTransitions: () => void;
  openServerSettings: () => void;
  startAddServerFromSettings: () => void;
  openCompanionChoiceDialog: (key: string) => void;
}

export interface SettingsInteractionState {
  step: AppRoute;
  haBaseUrl: string;
  haAccessToken: string;
  configSummary: string;
  deviceName: string;
  serverNameOverride: string;
  serverExternalUrl: string;
  serverInternalUrl: string;
  sessionTimeout: string;
  secureConnectionChoice: string;
  websocketMode: string;
  serviceCardUpdateFrequency: string;
  homeNetworkName: string;
  homeWifiSsids: string[];
  homeSsidInput: string;
  fullScreenEnabled: boolean;
  keepScreenOnEnabled: boolean;
  pinchToZoomEnabled: boolean;
  autoPlayVideoEnabled: boolean;
  alwaysShowFirstViewOnAppStartEnabled: boolean;
  trustServer: boolean;
  appLockEnabled: boolean;
  appLockHomeBypass: boolean;
  appLocked: boolean;
  appLockAuthPending: boolean;
  nativeFeatureBackTarget: AppRoute;
  secureConnectionFromSettings: boolean;
  showDeleteServerDialog: boolean;
  serverEditKey: string;
  serverEditTitle: string;
  serverEditValue: string;
  showServerEditDialog: boolean;
  selectedServerSettingsName: string;
  selectedServerSettingsInfo: StoredServerInfo;
  settingsDetailKey: string;
  settingsDetailTitle: string;
  settingsDetailSummary: string;
  settingsDetailBody: string;
  settingsDetailStatus: string;
  settingsDetailAction: string;
  settingsEditValue: string;
  settingsOptionValue: string;
  dashboardUrl: string;
  dashboardCurrentUrl: string;
}

export class SettingsInteractionRuntimeService {
  private static selectedServerBaseUrl(state: SettingsInteractionState): string {
    const selectedBaseUrl = state.selectedServerSettingsInfo.baseUrl.trim();
    if (selectedBaseUrl.length > 0) {
      return UrlService.normalizeBaseUrl(selectedBaseUrl);
    }
    return UrlService.normalizeBaseUrl(state.haBaseUrl);
  }

  static isServerSettingItem(item: SettingsItem): boolean {
    return SettingsRouteService.isServerSettingItem(item);
  }

  static openSettingsItem(
    item: SettingsItem,
    state: SettingsInteractionState,
    callbacks: SettingsInteractionCallbacks
  ): void {
    if (SettingsInteractionRuntimeService.isServerSettingItem(item)) {
      SettingsInteractionRuntimeService.openServerSettingItem(item, state, callbacks);
      return;
    }
    if (item.type === SettingsItemType.SWITCH && item.actionId.length > 0) {
      SettingsInteractionRuntimeService.handleCompanionSwitch(item.actionId, state, callbacks);
      return;
    }
    state.settingsDetailKey = '';
    state.settingsEditValue = '';
    state.settingsOptionValue = '';
    state.settingsDetailTitle = item.title;
    state.settingsDetailKey = item.actionId;
    state.settingsDetailSummary = item.summary;
    state.settingsDetailBody = item.body;
    state.settingsDetailStatus = item.status;
    state.settingsDetailAction = item.action;
    state.step = AppRoute.SETTINGS_DETAIL;
  }

  static handleCompanionSwitch(
    actionId: string,
    state: SettingsInteractionState,
    callbacks: SettingsInteractionCallbacks
  ): void {
    if (actionId === 'toggle_fullscreen') {
      state.fullScreenEnabled = !state.fullScreenEnabled;
      callbacks.refreshSettingsState();
      callbacks.applyWindowPreferences();
      AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      return;
    }
    if (actionId === 'toggle_keep_screen') {
      state.keepScreenOnEnabled = !state.keepScreenOnEnabled;
      callbacks.refreshSettingsState();
      callbacks.applyWindowPreferences();
      AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      return;
    }
    if (actionId === 'toggle_pinch_to_zoom') {
      state.pinchToZoomEnabled = !state.pinchToZoomEnabled;
      callbacks.refreshSettingsState();
      callbacks.applyDashboardPreferences();
      AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      return;
    }
    if (actionId === 'toggle_autoplay_video') {
      state.autoPlayVideoEnabled = !state.autoPlayVideoEnabled;
      callbacks.refreshSettingsState();
      AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      return;
    }
    if (actionId === 'toggle_always_show_first_view') {
      state.alwaysShowFirstViewOnAppStartEnabled = !state.alwaysShowFirstViewOnAppStartEnabled;
      callbacks.refreshSettingsState();
      AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      return;
    }
  }

  static openServerSettingItem(
    item: SettingsItem,
    state: SettingsInteractionState,
    callbacks: SettingsInteractionCallbacks
  ): void {
    if (item.actionId === 'server_trust_server') {
      state.trustServer = !state.trustServer;
      callbacks.refreshSettingsState();
      callbacks.setMessage(state.trustServer ? Localization.t('server_trusted') : Localization.t('server_untrusted'));
      AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      return;
    }
    if (item.actionId === 'server_app_lock') {
      SettingsInteractionRuntimeService.toggleAppLock(state, callbacks);
      return;
    }
    if (item.actionId === 'server_app_lock_home_bypass') {
      if (state.appLockEnabled) {
        state.appLockHomeBypass = !state.appLockHomeBypass;
        callbacks.refreshSettingsState();
        AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      }
      return;
    }
    if (item.actionId === 'server_connection_security') {
      SettingsInteractionRuntimeService.handleSettingsAction(item.actionId, state, callbacks);
      return;
    }
    if (item.actionId === 'server_name' ||
      item.actionId === 'server_device_name' ||
      item.actionId === 'server_external_url' ||
      item.actionId === 'server_internal_url' ||
      item.actionId === 'server_session_timeout') {
      SettingsInteractionRuntimeService.openServerEditDialog(item.actionId, item.title, state);
      return;
    }
    if (item.actionId === 'server_home_network') {
      state.settingsDetailKey = item.actionId;
      state.settingsDetailTitle = item.title;
      state.step = AppRoute.SETTINGS_DETAIL;
      return;
    }
    SettingsInteractionRuntimeService.openServerDetail(item, state);
  }

  static openServerEditDialog(key: string, title: string, state: SettingsInteractionState): void {
    state.serverEditKey = key;
    state.serverEditTitle = title;
    if (key === 'server_name') {
      state.serverEditValue = state.selectedServerSettingsName.trim().length > 0
        ? state.selectedServerSettingsName
        : SettingsSummaryService.serverDisplayName(state.serverNameOverride, state.configSummary);
    } else if (key === 'server_external_url') {
      state.serverEditValue = SettingsInteractionRuntimeService.selectedServerBaseUrl(state);
    } else if (key === 'server_internal_url') {
      state.serverEditValue = state.serverInternalUrl;
    } else if (key === 'server_session_timeout') {
      state.serverEditValue = state.sessionTimeout;
    } else {
      state.serverEditValue = state.deviceName;
    }
    state.showServerEditDialog = true;
  }

  static saveServerEditDialog(state: SettingsInteractionState, callbacks: SettingsInteractionCallbacks): void {
    const value = state.serverEditValue.trim();
    if (state.serverEditKey === 'server_name' && value.length > 0) {
      const info = callbacks.currentServerInfo();
      state.selectedServerSettingsName = value;
      callbacks.updateServerName(value, info);
      callbacks.syncServerNameToHomeAssistant(value, info);
    } else if (state.serverEditKey === 'server_device_name' && value.length > 0) {
      callbacks.applyServerInfo(StorageService.applyDeviceName(callbacks.currentServerInfo(), value));
    } else if (state.serverEditKey === 'server_external_url') {
      const normalized = UrlService.normalizeBaseUrl(value);
      if (normalized.length === 0) {
        callbacks.setMessage(Localization.t('manual_server_invalid'));
        return;
      }
      callbacks.applyServerInfo(StorageService.applyServer(callbacks.currentServerInfo(), normalized));
    } else if (state.serverEditKey === 'server_internal_url') {
      if (value.length === 0) {
        state.serverInternalUrl = '';
      } else {
        const normalized = UrlService.normalizeBaseUrl(value);
        if (normalized.length === 0) {
          callbacks.setMessage(Localization.t('manual_server_invalid'));
          return;
        }
        state.serverInternalUrl = normalized;
      }
    } else if (state.serverEditKey === 'server_session_timeout') {
      state.sessionTimeout = value.length > 0 ? value : '0';
    }
    callbacks.refreshSettingsState();
    state.showServerEditDialog = false;
    AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
  }

  static addHomeWifiSsid(state: SettingsInteractionState): void {
    const value = state.homeSsidInput.trim();
    if (value.length === 0) {
      return;
    }
    if (state.homeWifiSsids.indexOf(value) < 0) {
      state.homeWifiSsids.push(value);
      state.homeNetworkName = '';
    }
    state.homeSsidInput = '';
  }

  static removeHomeWifiSsid(value: string, state: SettingsInteractionState): void {
    state.homeWifiSsids = state.homeWifiSsids.filter((item: string): boolean => item !== value);
    state.homeNetworkName = '';
  }

  static saveServerSettingDetail(
    state: SettingsInteractionState,
    callbacks: SettingsInteractionCallbacks
  ): void {
    const value = state.settingsEditValue.trim();
    if (state.settingsDetailKey === 'server_device_name') {
      callbacks.applyServerInfo(StorageService.applyDeviceName(callbacks.currentServerInfo(), value));
    } else if (state.settingsDetailKey === 'server_external_url') {
      const normalized = UrlService.normalizeBaseUrl(value);
      if (normalized.length === 0) {
        callbacks.setMessage(Localization.t('manual_server_invalid'));
        return;
      }
      callbacks.applyServerInfo(StorageService.applyServer(callbacks.currentServerInfo(), normalized));
    } else if (state.settingsDetailKey === 'server_internal_url') {
      state.serverInternalUrl = value.length > 0 ? UrlService.normalizeBaseUrl(value) : '';
    } else if (state.settingsDetailKey === 'server_session_timeout') {
      state.sessionTimeout = value.length > 0 ? value : '0';
    } else if (state.settingsDetailKey === 'server_websocket') {
      SettingsInteractionRuntimeService.applyPersistentConnectionMode(
        state.settingsOptionValue.length > 0 ? state.settingsOptionValue : 'system',
        state,
        callbacks
      );
    }
    callbacks.refreshSettingsState();
    state.step = AppRoute.SERVER_SETTINGS;
    AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
  }

  static handleSettingsAction(
    actionId: string,
    state: SettingsInteractionState,
    callbacks: SettingsInteractionCallbacks
  ): void {
    const decision: SettingsActionDecision = SettingsRouteService.decideAction(actionId);
    if (decision.kind === SettingsActionKind.OPEN_SERVER) {
      callbacks.openServerSettings();
      return;
    }
    if (decision.kind === SettingsActionKind.ADD_SERVER) {
      callbacks.startAddServerFromSettings();
      return;
    }
    if (decision.kind === SettingsActionKind.DELETE_SERVER) {
      state.showDeleteServerDialog = true;
      return;
    }
    if (decision.kind === SettingsActionKind.OPEN_SETTINGS_DETAIL) {
      state.settingsDetailKey = decision.detailKey;
      state.settingsDetailTitle = Localization.t('settings_gestures');
      state.step = AppRoute.SETTINGS_DETAIL;
      return;
    }
    if (decision.kind === SettingsActionKind.OPEN_COMPANION_CHOICE) {
      callbacks.openCompanionChoiceDialog(decision.choiceKey);
      return;
    }
    if (decision.kind === SettingsActionKind.OPEN_NATIVE_FEATURE) {
      state.nativeFeatureBackTarget = state.step === AppRoute.SERVER_SETTINGS
        ? AppRoute.SERVER_SETTINGS
        : AppRoute.COMPANION_SETTINGS;
      state.step = decision.route;
    }
  }

  private static openServerDetail(item: SettingsItem, state: SettingsInteractionState): void {
    state.settingsDetailKey = item.actionId;
    state.settingsDetailTitle = item.title;
    state.settingsDetailSummary = item.summary;
    state.settingsDetailBody = item.body;
    state.settingsDetailStatus = item.status;
    state.settingsDetailAction = '';
    if (item.actionId === 'server_external_url') {
      state.settingsEditValue = SettingsInteractionRuntimeService.selectedServerBaseUrl(state);
    } else if (item.actionId === 'server_internal_url') {
      state.settingsEditValue = state.serverInternalUrl;
    } else if (item.actionId === 'server_session_timeout') {
      state.settingsEditValue = state.sessionTimeout;
    } else {
      state.settingsEditValue = '';
    }
    if (item.actionId === 'server_websocket') {
      state.settingsOptionValue = state.websocketMode;
    } else {
      state.settingsOptionValue = '';
    }
    state.step = AppRoute.SETTINGS_DETAIL;
  }

  private static toggleAppLock(state: SettingsInteractionState, callbacks: SettingsInteractionCallbacks): void {
    if (state.appLockEnabled) {
      state.appLockEnabled = false;
      state.appLockHomeBypass = false;
      state.appLocked = false;
      callbacks.refreshSettingsState();
      callbacks.setMessage(Localization.t('app_lock_disabled_message'));
      AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      return;
    }
    if (state.appLockAuthPending) {
      return;
    }
    state.appLockAuthPending = true;
    state.appLockEnabled = true;
    callbacks.refreshSettingsState();
    callbacks.ignoreAppLockTransitions();
    callbacks.setMessage(Localization.t('app_lock_requesting_auth'));
    AppLockRuntimeService.authenticateEnable(callbacks.context())
      .then((result): void => {
        state.appLockAuthPending = false;
        if (result.success) {
          state.appLockEnabled = true;
          state.appLocked = false;
          callbacks.refreshSettingsState();
          callbacks.setMessage(Localization.t('app_lock_enabled_message'));
          AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
        } else {
          state.appLockEnabled = false;
          state.appLockHomeBypass = false;
          callbacks.refreshSettingsState();
          callbacks.setMessage(result.message.length > 0
            ? Localization.format('app_lock_enable_failed_with_message', 'message', result.message)
            : Localization.t('app_lock_enable_failed'));
          AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
        }
      })
      .catch((): void => {
        state.appLockAuthPending = false;
        state.appLockEnabled = false;
        state.appLockHomeBypass = false;
        callbacks.refreshSettingsState();
        callbacks.setMessage(Localization.t('app_lock_enable_error'));
        AppSettingsStore.saveCurrentAppStorage(callbacks.context()).catch((): void => {});
      });
  }

  static applyPersistentConnectionMode(
    value: string,
    state: SettingsInteractionState,
    callbacks: SettingsInteractionCallbacks
  ): void {
    const normalized = value === 'always' ? 'always' : 'system';
    state.websocketMode = normalized;
    if (normalized === 'always') {
      state.serviceCardUpdateFrequency = 'default';
    }
    AppSettingsStore.saveWebsocketMode(callbacks.context(), normalized).catch((): void => {});
    callbacks.refreshCards();
    callbacks.refreshSettingsState();
    if (normalized === 'always') {
      LongRunningTaskService.ensureActive(callbacks.context() as common.UIAbilityContext)
        .then((): void => {
          HaBackgroundConnectionService.ensureRunning(callbacks.context(), true).catch((): void => {});
          callbacks.setMessage(Localization.t('persistent_connection_always_message'));
        })
        .catch((err: Error): void => {
          state.websocketMode = 'system';
          AppSettingsStore.saveWebsocketMode(callbacks.context(), 'system').catch((): void => {});
          callbacks.refreshSettingsState();
          callbacks.setMessage(Localization.format('persistent_connection_failed', 'error', err.message));
        });
      return;
    }
    HaBackgroundConnectionService.stop();
    LongRunningTaskService.stop(callbacks.context() as common.UIAbilityContext)
      .catch((): void => {});
    callbacks.setMessage(Localization.t('persistent_connection_system_message'));
  }
}
