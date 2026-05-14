import { Breakpoints } from '../shared/device/Breakpoints';
import { DeviceFormFactor, DeviceProfile, DeviceProfileInfo } from '../shared/device/DeviceProfile';

export interface AppDeviceRuntimeState {
  viewportWidth: number;
  viewportHeight: number;
}

export class AppDeviceRuntimeService {
  static defaultViewportWidth(): number {
    return Breakpoints.PHONE_MAX_WIDTH;
  }

  static updateViewportSize(state: AppDeviceRuntimeState, width: Length, height: Length): void {
    if (typeof width === 'number' && width > 0) {
      state.viewportWidth = width;
    }
    if (typeof height === 'number' && height > 0) {
      state.viewportHeight = height;
    }
  }

  static profile(state: AppDeviceRuntimeState): DeviceProfileInfo {
    return DeviceProfile.fromSize(state.viewportWidth, state.viewportHeight);
  }

  static onboardingContentMaxWidth(state: AppDeviceRuntimeState): number {
    return Breakpoints.onboardingContentMaxWidth(state.viewportWidth);
  }

  static settingsContentMaxWidth(state: AppDeviceRuntimeState): number {
    return AppDeviceRuntimeService.profile(state).settingsMaxWidth;
  }

  static isWearableProfile(state: AppDeviceRuntimeState): boolean {
    return AppDeviceRuntimeService.profile(state).formFactor === DeviceFormFactor.WEARABLE;
  }
}
