import { SettingsItem } from '../../models/SettingsItem';
import { AppRoute } from '../../app/AppRoute';

export enum SettingsActionKind {
  NONE,
  OPEN_SERVER,
  ADD_SERVER,
  DELETE_SERVER,
  OPEN_NATIVE_FEATURE,
  OPEN_SETTINGS_DETAIL,
  OPEN_COMPANION_CHOICE
}

export interface SettingsActionDecision {
  kind: SettingsActionKind;
  route: AppRoute;
  detailKey: string;
  choiceKey: string;
}

export class SettingsRouteService {
  static emptyDecision(): SettingsActionDecision {
    return {
      kind: SettingsActionKind.NONE,
      route: AppRoute.WELCOME,
      detailKey: '',
      choiceKey: ''
    };
  }

  static isServerSettingItem(item: SettingsItem): boolean {
    return item.actionId.startsWith('server_');
  }

  static isCompanionSettingsFlowVisible(
    route: AppRoute,
    settingsDetailKey: string,
    nativeFeatureBackTarget: AppRoute
  ): boolean {
    if (route === AppRoute.COMPANION_SETTINGS) {
      return true;
    }
    if (route === AppRoute.SETTINGS_DETAIL && !settingsDetailKey.startsWith('server_')) {
      return true;
    }
    if (nativeFeatureBackTarget !== AppRoute.COMPANION_SETTINGS) {
      return false;
    }
    return route === AppRoute.NOTIFICATION_SETTINGS ||
      route === AppRoute.SENSOR_SETTINGS ||
      route === AppRoute.SENSOR_UPDATE_FREQUENCY ||
      route === AppRoute.HEALTH_SENSOR_SETTINGS;
  }

  static companionChoiceKey(actionId: string): string {
    if (actionId === 'open_display_orientation') {
      return 'display_orientation';
    }
    if (actionId === 'open_display_zoom') {
      return 'display_zoom';
    }
    if (actionId === 'open_display_language') {
      return 'display_language';
    }
    if (actionId === 'open_display_theme') {
      return 'display_theme';
    }
    if (actionId === 'server_connection_security') {
      return 'server_connection_security';
    }
    return '';
  }

  static nativeFeatureRoute(actionId: string): AppRoute {
    if (actionId === 'open_sensor_settings') {
      return AppRoute.SENSOR_SETTINGS;
    }
    if (actionId === 'open_sensor_update_frequency') {
      return AppRoute.SENSOR_UPDATE_FREQUENCY;
    }
    if (actionId === 'open_health_sensor_settings') {
      return AppRoute.HEALTH_SENSOR_SETTINGS;
    }
    if (actionId === 'open_notification_settings') {
      return AppRoute.NOTIFICATION_SETTINGS;
    }
    return AppRoute.WELCOME;
  }

  static decideAction(actionId: string): SettingsActionDecision {
    const decision = SettingsRouteService.emptyDecision();
    if (actionId === 'open_server') {
      decision.kind = SettingsActionKind.OPEN_SERVER;
      return decision;
    }
    if (actionId === 'add_server') {
      decision.kind = SettingsActionKind.ADD_SERVER;
      return decision;
    }
    if (actionId === 'delete_server') {
      decision.kind = SettingsActionKind.DELETE_SERVER;
      return decision;
    }
    if (actionId === 'open_display_gestures') {
      decision.kind = SettingsActionKind.OPEN_SETTINGS_DETAIL;
      decision.detailKey = 'display_gestures';
      return decision;
    }
    const choiceKey = SettingsRouteService.companionChoiceKey(actionId);
    if (choiceKey.length > 0) {
      decision.kind = SettingsActionKind.OPEN_COMPANION_CHOICE;
      decision.choiceKey = choiceKey;
      return decision;
    }
    const route = SettingsRouteService.nativeFeatureRoute(actionId);
    if (route !== AppRoute.WELCOME) {
      decision.kind = SettingsActionKind.OPEN_NATIVE_FEATURE;
      decision.route = route;
    }
    return decision;
  }
}
