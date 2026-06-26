import { DeviceFormFactor, DeviceProfileInfo, DisplaySizeClass } from '../shared/device/DeviceProfile';
import { AssistRuntimeHost } from '../features/assist/AssistRuntimeHost';
import { NativeSettingsOverlayHost } from '../features/settings/NativeSettingsOverlayHost';
import { HealthSensorCatalog } from '../features/sensors/HealthSensorCatalog';
import { SensorSettingsOverlayHost } from '../features/sensors/SensorSettingsOverlayHost';
import { SensorGroup, SensorUpdateFrequency } from '../features/sensors/SensorModels';
import { AppRoute } from './AppRoute';
import { AppRuntimeOverlayActions, AppRuntimeOverlaySnapshot } from './AppRuntimeOverlayModels';

class DefaultDeviceProfileInfo implements DeviceProfileInfo {
  widthVp: number = 0;
  heightVp: number = 0;
  formFactor: DeviceFormFactor = DeviceFormFactor.PHONE;
  sizeClass: DisplaySizeClass = DisplaySizeClass.COMPACT;
  contentMaxWidth: number = 0;
  settingsMaxWidth: number = 0;
}

const DEFAULT_OVERLAY_SNAPSHOT: AppRuntimeOverlaySnapshot = {
  route: AppRoute.DASHBOARD,
  baseUrl: '',
  accessToken: '',
  refreshToken: '',
  assistStartListeningSignal: 0,
  assistStartListeningRequested: false,
  profile: new DefaultDeviceProfileInfo(),
  sensorGroups: [],
  directSensorIds: [],
  healthAuthorizationState: 'unknown',
  sensorUpdateFrequency: SensorUpdateFrequency.NORMAL,
  contentMaxWidth: 720
};

const DEFAULT_OVERLAY_ACTIONS: AppRuntimeOverlayActions = {
  onRoute: () => {},
  onBackToNativeTarget: () => {},
  onSwipeBack: () => {},
  onCloseAssist: () => {},
  onSensorHelp: () => {},
  onSensorSearch: () => {},
  onSensorFilter: () => {},
  onToggleSensor: (_id: string, _enabled: boolean): void => {},
  onOpenHealthSensors: (_onAuthorized: () => void): void => {},
  onSelectSensorFrequency: () => {}
};

@Component
export struct AppRuntimeOverlaysHost {
  @Prop snapshot: AppRuntimeOverlaySnapshot = DEFAULT_OVERLAY_SNAPSHOT;
  @Prop route: number = AppRoute.DASHBOARD;
  actions: AppRuntimeOverlayActions = DEFAULT_OVERLAY_ACTIONS;

  build() {
    if (this.shouldRenderOverlay()) {
      Stack() {
        if (this.snapshot.route === AppRoute.ASSIST_CONVERSATION) {
          Column() {
            AssistRuntimeHost({
              route: this.snapshot.route,
              baseUrl: this.snapshot.baseUrl,
              accessToken: this.snapshot.accessToken,
              startListeningSignal: this.snapshot.assistStartListeningSignal,
              startListeningRequested: this.snapshot.assistStartListeningRequested,
              onClose: this.actions.onCloseAssist
            })
          }
          .width('100%')
          .height('100%')
        } else if (this.isNativeSettingsRoute()) {
          Column() {
            NativeSettingsOverlayHost({
              route: this.snapshot.route,
              profile: this.snapshot.profile,
              onBack: this.actions.onBackToNativeTarget,
              onSwipeBack: this.actions.onSwipeBack
            })
          }
          .width('100%')
          .height('100%')
        } else if (this.isSensorOverlayRoute()) {
          Column() {
            SensorSettingsOverlayHost({
              route: this.snapshot.route,
              groups: this.sensorOverlayGroups(),
              selectedFrequency: this.snapshot.sensorUpdateFrequency,
              contentMaxWidth: this.snapshot.contentMaxWidth,
              showControls: this.snapshot.route !== AppRoute.HEALTH_SENSOR_SETTINGS,
              healthAuthorizationState: this.snapshot.route === AppRoute.HEALTH_SENSOR_SETTINGS
                ? this.snapshot.healthAuthorizationState
                : '',
              onBack: this.sensorOverlayBackAction(),
              onHelp: this.actions.onSensorHelp,
              onSearch: this.actions.onSensorSearch,
              onFilter: this.actions.onSensorFilter,
              onToggleSensor: this.actions.onToggleSensor,
              onOpenHealthSensors: (): void => {
                this.actions.onOpenHealthSensors((): void => this.actions.onRoute(AppRoute.HEALTH_SENSOR_SETTINGS));
              },
              onSelectFrequency: this.actions.onSelectSensorFrequency,
              onSwipeBack: this.sensorOverlayBackAction()
            })
          }
          .width('100%')
          .height('100%')
        }

      }
      .width('100%')
      .height('100%')
    }
  }

  private shouldRenderOverlay(): boolean {
    return this.snapshot.route === AppRoute.ASSIST_CONVERSATION ||
      this.isNativeSettingsRoute() ||
      this.isSensorOverlayRoute();
  }

  private isNativeSettingsRoute(): boolean {
    return this.snapshot.route === AppRoute.NOTIFICATION_SETTINGS;
  }

  private isSensorOverlayRoute(): boolean {
    return this.snapshot.route === AppRoute.SENSOR_SETTINGS ||
      this.snapshot.route === AppRoute.SENSOR_UPDATE_FREQUENCY ||
      this.snapshot.route === AppRoute.HEALTH_SENSOR_SETTINGS;
  }

  private sensorOverlayGroups(): SensorGroup[] {
    if (this.snapshot.route === AppRoute.HEALTH_SENSOR_SETTINGS) {
      return HealthSensorCatalog.groups(this.snapshot.directSensorIds);
    }
    return this.snapshot.sensorGroups;
  }

  private sensorOverlayBackAction(): () => void {
    if (this.snapshot.route === AppRoute.HEALTH_SENSOR_SETTINGS) {
      return (): void => this.actions.onRoute(AppRoute.SENSOR_SETTINGS);
    }
    return this.actions.onBackToNativeTarget;
  }
}
