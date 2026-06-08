// Builds callback adapters that let feature services mutate AppRuntimeHost state.
// This keeps service code decoupled from the concrete ArkUI host implementation.
import common from '@ohos.app.ability.common';
import { Localization } from '../shared/i18n/Localization';
import { StoredServerInfo } from '../services/StorageService';
import { SettingsChoiceRuntimeCallbacks } from '../features/settings/SettingsChoiceRuntimeService';
import { SettingsInteractionCallbacks } from '../features/settings/SettingsInteractionRuntimeService';
import { ServerAccountRuntimeCallbacks } from '../features/settings/ServerAccountRuntimeService';
import { SensorRuntimeCallbacks, SensorRuntimeSnapshot } from '../features/sensors/SensorRuntimeService';
import { SensorRuntimeFlags } from '../features/sensors/SensorRuntimePresenter';
import { DashboardRuntimeCallbacks } from '../features/dashboard/DashboardRuntimeService';
import { RegistrationRuntimeCallbacks } from '../features/registration/RegistrationRuntimeService';
import { AuthFlowRuntimeCallbacks } from '../features/auth/AuthFlowRuntimeService';
import { ExternalAuthRuntimeCallbacks } from '../features/auth/ExternalAuthRuntimeService';
import { DiscoveryFlowRuntimeCallbacks } from '../features/discovery/DiscoveryFlowRuntimeService';
import { AppLifecycleRuntimeCallbacks } from './AppLifecycleRuntimeService';
import { AppNavigationRuntimeCallbacks } from './AppNavigationRuntimeService';
import { AppRoute } from './AppRoute';
import { CardRuntimeRepository } from '../features/cards/CardRuntimeRepository';

export interface AppRuntimeCallbackTarget {
  applyWindowPreferences(): void;
  applyDashboardPreferences(): void;
  applyThemePreferences(): void;
  refreshDashboardTheme(): void;
  prewarmDiscovery(): void;
  applyActiveTheme(): void;
  currentStoredServerInfo(): StoredServerInfo;
  applyStoredServerInfo(info: StoredServerInfo): void;
  currentSettingsServerInfo(): StoredServerInfo;
  applySettingsServerInfo(info: StoredServerInfo): void;
  updateSettingsServerName(name: string, info: StoredServerInfo): void;
  syncSettingsServerNameToHomeAssistant(name: string, info: StoredServerInfo): void;
  refreshAccessToken(baseUrl: string): Promise<boolean>;
  loadExternalAuthAccessToken(baseUrl: string, forceRefresh: boolean): Promise<string>;
  syncPublicSensors(reason: string): void;
  refreshHomeNetworkStatus(allowDashboardUrlReload?: boolean): void;
  ensureMobileAppRegistration(reason: string): void;
  stringifyError(err: Error | string | number | boolean | Object | ArrayBuffer): string;
  initializeDeviceName(): void;
  syncCardServerConnection(): void;
  applySensorDefaultMigration(): void;
  subscribeBatteryEvents(onEvent: () => void): void;
  subscribeNetworkEvents(onEvent: () => void): void;
  subscribeDirectSensorEvents(onEvent: (reason: string) => void): void;
  subscribeHardwareSensorEvents(onEvent: (reason: string) => void): void;
  refreshPeriodicSensorTimer(): void;
  startLocationSensorsIfNeeded(): void;
  refreshLocationZones(syncAfterRefresh: boolean): void;
  reconcileBackgroundLocationPermission(): void;
  registerBackDispatcher(handler: () => boolean): void;
  handleBackNavigation(): boolean;
  shouldLockApp(): boolean;
  fetchHaConfig(): Promise<void>;
  clearBackDispatcher(): void;
  unsubscribeSystemEvents(): void;
  stopSensorRuntime(): void;
  stopDiscoveryAnimation(): void;
  refreshCurrentLocationForDiagnostics(trigger: string): void;
  isIgnoringAppLockTransitions(): boolean;
  maybeResetDashboardToFirstView(): void;
  closeCompanionChoiceDialog(): void;
  setDiscoverySheetVisible(visible: boolean): void;
  cancelAddServerFromSettings(): void;
  returnToHaSettingsPage(): void;
  canDashboardGoBack(): boolean;
  dashboardGoBack(): void;
  tryRunWebScript(script: string): void;
  context(): common.Context;
  setStep(route: AppRoute): void;
  setMessage(message: string): void;
  bumpSettingsRevision(): void;
  ignoreAppLockTransitions(): void;
  openServerSettings(): void;
  startAddServerFromSettings(): void;
  openCompanionChoiceDialog(key: string): void;
  openSecureConnectionFromSettings(): void;
  resetSensorRuntime(): void;
  resetAddServerSnapshot(): void;
  sensorRuntimeSnapshot(): SensorRuntimeSnapshot;
  applySensorFlags(flags: SensorRuntimeFlags): void;
  restoreInstanceAppSettingsState(): Promise<void>;
  setLocationHistoryJsonValue(value: string): void;
  setLocationSentModeValue(value: string): void;
  setLocationDiagnosticsJsonValue(value: string): void;
  setLocationGeofenceStatusValue(value: string): void;
  isWebControllerMounted(): boolean;
  openCompanionSettings(): void;
  openAssistSettings(): void;
  openAssistConversation(payload: Object | string): void;
  startOfficialLogin(): void;
}

export class AppRuntimeCallbackFactory {
  static settingsChoice(target: AppRuntimeCallbackTarget): SettingsChoiceRuntimeCallbacks {
    return {
      applyWindowPreferences: (): void => target.applyWindowPreferences(),
      applyDashboardPreferences: (): void => target.applyDashboardPreferences(),
      applyThemePreferences: (): void => target.applyThemePreferences(),
      refreshDashboardTheme: (): void => target.refreshDashboardTheme(),
      refreshCards: (): void => target.syncCardServerConnection(),
      refreshHomeNetworkStatus: (): void => target.refreshHomeNetworkStatus(false),
      bumpSettingsRevision: (): void => target.bumpSettingsRevision()
    };
  }

  static settingsInteraction(target: AppRuntimeCallbackTarget): SettingsInteractionCallbacks {
    return {
      context: (): common.Context => target.context(),
      currentServerInfo: (): StoredServerInfo => target.currentSettingsServerInfo(),
      applyServerInfo: (info: StoredServerInfo): void => target.applySettingsServerInfo(info),
      updateServerName: (name: string, info: StoredServerInfo): void => target.updateSettingsServerName(name, info),
      syncServerNameToHomeAssistant: (name: string, info: StoredServerInfo): void =>
        target.syncSettingsServerNameToHomeAssistant(name, info),
      setStep: (route: AppRoute): void => target.setStep(route),
      setMessage: (message: string): void => target.setMessage(message),
      bumpSwitchRevision: (): void => target.bumpSettingsRevision(),
      applyWindowPreferences: (): void => target.applyWindowPreferences(),
      applyDashboardPreferences: (): void => target.applyDashboardPreferences(),
      refreshCards: (): void => target.syncCardServerConnection(),
      ignoreAppLockTransitions: (): void => target.ignoreAppLockTransitions(),
      openServerSettings: (): void => target.openServerSettings(),
      startAddServerFromSettings: (): void => target.startAddServerFromSettings(),
      openCompanionChoiceDialog: (key: string): void => target.openCompanionChoiceDialog(key)
    };
  }

  static serverAccount(target: AppRuntimeCallbackTarget): ServerAccountRuntimeCallbacks {
    return {
      context: (): common.Context => target.context(),
      clearCardsForServer: (serverInstanceId: string): Promise<void> => CardRuntimeRepository.clearByServer(target.context(), serverInstanceId),
      stopDiscoveryAnimation: (): void => target.stopDiscoveryAnimation(),
      applyServerInfo: (info: StoredServerInfo): void => target.applyStoredServerInfo(info),
      resetSensorRuntime: (): void => target.resetSensorRuntime(),
      resetAddServerSnapshot: (): void => target.resetAddServerSnapshot(),
      bumpSettingsRevision: (): void => target.bumpSettingsRevision(),
      restoreAppSettings: (): Promise<void> => target.restoreInstanceAppSettingsState()
    };
  }

  static sensors(target: AppRuntimeCallbackTarget): SensorRuntimeCallbacks {
    return {
      context: (): common.Context => target.context(),
      snapshot: (): SensorRuntimeSnapshot => target.sensorRuntimeSnapshot(),
      applyFlags: (flags: SensorRuntimeFlags): void => target.applySensorFlags(flags),
      setLocationHistoryJson: (value: string): void => target.setLocationHistoryJsonValue(value),
      setLocationSentMode: (value: string): void => target.setLocationSentModeValue(value),
      setLocationDiagnosticsJson: (value: string): void => target.setLocationDiagnosticsJsonValue(value),
      setLocationGeofenceStatus: (value: string): void => target.setLocationGeofenceStatusValue(value),
      setMessage: (value: string): void => target.setMessage(value),
      bumpSwitchRevision: (): void => target.bumpSettingsRevision(),
      stringifyError: (err: Error | string | number | boolean | Object | ArrayBuffer): string => target.stringifyError(err)
    };
  }

  static externalAuth(target: AppRuntimeCallbackTarget): ExternalAuthRuntimeCallbacks {
    return {
      isWebMounted: (): boolean => target.isWebControllerMounted(),
      runScript: (script: string): void => target.tryRunWebScript(script),
      refreshAccessToken: (baseUrl: string): Promise<boolean> => target.refreshAccessToken(baseUrl),
      loadAccessToken: (baseUrl: string, forceRefresh: boolean): Promise<string> =>
        target.loadExternalAuthAccessToken(baseUrl, forceRefresh),
      currentServerInfo: (): StoredServerInfo => target.currentStoredServerInfo(),
      applyServerInfo: (info: StoredServerInfo): void => target.applyStoredServerInfo(info),
      openCompanionSettings: (): void => target.openCompanionSettings(),
      openAssistSettings: (): void => target.openAssistSettings(),
      openAssistConversation: (payload: Object | string): void => target.openAssistConversation(payload)
    };
  }

  static discovery(target: AppRuntimeCallbackTarget): DiscoveryFlowRuntimeCallbacks {
    return {
      context: (): common.Context => target.context(),
      setDiscoverySheetVisible: (visible: boolean): void => target.setDiscoverySheetVisible(visible),
      currentServerInfo: (): StoredServerInfo => target.currentStoredServerInfo(),
      applyServerInfo: (info: StoredServerInfo): void => target.applyStoredServerInfo(info),
      startOfficialLogin: (): void => target.startOfficialLogin()
    };
  }

  static dashboard(target: AppRuntimeCallbackTarget): DashboardRuntimeCallbacks {
    return {
      applyActiveTheme: (): void => target.applyActiveTheme(),
      applyWindowPreferences: (): void => target.applyWindowPreferences(),
      applyDashboardPreferences: (): void => target.applyDashboardPreferences()
    };
  }

  static registration(target: AppRuntimeCallbackTarget): RegistrationRuntimeCallbacks {
    return {
      currentServerInfo: (): StoredServerInfo => target.currentStoredServerInfo(),
      applyServerInfo: (info: StoredServerInfo): void => target.applyStoredServerInfo(info),
      refreshAccessToken: (baseUrl: string): Promise<boolean> => target.refreshAccessToken(baseUrl),
      syncPublicSensors: (reason: string): void => target.syncPublicSensors(reason),
      stringifyError: (err: Error | string | number | boolean | Object | ArrayBuffer): string => target.stringifyError(err),
      context: (): common.Context => target.context()
    };
  }

  static authFlow(target: AppRuntimeCallbackTarget): AuthFlowRuntimeCallbacks {
    return {
      currentServerInfo: (): StoredServerInfo => target.currentStoredServerInfo(),
      applyServerInfo: (info: StoredServerInfo): void => target.applyStoredServerInfo(info),
      stringifyError: (err: Error | string | number | boolean | Object | ArrayBuffer): string => target.stringifyError(err)
    };
  }

  static lifecycle(target: AppRuntimeCallbackTarget): AppLifecycleRuntimeCallbacks {
    return {
      initializeDeviceName: (): void => target.initializeDeviceName(),
      syncCardServerConnection: (): void => target.syncCardServerConnection(),
      applySensorDefaultMigration: (): void => target.applySensorDefaultMigration(),
      applyThemePreferences: (): void => target.applyThemePreferences(),
      subscribeBatteryEvents: (onEvent: () => void): void => target.subscribeBatteryEvents(onEvent),
      subscribeNetworkEvents: (onEvent: () => void): void => target.subscribeNetworkEvents(onEvent),
      subscribeDirectSensorEvents: (onEvent: (reason: string) => void): void =>
        target.subscribeDirectSensorEvents(onEvent),
      subscribeHardwareSensorEvents: (onEvent: (reason: string) => void): void =>
        target.subscribeHardwareSensorEvents(onEvent),
      refreshPeriodicSensorTimer: (): void => target.refreshPeriodicSensorTimer(),
      refreshHomeNetworkStatus: (allowDashboardUrlReload?: boolean): void =>
        target.refreshHomeNetworkStatus(allowDashboardUrlReload),
      syncPublicSensors: (reason: string): void => target.syncPublicSensors(reason),
      ensureMobileAppRegistration: (reason: string): void => target.ensureMobileAppRegistration(reason),
      startLocationSensorsIfNeeded: (): void => target.startLocationSensorsIfNeeded(),
      refreshLocationZones: (syncAfterRefresh: boolean): void => target.refreshLocationZones(syncAfterRefresh),
      reconcileBackgroundLocationPermission: (): void => target.reconcileBackgroundLocationPermission(),
      registerBackDispatcher: (handler: () => boolean): void => target.registerBackDispatcher(handler),
      handleBackNavigation: (): boolean => target.handleBackNavigation(),
      shouldLockApp: (): boolean => target.shouldLockApp(),
      fetchHaConfig: (): Promise<void> => target.fetchHaConfig(),
      stringifyError: (err: Error | string | number | boolean | Object | ArrayBuffer): string => target.stringifyError(err),
      clearBackDispatcher: (): void => target.clearBackDispatcher(),
      unsubscribeSystemEvents: (): void => target.unsubscribeSystemEvents(),
      stopSensorRuntime: (): void => target.stopSensorRuntime(),
      stopDiscoveryAnimation: (): void => target.stopDiscoveryAnimation(),
      refreshCurrentLocationForDiagnostics: (trigger: string): void => target.refreshCurrentLocationForDiagnostics(trigger),
      isIgnoringAppLockTransitions: (): boolean => target.isIgnoringAppLockTransitions(),
      applyWindowPreferences: (): void => target.applyWindowPreferences(),
      applyDashboardPreferences: (): void => target.applyDashboardPreferences(),
      maybeResetDashboardToFirstView: (): void => target.maybeResetDashboardToFirstView(),
      refreshDashboardTheme: (): void => target.refreshDashboardTheme(),
      prewarmDiscovery: (): void => target.prewarmDiscovery()
    };
  }

  static navigation(target: AppRuntimeCallbackTarget): AppNavigationRuntimeCallbacks {
    return {
      closeCompanionChoiceDialog: (): void => target.closeCompanionChoiceDialog(),
      setDiscoverySheetVisible: (visible: boolean): void => target.setDiscoverySheetVisible(visible),
      cancelAddServerFromSettings: (): void => target.cancelAddServerFromSettings(),
      stopDiscoveryAnimation: (): void => target.stopDiscoveryAnimation(),
      returnToHaSettingsPage: (): void => target.returnToHaSettingsPage(),
      canDashboardGoBack: (): boolean => target.canDashboardGoBack(),
      dashboardGoBack: (): void => target.dashboardGoBack()
    };
  }
}
