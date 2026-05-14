import { Breakpoints } from './Breakpoints';

export enum DeviceFormFactor {
  PHONE,
  TABLET,
  WEARABLE,
  CAR,
  UNKNOWN
}

export enum DisplaySizeClass {
  COMPACT,
  MEDIUM,
  EXPANDED
}

export interface DeviceProfileInfo {
  widthVp: number;
  heightVp: number;
  formFactor: DeviceFormFactor;
  sizeClass: DisplaySizeClass;
  contentMaxWidth: number;
  settingsMaxWidth: number;
}

export class DeviceProfile {
  static fromSize(widthVp: number, heightVp: number): DeviceProfileInfo {
    let formFactor = DeviceFormFactor.PHONE;
    if (DeviceProfile.isWearableLike(widthVp, heightVp)) {
      formFactor = DeviceFormFactor.WEARABLE;
    } else if (widthVp >= Breakpoints.TABLET_MIN_WIDTH) {
      formFactor = DeviceFormFactor.TABLET;
    }

    return {
      widthVp,
      heightVp,
      formFactor,
      sizeClass: DeviceProfile.sizeClass(widthVp),
      contentMaxWidth: Breakpoints.onboardingContentMaxWidth(widthVp),
      settingsMaxWidth: Breakpoints.settingsContentMaxWidth(widthVp)
    };
  }

  private static isWearableLike(widthVp: number, heightVp: number): boolean {
    return widthVp > 0 &&
      heightVp > 0 &&
      widthVp <= Breakpoints.WEARABLE_MAX_WIDTH &&
      heightVp <= Breakpoints.WEARABLE_MAX_WIDTH;
  }

  private static sizeClass(widthVp: number): DisplaySizeClass {
    if (Breakpoints.isExpanded(widthVp)) {
      return DisplaySizeClass.EXPANDED;
    }
    if (Breakpoints.isMedium(widthVp)) {
      return DisplaySizeClass.MEDIUM;
    }
    return DisplaySizeClass.COMPACT;
  }

  static formFactorName(formFactor: DeviceFormFactor): string {
    if (formFactor === DeviceFormFactor.TABLET) {
      return 'tablet';
    }
    if (formFactor === DeviceFormFactor.WEARABLE) {
      return 'wearable';
    }
    if (formFactor === DeviceFormFactor.CAR) {
      return 'car';
    }
    if (formFactor === DeviceFormFactor.UNKNOWN) {
      return 'unknown';
    }
    return 'phone';
  }

  static sizeClassName(sizeClass: DisplaySizeClass): string {
    if (sizeClass === DisplaySizeClass.EXPANDED) {
      return 'expanded';
    }
    if (sizeClass === DisplaySizeClass.MEDIUM) {
      return 'medium';
    }
    return 'compact';
  }
}
