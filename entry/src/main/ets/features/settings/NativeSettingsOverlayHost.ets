import { AppRoute } from '../../app/AppRoute';
import { DeviceFormFactor, DeviceProfileInfo, DisplaySizeClass } from '../../shared/device/DeviceProfile';
import { NotificationSettingsPage } from '../notifications/NotificationSettingsPage';

class DefaultDeviceProfileInfo implements DeviceProfileInfo {
  widthVp: number = 0;
  heightVp: number = 0;
  formFactor: DeviceFormFactor = DeviceFormFactor.PHONE;
  sizeClass: DisplaySizeClass = DisplaySizeClass.COMPACT;
  contentMaxWidth: number = 0;
  settingsMaxWidth: number = 0;
}

@Component
export struct NativeSettingsOverlayHost {
  @Prop route: number = AppRoute.NOTIFICATION_SETTINGS;
  @Prop profile: DeviceProfileInfo = new DefaultDeviceProfileInfo();

  onBack: () => void = () => {};
  onOpenNotificationHistory: () => void = () => {};
  onSwipeBack: () => void = () => {};

  build() {
    if (this.route === AppRoute.NOTIFICATION_SETTINGS) {
      NotificationSettingsPage({
        contentMaxWidth: this.profile.settingsMaxWidth,
        onBack: this.onBack,
        onOpenHistory: this.onOpenNotificationHistory,
        onSwipeBack: this.onSwipeBack
      })
    }
  }
}
