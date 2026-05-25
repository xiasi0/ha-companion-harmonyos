import { AppRoute } from './AppRoute';
import { AppNavigator } from './AppNavigator';
import { Localization } from '../shared/i18n/Localization';
import { UrlService } from '../services/UrlService';

export interface AppNavigationRuntimeState {
  showCompanionChoiceDialog: boolean;
  showDiscoveredSheet: boolean;
  addingServerFromSettings: boolean;
  onboardingBackTarget: number;
  showLoginWeb: boolean;
  loading: boolean;
  step: number;
  secureConnectionFromSettings: boolean;
  settingsDetailKey: string;
  settingsDetailTitle: string;
  showDeleteServerDialog: boolean;
  showServerEditDialog: boolean;
  nativeFeatureBackTarget: number;
  dashboardCurrentUrl: string;
  connectionErrorBackTarget: number;
  connectionProbeToken: number;
}

export interface AppNavigationRuntimeCallbacks {
  closeCompanionChoiceDialog: () => void;
  setDiscoverySheetVisible: (visible: boolean) => void;
  cancelAddServerFromSettings: () => void;
  stopDiscoveryAnimation: () => void;
  returnToHaSettingsPage: () => void;
  currentDashboardUrl: () => string;
  canDashboardGoBack: () => boolean;
  dashboardGoBack: () => void;
  runDashboardScript: (script: string) => void;
}

export class AppNavigationRuntimeService {
  static handleBackNavigation(
    state: AppNavigationRuntimeState,
    callbacks: AppNavigationRuntimeCallbacks
  ): boolean {
    if (state.showCompanionChoiceDialog) {
      callbacks.closeCompanionChoiceDialog();
      return true;
    }
    if (state.showDiscoveredSheet) {
      callbacks.setDiscoverySheetVisible(false);
      return true;
    }
    if (state.secureConnectionFromSettings) {
      state.secureConnectionFromSettings = false;
      return true;
    }
    if (state.step === AppRoute.DISCOVERY) {
      if (state.addingServerFromSettings && state.onboardingBackTarget === AppRoute.COMPANION_SETTINGS) {
        callbacks.cancelAddServerFromSettings();
        return true;
      }
      callbacks.stopDiscoveryAnimation();
      state.connectionProbeToken += 1;
      state.loading = false;
      state.step = state.onboardingBackTarget;
      state.showLoginWeb = false;
      return true;
    }
    if (state.step === AppRoute.MANUAL_SERVER || state.step === AppRoute.LOGIN) {
      state.connectionProbeToken += 1;
      state.loading = false;
      state.step = AppRoute.DISCOVERY;
      state.showLoginWeb = false;
      return true;
    }
    if (state.step === AppRoute.CONNECTION_ERROR) {
      state.connectionProbeToken += 1;
      state.loading = false;
      state.step = state.connectionErrorBackTarget > 0 ? state.connectionErrorBackTarget : AppRoute.MANUAL_SERVER;
      state.showLoginWeb = false;
      return true;
    }
    if (state.step === AppRoute.NAME_DEVICE) {
      state.step = AppRoute.LOGIN;
      return true;
    }
    if (state.step === AppRoute.LOCAL_FIRST) {
      state.step = AppRoute.NAME_DEVICE;
      return true;
    }
    if (state.step === AppRoute.LOCATION_SHARING) {
      state.step = AppRoute.LOCAL_FIRST;
      return true;
    }
    if (state.step === AppRoute.SECURE_CONNECTION) {
      state.step = AppRoute.LOCATION_SHARING;
      return true;
    }
    if (state.step === AppRoute.HOME_NETWORK) {
      state.step = AppRoute.SECURE_CONNECTION;
      return true;
    }
    return AppNavigationRuntimeService.handleSettingsBack(state, callbacks);
  }

  private static handleSettingsBack(
    state: AppNavigationRuntimeState,
    callbacks: AppNavigationRuntimeCallbacks
  ): boolean {
    if (state.step === AppRoute.COMPANION_SETTINGS) {
      callbacks.returnToHaSettingsPage();
      return true;
    }
    if (state.step === AppRoute.SETTINGS_DETAIL) {
      if (state.settingsDetailKey.startsWith('gesture_action_')) {
        state.settingsDetailKey = 'display_gestures';
        state.settingsDetailTitle = Localization.t('settings_gestures');
        return true;
      }
      state.step = state.settingsDetailKey.startsWith('server_') ? AppRoute.SERVER_SETTINGS : AppRoute.COMPANION_SETTINGS;
      return true;
    }
    if (state.step === AppRoute.SERVER_SETTINGS) {
      if (state.showDeleteServerDialog) {
        state.showDeleteServerDialog = false;
        return true;
      }
      if (state.showServerEditDialog) {
        state.showServerEditDialog = false;
        return true;
      }
      state.step = AppNavigator.settingsBackTarget(AppRoute.SERVER_SETTINGS);
      return true;
    }
    if (state.step === AppRoute.ASSIST_CONVERSATION) {
      state.step = AppRoute.DASHBOARD;
      return true;
    }
    if (AppNavigationRuntimeService.isNativeSettingsRoute(state.step)) {
      state.step = state.nativeFeatureBackTarget;
      return true;
    }
    if (state.step === AppRoute.DASHBOARD) {
      return AppNavigationRuntimeService.handleDashboardBack(state, callbacks);
    }
    return false;
  }

  private static handleDashboardBack(
    state: AppNavigationRuntimeState,
    callbacks: AppNavigationRuntimeCallbacks
  ): boolean {
    const currentUrl = callbacks.currentDashboardUrl();
    if (UrlService.isDashboardHomeUrl(currentUrl)) {
      return false;
    }
    if (callbacks.canDashboardGoBack()) {
      callbacks.dashboardGoBack();
      return true;
    }
    callbacks.runDashboardScript('history.back();');
    return true;
  }

  private static isNativeSettingsRoute(route: number): boolean {
    return route === AppRoute.NOTIFICATION_SETTINGS ||
      route === AppRoute.SENSOR_SETTINGS ||
      route === AppRoute.SENSOR_UPDATE_FREQUENCY;
  }
}
