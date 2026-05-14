import { DeviceFormFactor, DeviceProfileInfo, DisplaySizeClass } from '../shared/device/DeviceProfile';
import { AssistRuntimeHost } from '../features/assist/AssistRuntimeHost';
import { NativeSettingsOverlayHost } from '../features/settings/NativeSettingsOverlayHost';
import { SensorSettingsOverlayHost } from '../features/sensors/SensorSettingsOverlayHost';
import { SensorUpdateFrequency } from '../features/sensors/SensorModels';
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
  sensorUpdateFrequency: SensorUpdateFrequency.NORMAL,
  contentMaxWidth: 720,
  switchRevision: 0
};

const DEFAULT_OVERLAY_ACTIONS: AppRuntimeOverlayActions = {
  onRoute: () => {},
  onBackToNativeTarget: () => {},
  onSwipeBack: () => {},
  onCloseAssist: () => {},
  onSensorHelp: () => {},
  onSensorSearch: () => {},
  onSensorFilter: () => {},
  onToggleSensor: () => {},
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
        } else if (this.snapshot.route === AppRoute.SENSOR_SETTINGS || this.snapshot.route === AppRoute.SENSOR_UPDATE_FREQUENCY) {
          Column() {
            SensorSettingsOverlayHost({
              route: this.snapshot.route,
              groups: this.snapshot.sensorGroups,
              selectedFrequency: this.snapshot.sensorUpdateFrequency,
              contentMaxWidth: this.snapshot.contentMaxWidth,
              switchRevision: this.snapshot.switchRevision,
              onBack: this.actions.onBackToNativeTarget,
              onHelp: this.actions.onSensorHelp,
              onSearch: this.actions.onSensorSearch,
              onFilter: this.actions.onSensorFilter,
              onToggleSensor: this.actions.onToggleSensor,
              onSelectFrequency: this.actions.onSelectSensorFrequency,
              onSwipeBack: this.actions.onSwipeBack
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
      this.snapshot.route === AppRoute.SENSOR_SETTINGS ||
      this.snapshot.route === AppRoute.SENSOR_UPDATE_FREQUENCY;
  }

  private isNativeSettingsRoute(): boolean {
    return this.snapshot.route === AppRoute.NOTIFICATION_SETTINGS;
  }
}
