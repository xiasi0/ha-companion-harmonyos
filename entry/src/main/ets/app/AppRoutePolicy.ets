import { AppRoute } from './AppRoute';

export class AppRoutePolicy {
  static isNativeOnboardingStep(route: AppRoute): boolean {
    return route === AppRoute.WELCOME ||
      route === AppRoute.DISCOVERY ||
      route === AppRoute.MANUAL_SERVER ||
      route === AppRoute.CONNECTION_ERROR ||
      route === AppRoute.NAME_DEVICE ||
      route === AppRoute.LOCAL_FIRST ||
      route === AppRoute.LOCATION_SHARING ||
      route === AppRoute.SECURE_CONNECTION ||
      route === AppRoute.HOME_NETWORK;
  }
}
