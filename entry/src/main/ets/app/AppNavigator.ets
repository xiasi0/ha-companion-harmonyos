import { AppRoute } from './AppRoute';

export class AppNavigator {
  static isNativeOverlay(route: AppRoute): boolean {
    return route === AppRoute.COMPANION_SETTINGS ||
      route === AppRoute.SETTINGS_DETAIL ||
      route === AppRoute.SERVER_SETTINGS ||
      route === AppRoute.NOTIFICATION_SETTINGS ||
      route === AppRoute.SENSOR_SETTINGS ||
      route === AppRoute.SENSOR_UPDATE_FREQUENCY ||
      route === AppRoute.ASSIST_CONVERSATION ||
      route === AppRoute.CARD_BINDING;
  }

  static isOnboarding(route: AppRoute): boolean {
    return route === AppRoute.WELCOME ||
      route === AppRoute.DISCOVERY ||
      route === AppRoute.MANUAL_SERVER ||
      route === AppRoute.CONNECTION_ERROR ||
      route === AppRoute.LOGIN ||
      route === AppRoute.NAME_DEVICE ||
      route === AppRoute.LOCAL_FIRST ||
      route === AppRoute.LOCATION_SHARING ||
      route === AppRoute.SECURE_CONNECTION ||
      route === AppRoute.HOME_NETWORK;
  }

  static settingsBackTarget(route: AppRoute): AppRoute {
    if (route === AppRoute.SERVER_SETTINGS ||
      route === AppRoute.SETTINGS_DETAIL ||
      route === AppRoute.NOTIFICATION_SETTINGS ||
      route === AppRoute.SENSOR_SETTINGS ||
      route === AppRoute.SENSOR_UPDATE_FREQUENCY ||
      route === AppRoute.ASSIST_CONVERSATION ||
      route === AppRoute.CARD_BINDING) {
      return AppRoute.COMPANION_SETTINGS;
    }
    return AppRoute.DASHBOARD;
  }
}
