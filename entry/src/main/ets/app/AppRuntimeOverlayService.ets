import { DeviceProfileInfo } from '../shared/device/DeviceProfile';
import { Localization } from '../shared/i18n/Localization';
import { normalizeSensorUpdateFrequency, SensorGroup } from '../features/sensors/SensorModels';
import { AppRoute } from './AppRoute';
import { AppRuntimeOverlayActions, AppRuntimeOverlaySnapshot } from './AppRuntimeOverlayModels';

export interface AppRuntimeOverlayState {
  step: number;
  haBaseUrl: string;
  haAccessToken: string;
  haRefreshToken: string;
  assistStartListeningSignal: number;
  assistStartListeningRequested: boolean;
  sensorUpdateFrequency: string;
}

export interface AppRuntimeOverlayTarget extends AppRuntimeOverlayState {
  nativeFeatureBackTarget: number;
  message: string;
  currentDeviceProfile(): DeviceProfileInfo;
  settingsContentMaxWidth(): number;
  overlaySensorGroups(): SensorGroup[];
  overlayDirectSensorIds(): string[];
  healthAuthorizationState: string;
  handleBackNavigation(): boolean;
  toggleSensor(sensorId: string, enabled?: boolean): void;
  openHealthSensors(onAuthorized: () => void): void;
}

export class AppRuntimeOverlayService {
  static snapshot(target: AppRuntimeOverlayTarget): AppRuntimeOverlaySnapshot {
    const profile = target.currentDeviceProfile();
    return {
      route: target.step,
      baseUrl: target.haBaseUrl,
      accessToken: target.haAccessToken,
      refreshToken: target.haRefreshToken,
      assistStartListeningSignal: target.assistStartListeningSignal,
      assistStartListeningRequested: target.assistStartListeningRequested,
      profile: profile,
      sensorGroups: target.overlaySensorGroups(),
      directSensorIds: target.overlayDirectSensorIds(),
      healthAuthorizationState: target.healthAuthorizationState,
      sensorUpdateFrequency: target.sensorUpdateFrequency,
      contentMaxWidth: target.settingsContentMaxWidth()
    };
  }

  static actions(target: AppRuntimeOverlayTarget): AppRuntimeOverlayActions {
    return {
      onRoute: (route: number): void => {
        target.step = route;
      },
      onBackToNativeTarget: (): void => {
        target.step = target.nativeFeatureBackTarget;
      },
      onSwipeBack: (): void => {
        target.handleBackNavigation();
      },
      onCloseAssist: (): void => {
        target.step = AppRoute.DASHBOARD;
      },
      onSensorHelp: (): void => {
        target.message = 'https://companion.home-assistant.io/docs/core/sensors';
      },
      onSensorSearch: (): void => {
        target.message = Localization.t('sensor_search');
      },
      onSensorFilter: (): void => {
        target.message = Localization.t('sensor_filter');
      },
      onToggleSensor: (id: string, enabled: boolean): void => target.toggleSensor(id, enabled),
      onOpenHealthSensors: (onAuthorized: () => void): void => target.openHealthSensors(onAuthorized),
      onSelectSensorFrequency: (value: string): void => {
        target.sensorUpdateFrequency = normalizeSensorUpdateFrequency(value);
      }
    };
  }
}
