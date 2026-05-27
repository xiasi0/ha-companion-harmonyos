import { AppRoute } from './AppRoute';
import { AppBackDispatcher } from './AppBackDispatcher';
import { AppForegroundDecision, AppStartupCoordinator, StartupRestoreDecision } from './AppStartupCoordinator';
import { Localization } from '../shared/i18n/Localization';
import { UrlService } from '../services/UrlService';

export interface AppLifecycleRuntimeState {
  appLanguage: string;
  haBaseUrl: string;
  haAccessToken: string;
  appLocked: boolean;
  appUnlocking: boolean;
  dashboardUrl: string;
  dashboardCurrentUrl: string;
  dashboardClearHistoryPending: boolean;
  authUrl: string;
  showLoginWeb: boolean;
  dashboardBridgeReady: boolean;
  dashboardAuthProvided: boolean;
  step: number;
  message: string;
  appTheme: string;
  appResolvedDark: boolean;
}

export interface AppLifecycleRuntimeCallbacks {
  initializeDeviceName: () => void;
  syncCardServerConnection: () => void;
  applySensorDefaultMigration: () => void;
  applyThemePreferences: () => void;
  subscribeBatteryEvents: (onEvent: () => void) => void;
  subscribeNetworkEvents: (onEvent: () => void) => void;
  syncPublicSensors: (reason: string) => void;
  refreshHomeNetworkStatus: (allowDashboardUrlReload?: boolean) => void;
  ensureMobileAppRegistration: (reason: string) => void;
  startLocationSensorsIfNeeded: () => void;
  refreshLocationZones: (syncAfterRefresh: boolean) => void;
  reconcileBackgroundLocationPermission: () => void;
  registerBackDispatcher: (handler: () => boolean) => void;
  handleBackNavigation: () => boolean;
  shouldLockApp: () => boolean;
  fetchHaConfig: () => Promise<void>;
  stringifyError: (err: Error | string | number | boolean | Object | ArrayBuffer) => string;
  clearBackDispatcher: () => void;
  unsubscribeSystemEvents: () => void;
  stopSensorRuntime: () => void;
  stopDiscoveryAnimation: () => void;
  refreshCurrentLocationForDiagnostics: (trigger: string) => void;
  isIgnoringAppLockTransitions: () => boolean;
  applyWindowPreferences: () => void;
  applyDashboardPreferences: () => void;
  maybeResetDashboardToFirstView: () => void;
  refreshDashboardTheme: () => void;
  prewarmDiscovery: () => void;
}

export class AppLifecycleRuntimeService {
  static aboutToAppear(state: AppLifecycleRuntimeState, callbacks: AppLifecycleRuntimeCallbacks): void {
    Localization.setAppLanguage(state.appLanguage);
    callbacks.initializeDeviceName();
    callbacks.syncCardServerConnection();
    callbacks.ensureMobileAppRegistration('app_opened');
    callbacks.applySensorDefaultMigration();
    callbacks.applyThemePreferences();
    callbacks.subscribeBatteryEvents((): void => {
      callbacks.syncPublicSensors('battery_event');
    });
    callbacks.subscribeNetworkEvents((): void => {
      callbacks.refreshHomeNetworkStatus(false);
      callbacks.syncPublicSensors('network_event');
    });
    callbacks.startLocationSensorsIfNeeded();
    callbacks.refreshLocationZones(false);
    callbacks.registerBackDispatcher((): boolean => {
      return callbacks.handleBackNavigation();
    });
    callbacks.prewarmDiscovery();

    const restoredDashboardUrl = UrlService.buildDashboardUrl(UrlService.normalizeBaseUrl(state.haBaseUrl));
    state.appLocked = callbacks.shouldLockApp();
    const restoreDecision: StartupRestoreDecision = AppStartupCoordinator.restoreOnAppear({
      baseUrl: state.haBaseUrl,
      accessToken: state.haAccessToken,
      appLocked: state.appLocked,
      dashboardUrl: restoredDashboardUrl
    });
    if (restoreDecision.shouldRestoreDashboard && state.step === AppRoute.WELCOME) {
      AppLifecycleRuntimeService.applyRestoreDecision(state, restoreDecision);
      callbacks.fetchHaConfig().catch((e: Error | string | number | boolean | Object | ArrayBuffer) => {
        state.message = Localization.format('app_config_fetch_exception', 'error', callbacks.stringifyError(e));
      });
    } else if (restoreDecision.shouldRestoreDashboard) {
      callbacks.fetchHaConfig().catch((e: Error | string | number | boolean | Object | ArrayBuffer) => {
        state.message = Localization.format('app_config_fetch_exception', 'error', callbacks.stringifyError(e));
      });
    }
  }

  static aboutToDisappear(callbacks: AppLifecycleRuntimeCallbacks): void {
    callbacks.clearBackDispatcher();
    callbacks.unsubscribeSystemEvents();
    callbacks.stopSensorRuntime();
    callbacks.stopDiscoveryAnimation();
  }

  static onForeground(state: AppLifecycleRuntimeState, callbacks: AppLifecycleRuntimeCallbacks): void {
    callbacks.applyThemePreferences();
    callbacks.syncCardServerConnection();
    callbacks.ensureMobileAppRegistration('app_foreground');
    callbacks.prewarmDiscovery();
    callbacks.reconcileBackgroundLocationPermission();
    callbacks.refreshCurrentLocationForDiagnostics('app_foreground');
    callbacks.refreshHomeNetworkStatus(false);
    callbacks.syncPublicSensors('app_foreground');
    const decision: AppForegroundDecision = AppStartupCoordinator.foreground({
      route: state.step,
      shouldLock: callbacks.shouldLockApp(),
      ignoringLockTransitions: callbacks.isIgnoringAppLockTransitions()
    });
    if (decision.shouldLock) {
      state.appLocked = true;
      state.appUnlocking = false;
      state.message = decision.message;
      return;
    }
    if (!decision.shouldApplyWindowPreferences) {
      return;
    }
    callbacks.applyWindowPreferences();
    if (decision.shouldApplyDashboardPreferences) {
      callbacks.applyDashboardPreferences();
    }
  }

  static onBackground(state: AppLifecycleRuntimeState, callbacks: AppLifecycleRuntimeCallbacks): void {
    if (callbacks.isIgnoringAppLockTransitions()) {
      return;
    }
    if (callbacks.shouldLockApp()) {
      state.appLocked = true;
      state.appUnlocking = false;
    }
  }

  static onConfiguration(state: AppLifecycleRuntimeState, callbacks: AppLifecycleRuntimeCallbacks): void {
    const previousResolvedDark = state.appResolvedDark;
    callbacks.applyThemePreferences();
    callbacks.applyWindowPreferences();
    if (state.appTheme === 'system' && state.appResolvedDark !== previousResolvedDark) {
      callbacks.refreshDashboardTheme();
    }
  }

  private static applyRestoreDecision(state: AppLifecycleRuntimeState, restoreDecision: StartupRestoreDecision): void {
    state.dashboardUrl = restoreDecision.dashboardUrl;
    state.dashboardCurrentUrl = restoreDecision.dashboardUrl;
    state.dashboardClearHistoryPending = true;
    state.authUrl = restoreDecision.authUrl;
    state.showLoginWeb = restoreDecision.showLoginWeb;
    state.dashboardBridgeReady = restoreDecision.dashboardBridgeReady;
    state.dashboardAuthProvided = restoreDecision.dashboardAuthProvided;
    state.step = restoreDecision.route;
    state.message = restoreDecision.message;
  }
}
