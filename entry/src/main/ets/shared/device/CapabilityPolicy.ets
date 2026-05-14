import { SettingsCapability } from '../../models/SettingsItem';
import { DeviceFormFactor, DeviceProfileInfo } from './DeviceProfile';
import { Localization } from '../i18n/Localization';

export enum CapabilityAvailability {
  AVAILABLE,
  PLACEHOLDER,
  HIDDEN
}

export interface CapabilityDecision {
  availability: CapabilityAvailability;
  reason: string;
}

export class CapabilityPolicy {
  static available(): CapabilityDecision {
    return {
      availability: CapabilityAvailability.AVAILABLE,
      reason: ''
    };
  }

  static placeholder(reason: string): CapabilityDecision {
    return {
      availability: CapabilityAvailability.PLACEHOLDER,
      reason
    };
  }

  static hidden(reason: string): CapabilityDecision {
    return {
      availability: CapabilityAvailability.HIDDEN,
      reason
    };
  }

  static companionSettings(profile: DeviceProfileInfo): CapabilityDecision {
    if (profile.formFactor === DeviceFormFactor.WEARABLE) {
      return CapabilityPolicy.placeholder(Localization.t('capability_companion_layout'));
    }
    if (profile.formFactor === DeviceFormFactor.CAR) {
      return CapabilityPolicy.placeholder(Localization.t('capability_car_placeholder'));
    }
    return CapabilityPolicy.available();
  }

  static assist(profile: DeviceProfileInfo): CapabilityDecision {
    if (profile.formFactor === DeviceFormFactor.CAR) {
      return CapabilityPolicy.placeholder(Localization.t('capability_assist_car'));
    }
    return CapabilityPolicy.placeholder(Localization.t('capability_assist_pending'));
  }

  static nfc(profile: DeviceProfileInfo): CapabilityDecision {
    if (profile.formFactor === DeviceFormFactor.WEARABLE || profile.formFactor === DeviceFormFactor.CAR) {
      return CapabilityPolicy.hidden(Localization.t('capability_nfc_hidden'));
    }
    return CapabilityPolicy.placeholder(Localization.t('capability_nfc_pending'));
  }

  static settingsCapability(capability: SettingsCapability, profile: DeviceProfileInfo): CapabilityDecision {
    if (capability === SettingsCapability.NONE) {
      return CapabilityPolicy.available();
    }
    if (capability === SettingsCapability.NFC) {
      return CapabilityPolicy.nfc(profile);
    }
    if (capability === SettingsCapability.ASSIST) {
      return CapabilityPolicy.assist(profile);
    }
    if (capability === SettingsCapability.APP_INFO) {
      return CapabilityPolicy.available();
    }
    if (profile.formFactor === DeviceFormFactor.WEARABLE) {
      return CapabilityPolicy.wearableSettingsCapability(capability);
    }
    if (profile.formFactor === DeviceFormFactor.CAR) {
      return CapabilityPolicy.carSettingsCapability(capability);
    }
    return CapabilityPolicy.phoneAndTabletSettingsCapability(capability);
  }

  private static phoneAndTabletSettingsCapability(capability: SettingsCapability): CapabilityDecision {
    if (capability === SettingsCapability.SERVER_MANAGEMENT ||
      capability === SettingsCapability.SERVER_CONNECTION ||
      capability === SettingsCapability.SENSORS ||
      capability === SettingsCapability.DISPLAY ||
      capability === SettingsCapability.NOTIFICATIONS ||
      capability === SettingsCapability.SECURITY ||
      capability === SettingsCapability.PERSISTENT_CONNECTION ||
      capability === SettingsCapability.WIDGETS) {
      return CapabilityPolicy.available();
    }
    return CapabilityPolicy.placeholder(Localization.t('capability_harmony_reserved'));
  }

  private static wearableSettingsCapability(capability: SettingsCapability): CapabilityDecision {
    if (capability === SettingsCapability.SERVER_MANAGEMENT ||
      capability === SettingsCapability.NOTIFICATIONS ||
      capability === SettingsCapability.ASSIST) {
      return CapabilityPolicy.placeholder(Localization.t('capability_wearable_placeholder'));
    }
    return CapabilityPolicy.hidden(Localization.t('capability_wearable_hidden'));
  }

  private static carSettingsCapability(capability: SettingsCapability): CapabilityDecision {
    if (capability === SettingsCapability.ASSIST ||
      capability === SettingsCapability.NOTIFICATIONS ||
      capability === SettingsCapability.SERVER_CONNECTION) {
      return CapabilityPolicy.placeholder(Localization.t('capability_car_placeholder'));
    }
    return CapabilityPolicy.hidden(Localization.t('capability_car_hidden'));
  }
}
