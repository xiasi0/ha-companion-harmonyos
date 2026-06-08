// Collects HarmonyOS device sensor snapshots and publishes them to Home Assistant mobile_app webhooks.
// This file owns sensor payload shape, preference snapshots, and foreground update behavior.
import batteryInfo from '@ohos.batteryInfo';
import deviceInfo from '@ohos.deviceInfo';
import hidebug from '@ohos.hidebug';
import storageStatistics from '@ohos.file.storageStatistics';
import power from '@ohos.power';
import thermal from '@ohos.thermal';
import audio from '@ohos.multimedia.audio';
import motion from '@ohos.multimodalAwareness.motion';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import bluetoothAccess from '@ohos.bluetooth.access';
import nfcController from '@ohos.nfc.controller';
import display from '@ohos.display';
import vibrator from '@ohos.vibrator';
import geoLocationManager from '@ohos.geoLocationManager';
import { wifiManager } from '@kit.ConnectivityKit';
import type { Permissions } from '@ohos.abilityAccessCtrl';
import { NetworkHttpMethod, NetworkNetBearType, NetworkNetCap, NetworkService } from './NetworkService';
import { AppVersionService } from './AppVersionService';
import { Localization } from '../shared/i18n/Localization';
import { HarmonyLocationSnapshot, HarmonyLocationZone } from './HarmonyLocationService';
import { HarmonySensorEntityCategoryPolicy } from './HarmonySensorEntityCategoryPolicy';
import {
  GetZonesWebhookBody,
  HarmonyLocationSentMode,
  HarmonySensorSyncResult,
  HttpTextResult,
  NetSnapshot,
  RegisterSensorWebhookBody,
  SensorRegistrationWebhookData,
  SensorAttributes,
  SensorDescriptor,
  SensorPreferenceSnapshot,
  SensorUpdateWebhookData,
  UpdateLocationWebhookData,
  UpdateLocationWebhookBody,
  UpdateSensorStatesWebhookBody,
  WebhookResult
} from './HarmonySensorModels';

export {
  HarmonyLocationSentMode,
  HarmonySensorSyncResult,
  SensorPreferenceSnapshot
} from './HarmonySensorModels';

const SENSOR_TEXT_UNAVAILABLE = 'unavailable';
const SENSOR_TEXT_UNKNOWN = 'UNKNOWN';
const SENSOR_ICON_GENERIC = 'mdi:cellphone-cog';

interface HarmonyWifiSnapshot {
  active: boolean;
  connected: boolean;
  hotspotActive: boolean;
  ssid: string;
  bssid: string;
  hidden: boolean;
  rssi?: number;
  signalLevel?: number;
  frequency?: number;
  linkSpeed?: number;
  ipAddress: string;
}

interface HarmonyStorageSnapshot {
  totalSize?: number;
  freeSize?: number;
  usedSize?: number;
  usedPercent?: number;
}

interface HarmonyAudioVolumeSnapshot {
  minVolume?: number;
  maxVolume?: number;
  volumePercent?: number;
}

interface HarmonyAudioRouteSnapshot {
  outputDeviceTypes: string[];
  headphoneConnected: boolean;
  speakerActive: boolean;
  audioScene: string;
}

interface HarmonyDisplaySnapshot {
  available: boolean;
  state: string;
  width: number;
  height: number;
  availableWidth: number;
  availableHeight: number;
  refreshRate?: number;
  rotation?: number;
  orientation: string;
  densityDPI?: number;
  densityPixels?: number;
  scaledDensity?: number;
  xDPI?: number;
  yDPI?: number;
  screenShape: string;
  hdrFormats: string[];
  sourceMode: string;
  foldable: boolean;
  foldStatus: string;
  foldDisplayMode: string;
  brightnessSdrNits?: number;
  brightnessCurrentHeadroom?: number;
  brightnessMaxHeadroom?: number;
}

interface HardwareSensorValues {
  light?: number;
  lightColorTemperature?: number;
  lightInfraredLuminance?: number;
  pressure?: number;
  proximity?: number;
  steps?: number;
  stepDetected?: boolean;
  updatedAt?: number;
}

interface MultimodalSensorValues {
  operatingHand?: number;
  holdingHand?: number;
  updatedAt?: number;
}

interface GeocodedLocationValue {
  geocoderAvailable?: boolean;
  latitude?: number;
  longitude?: number;
  sourceTimeStamp?: number;
  placeName?: string;
  countryCode?: string;
  countryName?: string;
  administrativeArea?: string;
  subAdministrativeArea?: string;
  locality?: string;
  subLocality?: string;
  roadName?: string;
  subRoadName?: string;
  premises?: string;
  postalCode?: string;
}

interface SensorUpdateResponseError {
  code?: string;
  message?: string;
}

interface SensorUpdateResponseItem {
  success?: boolean;
  error?: SensorUpdateResponseError;
}

interface SensorUpdateResponseSummary {
  successfulDescriptors: SensorDescriptor[];
  unregisteredDescriptors: SensorDescriptor[];
}

export class HarmonySensorService {
  private static lastSensorRegistrationSignatures: Map<string, string> = new Map<string, string>();
  private static lastSensorUpdateSignatures: Map<string, string> = new Map<string, string>();

  private static readonly CORE_PUBLIC_SENSOR_IDS: string[] = [
    'battery_level',
    'battery_state',
    'charger_type',
    'network_type',
    'last_update_trigger',
    'location_background',
    'zone_background',
    'accurate_location'
  ];

  private static readonly DIRECT_PUBLIC_SENSOR_IDS: string[] = [
    'is_charging',
    'battery_health',
    'battery_temperature',
    'battery_voltage',
    'battery_current',
    'battery_power',
    'battery_technology',
    'battery_capacity_level',
    'battery_present',
    'wifi_state',
    'wifi_connection',
    'wifi_bssid',
    'wifi_ip_address',
    'wifi_frequency',
    'wifi_signal_strength',
    'wifi_link_speed',
    'hotspot_state',
    'current_version',
    'harmony_os_version',
    'harmony_os_security_patch',
    'harmony_device_type',
    'harmony_product_model',
    'harmony_performance_class',
    'harmony_boot_count',
    'storage_sensor',
    'active',
    'app_memory',
    'is_interactive',
    'is_idle',
    'power_save',
    'current_time_zone',
    'bluetooth_state',
    'audio_sensor',
    'audio_mode',
    'headphone_state',
    'speakerphone_state',
    'volume_alarm',
    'volume_call',
    'volume_music',
    'volume_ring',
    'volume_notification',
    'volume_accessibility',
    'harmony_thermal_level',
    'harmony_vibrator_effect_support',
    'harmony_operating_hand',
    'harmony_holding_hand',
    'location_permission',
    'nfc_state',
    'display_state',
    'screen_orientation',
    'screen_rotation',
    'screen_resolution',
    'display_refresh_rate',
    'display_density',
    'screen_brightness',
    'display_brightness_headroom',
    'harmony_screen_shape',
    'harmony_display_hdr_formats',
    'harmony_foldable',
    'harmony_fold_status',
    'harmony_fold_display_mode',
    'geocoded_location',
    'light_sensor',
    'pressure_sensor',
    'proximity_sensor',
    'steps_sensor'
  ];

  static supportedPublicSensorIds(): string[] {
    return HarmonySensorService.CORE_PUBLIC_SENSOR_IDS.concat(HarmonySensorService.DIRECT_PUBLIC_SENSOR_IDS);
  }

  static isCorePublicSensor(sensorId: string): boolean {
    return HarmonySensorService.containsText(HarmonySensorService.CORE_PUBLIC_SENSOR_IDS, sensorId);
  }

  static isSupportedPublicSensor(sensorId: string): boolean {
    return HarmonySensorService.containsText(HarmonySensorService.CORE_PUBLIC_SENSOR_IDS, sensorId) ||
      HarmonySensorService.containsText(HarmonySensorService.DIRECT_PUBLIC_SENSOR_IDS, sensorId);
  }

  static directSensorIdsFromJson(value: string): string[] {
    try {
      const parsed = JSON.parse(value) as string[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      return HarmonySensorService.normalizeDirectSensorIds(parsed);
    } catch (_) {
      return [];
    }
  }

  static directSensorIdsToJson(value: string[]): string {
    return JSON.stringify(HarmonySensorService.normalizeDirectSensorIds(value));
  }

  static normalizeDirectSensorIds(value: string[]): string[] {
    const result: string[] = [];
    for (let i = 0; i < value.length; i++) {
      const item = value[i];
      if (HarmonySensorService.isSupportedPublicSensor(item) &&
        !HarmonySensorService.isCorePublicSensor(item) &&
        !HarmonySensorService.containsText(result, item)) {
        result.push(item);
      }
    }
    return result;
  }

  static sensorSummary(sensorId: string, prefs: SensorPreferenceSnapshot): string {
    if (!HarmonySensorService.isSupportedPublicSensor(sensorId)) {
      return Localization.t('sensor_unavailable_summary');
    }
    if (sensorId === 'accurate_location') {
      return Localization.t('sensor_accurate_summary');
    }
    if (sensorId === 'zone_background') {
      return Localization.t('sensor_zone_summary');
    }
    if (sensorId === 'location_background') {
      return Localization.t('sensor_background_summary');
    }
    return '';
  }

  static isSensorEnabled(sensorId: string, prefs: SensorPreferenceSnapshot): boolean {
    switch (sensorId) {
      case 'battery_level':
        return prefs.batterySOCEnabled;
      case 'battery_state':
        return prefs.chargingStatusEnabled;
      case 'charger_type':
        return prefs.pluggedTypeEnabled;
      case 'network_type':
        return prefs.bearerTypesEnabled;
      case 'last_update_trigger':
        return prefs.lastUpdateTriggerEnabled;
      case 'location_background':
        return prefs.locationBackgroundEnabled;
      case 'zone_background':
        return prefs.zoneBackgroundEnabled;
      case 'accurate_location':
        return prefs.accurateLocationEnabled;
      default:
        return HarmonySensorService.containsText(prefs.directSensorIds, sensorId);
    }
  }

  static async syncPublicSensors(
    baseUrl: string,
    webhookId: string,
    cloudhookUrl: string,
    prefs: SensorPreferenceSnapshot,
    lastLocation: HarmonyLocationSnapshot | undefined,
    locationEnabledStatus: boolean,
    currentZoneName: string,
    locationSentMode: HarmonyLocationSentMode,
    sendLocationUpdate: boolean,
    reason: string
  ): Promise<HarmonySensorSyncResult> {
    const normalizedBaseUrl = HarmonySensorService.normalizeBaseUrl(baseUrl);
    const trimmedWebhookId = webhookId.trim();
    if (normalizedBaseUrl.length === 0 || trimmedWebhookId.length === 0) {
      return {
        registeredCount: 0,
        updatedCount: 0,
        locationUpdated: false,
        locationSummary: 'missing_webhook'
      };
    }

    await HarmonySensorService.refreshGeocodedLocationIfNeeded(prefs, lastLocation);
    const descriptors = HarmonySensorService.buildSensorDescriptors(
      prefs,
      lastLocation,
      locationEnabledStatus,
      locationSentMode
    );
    const webhookUrls = HarmonySensorService.webhookUrls(normalizedBaseUrl, trimmedWebhookId, cloudhookUrl);
    let registeredCount = 0;
    let updatedCount = 0;
    const registrationDescriptors = HarmonySensorService.changedRegistrationDescriptors(
      normalizedBaseUrl,
      trimmedWebhookId,
      descriptors,
      reason
    );

    if (registrationDescriptors.length > 0) {
      registeredCount = await HarmonySensorService.registerSensorDescriptors(
        normalizedBaseUrl,
        trimmedWebhookId,
        webhookUrls,
        registrationDescriptors
      );
    }

    const enabledSensors = descriptors.filter((item: SensorDescriptor) => item.enabled);
    const changedSensors = HarmonySensorService.changedSensorDescriptors(
      normalizedBaseUrl,
      trimmedWebhookId,
      enabledSensors
    );
    if (changedSensors.length > 0) {
      const result = await HarmonySensorService.postWebhookWithFallback(
        webhookUrls,
        HarmonySensorService.updateSensorStatesBody(changedSensors),
        false
      );
      if (HarmonySensorService.isWebhookWriteAccepted(result, false)) {
        const summary = HarmonySensorService.sensorUpdateResponseSummary(result.body, changedSensors);
        if (summary.unregisteredDescriptors.length > 0) {
          registeredCount += await HarmonySensorService.registerSensorDescriptors(
            normalizedBaseUrl,
            trimmedWebhookId,
            webhookUrls,
            summary.unregisteredDescriptors
          );
        }
        HarmonySensorService.rememberSensorUpdateSignatures(
          normalizedBaseUrl,
          trimmedWebhookId,
          summary.successfulDescriptors
        );
        updatedCount = summary.successfulDescriptors.length;
      }
    }

    let locationUpdated = false;
    let locationSummary = 'not_requested';
    if (sendLocationUpdate &&
      locationEnabledStatus &&
      lastLocation &&
      (prefs.locationBackgroundEnabled || prefs.zoneBackgroundEnabled || prefs.accurateLocationEnabled) &&
      locationSentMode !== 'never') {
      const locationBody = HarmonySensorService.updateLocationBody(
        lastLocation,
        currentZoneName,
        locationSentMode
      );
      if (locationBody) {
        const locationResult = await HarmonySensorService.postWebhookWithFallback(webhookUrls, locationBody, false);
        locationUpdated = locationResult.responseCode >= 200 && locationResult.responseCode < 300;
        locationSummary = `update_location:${locationResult.responseCode}:${NetworkService.shortText(locationResult.body)}`;
      } else {
        locationSummary = 'update_location_skipped_no_location';
      }
    } else if (locationSentMode === 'never') {
      locationSummary = 'location_never';
    } else if (sendLocationUpdate && !locationEnabledStatus) {
      locationSummary = 'location_disabled';
    } else if (sendLocationUpdate && !lastLocation) {
      locationSummary = 'update_location_skipped_no_location';
    }

    return {
      registeredCount,
      updatedCount,
      locationUpdated,
      locationSummary
    };
  }

  static async fetchZones(
    baseUrl: string,
    webhookId: string,
    cloudhookUrl: string
  ): Promise<HarmonyLocationZone[]> {
    const normalizedBaseUrl = HarmonySensorService.normalizeBaseUrl(baseUrl);
    const trimmedWebhookId = webhookId.trim();
    if (normalizedBaseUrl.length === 0 || trimmedWebhookId.length === 0) {
      return [];
    }
    const webhookUrls = HarmonySensorService.webhookUrls(normalizedBaseUrl, trimmedWebhookId, cloudhookUrl);
    const body: GetZonesWebhookBody = {
      type: 'get_zones'
    };
    for (let i = 0; i < webhookUrls.length; i++) {
      const result = await HarmonySensorService.postWebhookForText(webhookUrls[i], body);
      if (result.responseCode >= 200 && result.responseCode < 300) {
        return HarmonySensorService.parseZones(result.body);
      }
    }
    return [];
  }

  static async clearDeviceTrackerLocation(
    baseUrl: string,
    webhookId: string,
    cloudhookUrl: string
  ): Promise<WebhookResult> {
    const normalizedBaseUrl = HarmonySensorService.normalizeBaseUrl(baseUrl);
    const trimmedWebhookId = webhookId.trim();
    if (normalizedBaseUrl.length === 0 || trimmedWebhookId.length === 0) {
      return {
        responseCode: 0,
        body: '',
        failureSummary: 'missing_webhook'
      };
    }
    const body: UpdateLocationWebhookBody = {
      type: 'update_location',
      data: {}
    };
    return HarmonySensorService.postWebhookWithFallback(
      HarmonySensorService.webhookUrls(normalizedBaseUrl, trimmedWebhookId, cloudhookUrl),
      body,
      false
    );
  }

  private static buildSensorDescriptors(
    prefs: SensorPreferenceSnapshot,
    lastLocation: HarmonyLocationSnapshot | undefined,
    locationEnabledStatus: boolean,
    locationSentMode: HarmonyLocationSentMode
  ): SensorDescriptor[] {
    const netSnapshot = HarmonySensorService.getNetworkSnapshot();
    const wifiSnapshot = HarmonySensorService.getWifiSnapshot();
    const storageSnapshot = HarmonySensorService.getStorageSnapshot();
    const displaySnapshot = HarmonySensorService.getDisplaySnapshot();
    const hardwareSnapshot = HarmonySensorService.hardwareSensorValues();
    const multimodalSnapshot = HarmonySensorService.multimodalSensorValues();
    const geocodedLocation = HarmonySensorService.geocodedLocationValue();
    const audioRouteSnapshot = HarmonySensorService.audioRouteSnapshot();
    const batterySOC = HarmonySensorService.batteryLevelValue();
    const batteryState = HarmonySensorService.batteryStateValue();
    const pluggedType = HarmonySensorService.chargerTypeValue();
    const batteryTemperature = HarmonySensorService.batteryTemperatureValue();
    const batteryVoltage = HarmonySensorService.batteryVoltageValue();
    const batteryCurrent = HarmonySensorService.batteryCurrentValue();
    const batteryPower = HarmonySensorService.batteryPowerValue(batteryVoltage, batteryCurrent);
    const locationAttributes = HarmonySensorService.locationAttributes(lastLocation, locationSentMode);
    const lastUpdateTrigger = AppStorage.get<string>('lastUpdateTrigger') ?? 'unknown';

    const descriptors: SensorDescriptor[] = [
      {
        id: 'battery_level',
        name: 'Battery level',
        type: 'sensor',
        icon: HarmonySensorService.batteryLevelIcon(batterySOC, batteryState, pluggedType),
        state: batterySOC,
        attributes: {},
        enabled: prefs.batterySOCEnabled,
        deviceClass: 'battery',
        unitOfMeasurement: '%',
        stateClass: 'measurement',
      },
      {
        id: 'is_charging',
        name: 'Is charging',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: batteryState === 'charging' || batteryState === 'full',
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('is_charging', prefs),
      },
      {
        id: 'battery_state',
        name: 'Battery state',
        type: 'sensor',
        icon: HarmonySensorService.batteryStateIcon(batteryState),
        state: batteryState,
        attributes: HarmonySensorService.batteryStateAttributes(),
        enabled: prefs.chargingStatusEnabled,
        deviceClass: 'enum',
      },
      {
        id: 'battery_health',
        name: 'Battery health',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.batteryHealthValue(),
        attributes: HarmonySensorService.batteryHealthAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('battery_health', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'battery_temperature',
        name: 'Battery temperature',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(batteryTemperature),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('battery_temperature', prefs),
        deviceClass: 'temperature',
        unitOfMeasurement: '°C',
        stateClass: 'measurement',
      },
      {
        id: 'battery_voltage',
        name: 'Battery voltage',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(batteryVoltage),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('battery_voltage', prefs),
        deviceClass: 'voltage',
        unitOfMeasurement: 'V',
        stateClass: 'measurement',
      },
      {
        id: 'battery_current',
        name: 'Battery current',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(batteryCurrent),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('battery_current', prefs),
        deviceClass: 'current',
        unitOfMeasurement: 'mA',
        stateClass: 'measurement',
      },
      {
        id: 'battery_power',
        name: 'Battery power',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(batteryPower),
        attributes: {
          battery_voltage: batteryVoltage,
          battery_current: batteryCurrent
        },
        enabled: HarmonySensorService.isSensorEnabled('battery_power', prefs),
        deviceClass: 'power',
        unitOfMeasurement: 'W',
        stateClass: 'measurement',
      },
      {
        id: 'battery_technology',
        name: 'Battery technology',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(batteryInfo.technology ?? ''),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('battery_technology', prefs),
      },
      {
        id: 'battery_capacity_level',
        name: 'Battery capacity level',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.batteryCapacityLevelValue(),
        attributes: HarmonySensorService.batteryCapacityLevelAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('battery_capacity_level', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'battery_present',
        name: 'Battery present',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: batteryInfo.isBatteryPresent,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('battery_present', prefs),
      },
      {
        id: 'charger_type',
        name: 'Charger type',
        type: 'sensor',
        icon: HarmonySensorService.chargerTypeIcon(pluggedType),
        state: HarmonySensorService.nonEmptyText(pluggedType),
        attributes: HarmonySensorService.chargerTypeAttributes(),
        enabled: prefs.pluggedTypeEnabled,
        deviceClass: 'enum',
      },
      {
        id: 'wifi_state',
        name: 'Wi-Fi state',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: wifiSnapshot.active,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('wifi_state', prefs),
      },
      {
        id: 'wifi_connection',
        name: 'Wi-Fi connection',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(wifiSnapshot.ssid),
        attributes: {
          hidden: wifiSnapshot.hidden,
          signal_level: wifiSnapshot.signalLevel,
          frequency: wifiSnapshot.frequency,
          link_speed: wifiSnapshot.linkSpeed,
          ip_address: wifiSnapshot.ipAddress
        },
        enabled: HarmonySensorService.isSensorEnabled('wifi_connection', prefs),
      },
      {
        id: 'wifi_bssid',
        name: 'Wi-Fi BSSID',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(wifiSnapshot.bssid),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('wifi_bssid', prefs),
      },
      {
        id: 'wifi_ip_address',
        name: 'Wi-Fi IP address',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(wifiSnapshot.ipAddress),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('wifi_ip_address', prefs),
      },
      {
        id: 'wifi_frequency',
        name: 'Wi-Fi frequency',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.wifiMeasurementState(wifiSnapshot, wifiSnapshot.frequency),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('wifi_frequency', prefs),
        unitOfMeasurement: 'MHz',
        stateClass: 'measurement',
      },
      {
        id: 'wifi_signal_strength',
        name: 'Wi-Fi signal strength',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.wifiMeasurementState(wifiSnapshot, wifiSnapshot.rssi),
        attributes: {
          signal_level: wifiSnapshot.signalLevel
        },
        enabled: HarmonySensorService.isSensorEnabled('wifi_signal_strength', prefs),
        unitOfMeasurement: 'dBm',
        stateClass: 'measurement',
      },
      {
        id: 'wifi_link_speed',
        name: 'Wi-Fi link speed',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.wifiMeasurementState(wifiSnapshot, wifiSnapshot.linkSpeed),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('wifi_link_speed', prefs),
        unitOfMeasurement: 'Mbps',
        stateClass: 'measurement',
      },
      {
        id: 'hotspot_state',
        name: 'Hotspot state',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: wifiSnapshot.hotspotActive,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('hotspot_state', prefs),
      },
      {
        id: 'network_type',
        name: 'Network type',
        type: 'sensor',
        icon: HarmonySensorService.networkTypeIcon(netSnapshot.networkType),
        state: HarmonySensorService.nonEmptyText(netSnapshot.networkType),
        attributes: HarmonySensorService.networkTypeAttributes(netSnapshot.metered),
        enabled: prefs.bearerTypesEnabled,
        deviceClass: 'enum',
      },
      {
        id: 'current_version',
        name: 'App version',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: AppVersionService.versionName(),
        attributes: {
          version_code: AppVersionService.versionInfo().versionCode
        },
        enabled: HarmonySensorService.isSensorEnabled('current_version', prefs),
      },
      {
        id: 'harmony_os_version',
        name: 'HarmonyOS version',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(deviceInfo.displayVersion ?? deviceInfo.osFullName ?? ''),
        attributes: {
          os_full_name: deviceInfo.osFullName ?? '',
          sdk_api_version: deviceInfo.sdkApiVersion ?? 0,
          display_version: deviceInfo.displayVersion ?? ''
        },
        enabled: HarmonySensorService.isSensorEnabled('harmony_os_version', prefs),
      },
      {
        id: 'harmony_os_security_patch',
        name: 'HarmonyOS security patch',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(deviceInfo.securityPatchTag ?? ''),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('harmony_os_security_patch', prefs),
      },
      {
        id: 'harmony_device_type',
        name: 'HarmonyOS device type',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(deviceInfo.deviceType ?? ''),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('harmony_device_type', prefs),
      },
      {
        id: 'harmony_product_model',
        name: 'HarmonyOS product model',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.productModelValue(),
        attributes: {
          manufacturer: deviceInfo.manufacture ?? '',
          brand: deviceInfo.brand ?? '',
          market_name: deviceInfo.marketName ?? '',
          product_model: deviceInfo.productModel ?? ''
        },
        enabled: HarmonySensorService.isSensorEnabled('harmony_product_model', prefs),
      },
      {
        id: 'harmony_performance_class',
        name: 'HarmonyOS performance class',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(`${deviceInfo.performanceClass ?? ''}`),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('harmony_performance_class', prefs),
      },
      {
        id: 'harmony_boot_count',
        name: 'HarmonyOS boot count',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(deviceInfo.bootCount),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('harmony_boot_count', prefs),
        stateClass: 'measurement',
      },
      {
        id: 'active',
        name: 'Active',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: AppStorage.get<boolean>('appActive') ?? false,
        attributes: {
          app_active: AppStorage.get<boolean>('appActive') ?? false
        },
        enabled: HarmonySensorService.isSensorEnabled('active', prefs),
      },
      {
        id: 'app_memory',
        name: 'App memory',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(HarmonySensorService.appMemoryPss()),
        attributes: HarmonySensorService.appMemoryAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('app_memory', prefs),
        unitOfMeasurement: 'KB',
        stateClass: 'measurement',
      },
      {
        id: 'storage_sensor',
        name: 'Internal storage',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(storageSnapshot.usedPercent),
        attributes: {
          total_size: storageSnapshot.totalSize,
          free_size: storageSnapshot.freeSize,
          used_size: storageSnapshot.usedSize,
          used_percent: storageSnapshot.usedPercent
        },
        enabled: HarmonySensorService.isSensorEnabled('storage_sensor', prefs),
        unitOfMeasurement: '%',
        stateClass: 'measurement',
      },
      {
        id: 'is_interactive',
        name: 'Interactive',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.powerIsActive(),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('is_interactive', prefs),
      },
      {
        id: 'is_idle',
        name: 'Idle',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.powerIsStandby(),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('is_idle', prefs),
      },
      {
        id: 'power_save',
        name: 'Power save',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.powerSaveEnabled(),
        attributes: {
          power_mode: HarmonySensorService.powerModeValue()
        },
        enabled: HarmonySensorService.isSensorEnabled('power_save', prefs),
      },
      {
        id: 'current_time_zone',
        name: 'Current time zone',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.currentTimeZoneValue(),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('current_time_zone', prefs),
      },
      {
        id: 'bluetooth_state',
        name: 'Bluetooth state',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.bluetoothEnabled(),
        attributes: {
          options: [HarmonySensorService.bluetoothStateValue()]
        },
        enabled: HarmonySensorService.isSensorEnabled('bluetooth_state', prefs),
      },
      {
        id: 'audio_sensor',
        name: 'Ringer mode',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.ringerModeValue(),
        attributes: HarmonySensorService.ringerModeAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('audio_sensor', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'audio_mode',
        name: 'Audio mode',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: audioRouteSnapshot.audioScene,
        attributes: {
          audio_scene: audioRouteSnapshot.audioScene,
          options: ['default', 'ringing', 'phone_call', 'voice_chat']
        },
        enabled: HarmonySensorService.isSensorEnabled('audio_mode', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'headphone_state',
        name: 'Headphones',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: audioRouteSnapshot.headphoneConnected,
        attributes: HarmonySensorService.audioRouteAttributes(audioRouteSnapshot),
        enabled: HarmonySensorService.isSensorEnabled('headphone_state', prefs),
      },
      {
        id: 'speakerphone_state',
        name: 'Speakerphone',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: audioRouteSnapshot.speakerActive,
        attributes: HarmonySensorService.audioRouteAttributes(audioRouteSnapshot),
        enabled: HarmonySensorService.isSensorEnabled('speakerphone_state', prefs),
      },
      HarmonySensorService.volumeDescriptor('volume_alarm', 'Volume level alarm', audio.StreamUsage.STREAM_USAGE_ALARM, prefs),
      HarmonySensorService.volumeDescriptor('volume_call', 'Volume level call', audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION, prefs),
      HarmonySensorService.volumeDescriptor('volume_music', 'Volume level music', audio.StreamUsage.STREAM_USAGE_MUSIC, prefs),
      HarmonySensorService.volumeDescriptor('volume_ring', 'Volume level ringer', audio.StreamUsage.STREAM_USAGE_RINGTONE, prefs),
      HarmonySensorService.volumeDescriptor('volume_notification', 'Volume level notification', audio.StreamUsage.STREAM_USAGE_NOTIFICATION, prefs),
      HarmonySensorService.volumeDescriptor('volume_accessibility', 'Volume level accessibility', audio.StreamUsage.STREAM_USAGE_ACCESSIBILITY, prefs),
      {
        id: 'harmony_thermal_level',
        name: 'HarmonyOS thermal level',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.thermalLevelValue(),
        attributes: HarmonySensorService.thermalLevelAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('harmony_thermal_level', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'harmony_vibrator_effect_support',
        name: 'HarmonyOS vibrator effect support',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.vibratorEffectSupported(),
        attributes: HarmonySensorService.vibratorEffectAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('harmony_vibrator_effect_support', prefs),
      },
      {
        id: 'harmony_operating_hand',
        name: 'HarmonyOS operating hand',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.operatingHandState(multimodalSnapshot.operatingHand),
        attributes: {
          sensor_updated_at: multimodalSnapshot.updatedAt,
          options: ['unknown', 'left_hand', 'right_hand']
        },
        enabled: HarmonySensorService.isSensorEnabled('harmony_operating_hand', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'harmony_holding_hand',
        name: 'HarmonyOS holding hand',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.holdingHandState(multimodalSnapshot.holdingHand),
        attributes: {
          sensor_updated_at: multimodalSnapshot.updatedAt,
          options: ['unknown', 'not_held', 'left_hand', 'right_hand', 'both_hands']
        },
        enabled: HarmonySensorService.isSensorEnabled('harmony_holding_hand', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'location_permission',
        name: 'Location permission',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.locationPermissionValue(),
        attributes: HarmonySensorService.locationPermissionAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('location_permission', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'geocoded_location',
        name: 'Geocoded location',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.geocodedLocationState(geocodedLocation),
        attributes: HarmonySensorService.geocodedLocationAttributes(geocodedLocation),
        enabled: HarmonySensorService.isSensorEnabled('geocoded_location', prefs),
      },
      {
        id: 'nfc_state',
        name: 'NFC state',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nfcEnabled(),
        attributes: {
          nfc_state: HarmonySensorService.nfcStateValue()
        },
        enabled: HarmonySensorService.isSensorEnabled('nfc_state', prefs),
        deviceClass: 'connectivity',
      },
      {
        id: 'display_state',
        name: 'Display state',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: displaySnapshot.state,
        attributes: HarmonySensorService.displayStateAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('display_state', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'screen_orientation',
        name: 'Screen orientation',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: displaySnapshot.orientation,
        attributes: HarmonySensorService.displayOrientationAttributes(displaySnapshot),
        enabled: HarmonySensorService.isSensorEnabled('screen_orientation', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'screen_rotation',
        name: 'Screen rotation',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(displaySnapshot.rotation),
        attributes: {
          options: ['0', '90', '180', '270']
        },
        enabled: HarmonySensorService.isSensorEnabled('screen_rotation', prefs),
        unitOfMeasurement: '°',
        stateClass: 'measurement',
      },
      {
        id: 'screen_resolution',
        name: 'Screen resolution',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.displayResolutionValue(displaySnapshot),
        attributes: HarmonySensorService.displayResolutionAttributes(displaySnapshot),
        enabled: HarmonySensorService.isSensorEnabled('screen_resolution', prefs),
      },
      {
        id: 'display_refresh_rate',
        name: 'Display refresh rate',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(displaySnapshot.refreshRate),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('display_refresh_rate', prefs),
        unitOfMeasurement: 'Hz',
        stateClass: 'measurement',
      },
      {
        id: 'display_density',
        name: 'Display density',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(displaySnapshot.densityDPI),
        attributes: HarmonySensorService.displayDensityAttributes(displaySnapshot),
        enabled: HarmonySensorService.isSensorEnabled('display_density', prefs),
        unitOfMeasurement: 'dpi',
        stateClass: 'measurement',
      },
      {
        id: 'screen_brightness',
        name: 'Screen brightness',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(displaySnapshot.brightnessSdrNits),
        attributes: HarmonySensorService.displayBrightnessAttributes(displaySnapshot),
        enabled: HarmonySensorService.isSensorEnabled('screen_brightness', prefs),
        unitOfMeasurement: 'nit',
        stateClass: 'measurement',
      },
      {
        id: 'light_sensor',
        name: 'Light sensor',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(hardwareSnapshot.light),
        attributes: {
          color_temperature: hardwareSnapshot.lightColorTemperature,
          infrared_luminance: hardwareSnapshot.lightInfraredLuminance,
          sensor_updated_at: hardwareSnapshot.updatedAt
        },
        enabled: HarmonySensorService.isSensorEnabled('light_sensor', prefs),
        deviceClass: 'illuminance',
        unitOfMeasurement: 'lx',
        stateClass: 'measurement',
      },
      {
        id: 'pressure_sensor',
        name: 'Pressure sensor',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(hardwareSnapshot.pressure),
        attributes: {
          sensor_updated_at: hardwareSnapshot.updatedAt
        },
        enabled: HarmonySensorService.isSensorEnabled('pressure_sensor', prefs),
        deviceClass: 'atmospheric_pressure',
        unitOfMeasurement: 'hPa',
        stateClass: 'measurement',
      },
      {
        id: 'proximity_sensor',
        name: 'Proximity sensor',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(hardwareSnapshot.proximity),
        attributes: {
          sensor_updated_at: hardwareSnapshot.updatedAt
        },
        enabled: HarmonySensorService.isSensorEnabled('proximity_sensor', prefs),
      },
      {
        id: 'steps_sensor',
        name: 'Steps sensor',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(hardwareSnapshot.steps),
        attributes: {
          step_detected: hardwareSnapshot.stepDetected,
          sensor_updated_at: hardwareSnapshot.updatedAt
        },
        enabled: HarmonySensorService.isSensorEnabled('steps_sensor', prefs),
        unitOfMeasurement: 'steps',
        stateClass: 'total_increasing',
      },
      {
        id: 'display_brightness_headroom',
        name: 'Display brightness headroom',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(displaySnapshot.brightnessCurrentHeadroom),
        attributes: HarmonySensorService.displayBrightnessAttributes(displaySnapshot),
        enabled: HarmonySensorService.isSensorEnabled('display_brightness_headroom', prefs),
        stateClass: 'measurement',
      },
      {
        id: 'harmony_screen_shape',
        name: 'HarmonyOS screen shape',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: displaySnapshot.screenShape,
        attributes: HarmonySensorService.screenShapeAttributes(),
        enabled: HarmonySensorService.isSensorEnabled('harmony_screen_shape', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'harmony_display_hdr_formats',
        name: 'HarmonyOS display HDR formats',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(HarmonySensorService.displayHdrFormatCount(displaySnapshot)),
        attributes: {
          hdr_formats: displaySnapshot.hdrFormats,
          source_mode: displaySnapshot.sourceMode
        },
        enabled: HarmonySensorService.isSensorEnabled('harmony_display_hdr_formats', prefs),
        stateClass: 'measurement',
      },
      {
        id: 'harmony_foldable',
        name: 'HarmonyOS foldable',
        type: 'binary_sensor',
        icon: SENSOR_ICON_GENERIC,
        state: displaySnapshot.foldable,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('harmony_foldable', prefs),
      },
      {
        id: 'harmony_fold_status',
        name: 'HarmonyOS fold status',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: displaySnapshot.foldStatus,
        attributes: HarmonySensorService.foldStatusAttributes(displaySnapshot),
        enabled: HarmonySensorService.isSensorEnabled('harmony_fold_status', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'harmony_fold_display_mode',
        name: 'HarmonyOS fold display mode',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: displaySnapshot.foldDisplayMode,
        attributes: HarmonySensorService.foldDisplayModeAttributes(displaySnapshot),
        enabled: HarmonySensorService.isSensorEnabled('harmony_fold_display_mode', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'last_update_trigger',
        name: 'Last update trigger',
        type: 'sensor',
        icon: 'mdi:update',
        state: HarmonySensorService.nonEmptyText(lastUpdateTrigger),
        attributes: {},
        enabled: prefs.lastUpdateTriggerEnabled,
      },
      {
        id: 'location_background',
        name: 'Background location',
        type: 'binary_sensor',
        icon: 'mdi:map-marker-multiple',
        state: prefs.locationBackgroundEnabled && locationEnabledStatus,
        attributes: locationAttributes,
        enabled: prefs.locationBackgroundEnabled,
      },
      {
        id: 'zone_background',
        name: 'Location zone',
        type: 'binary_sensor',
        icon: 'mdi:map-marker-radius',
        state: prefs.zoneBackgroundEnabled,
        attributes: locationAttributes,
        enabled: prefs.zoneBackgroundEnabled,
      },
      {
        id: 'accurate_location',
        name: 'Single accurate location',
        type: 'binary_sensor',
        icon: 'mdi:crosshairs-gps',
        state: prefs.accurateLocationEnabled,
        attributes: locationAttributes,
        enabled: prefs.accurateLocationEnabled,
      }
    ];
    return HarmonySensorEntityCategoryPolicy.apply(descriptors);
  }

  private static locationAttributes(
    lastLocation: HarmonyLocationSnapshot | undefined,
    locationSentMode: HarmonyLocationSentMode
  ): SensorAttributes {
    if (!lastLocation) {
      return {
        accuracy: null,
        timeStamp: null,
        gps_accuracy: null,
        location_sent: 'none'
      };
    }
    return {
      accuracy: lastLocation.accuracy,
      timeStamp: lastLocation.timeStamp,
      gps_accuracy: Math.round(lastLocation.accuracy),
      location_sent: locationSentMode
    };
  }

  private static updateLocationBody(
    lastLocation: HarmonyLocationSnapshot | undefined,
    currentZoneName: string,
    locationSentMode: HarmonyLocationSentMode
  ): UpdateLocationWebhookBody | undefined {
    const data: UpdateLocationWebhookData = {};
    if (locationSentMode === 'zone') {
      data.location_name = currentZoneName.length > 0 ? currentZoneName : 'not_home';
      return {
        type: 'update_location',
        data
      };
    }
    if (!lastLocation) {
      return undefined;
    }
    const batterySOC = HarmonySensorService.batteryLevelValue();
    data.gps = [lastLocation.latitude, lastLocation.longitude];
    data.gps_accuracy = Math.max(Math.round(lastLocation.accuracy), 1);
    if (batterySOC > 0) {
      data.battery = batterySOC;
    }
    if (typeof lastLocation.speed === 'number' && lastLocation.speed > 0) {
      data.speed = Math.round(lastLocation.speed);
    }
    if (typeof lastLocation.altitude === 'number' && lastLocation.altitude > 0) {
      data.altitude = Math.round(lastLocation.altitude);
    }
    if (typeof lastLocation.direction === 'number' && lastLocation.direction > 0) {
      data.course = Math.round(lastLocation.direction);
    }
    if (typeof lastLocation.altitudeAccuracy === 'number' && lastLocation.altitudeAccuracy > 0) {
      data.vertical_accuracy = Math.round(lastLocation.altitudeAccuracy);
    }
    return {
      type: 'update_location',
      data
    };
  }

  private static registerSensorBody(descriptor: SensorDescriptor): RegisterSensorWebhookBody {
    const data: SensorRegistrationWebhookData = {
      unique_id: descriptor.id,
      state: descriptor.enabled ? HarmonySensorService.webhookState(descriptor.state) : null,
      type: descriptor.type,
      icon: descriptor.icon,
      attributes: descriptor.attributes,
      name: descriptor.name,
      disabled: !descriptor.enabled
    };
    if (descriptor.deviceClass) {
      data.device_class = descriptor.deviceClass;
    }
    if (descriptor.unitOfMeasurement) {
      data.unit_of_measurement = descriptor.unitOfMeasurement;
    }
    if (descriptor.stateClass) {
      data.state_class = descriptor.stateClass;
    }
    if (descriptor.entityCategory) {
      data.entity_category = descriptor.entityCategory;
    }
    return {
      type: 'register_sensor',
      data
    };
  }

  private static changedRegistrationDescriptors(
    baseUrl: string,
    webhookId: string,
    descriptors: SensorDescriptor[],
    reason: string
  ): SensorDescriptor[] {
    if (HarmonySensorService.shouldForceSensorRegistration(reason)) {
      return descriptors;
    }
    const changed: SensorDescriptor[] = [];
    for (let i = 0; i < descriptors.length; i++) {
      const descriptor = descriptors[i];
      const key = HarmonySensorService.sensorRegistrationSignatureKey(baseUrl, webhookId, descriptor.id);
      const signature = HarmonySensorService.sensorRegistrationSignature(descriptor);
      if (HarmonySensorService.lastSensorRegistrationSignatures.get(key) !== signature) {
        changed.push(descriptor);
      }
    }
    return changed;
  }

  private static shouldForceSensorRegistration(reason: string): boolean {
    return reason === 'device_registered' ||
      reason === 'server_switched';
  }

  private static async registerSensorDescriptors(
    baseUrl: string,
    webhookId: string,
    webhookUrls: string[],
    descriptors: SensorDescriptor[]
  ): Promise<number> {
    let registeredCount = 0;
    for (let i = 0; i < descriptors.length; i++) {
      const descriptor = descriptors[i];
      const result = await HarmonySensorService.postWebhookWithFallback(
        webhookUrls,
        HarmonySensorService.registerSensorBody(descriptor),
        true
      );
      if (!HarmonySensorService.isWebhookWriteAccepted(result, true)) {
        continue;
      }
      HarmonySensorService.lastSensorRegistrationSignatures.set(
        HarmonySensorService.sensorRegistrationSignatureKey(baseUrl, webhookId, descriptor.id),
        HarmonySensorService.sensorRegistrationSignature(descriptor)
      );
      if (descriptor.enabled && HarmonySensorService.isWebhookSuccess(result)) {
        HarmonySensorService.lastSensorUpdateSignatures.set(
          HarmonySensorService.sensorUpdateSignatureKey(baseUrl, webhookId, descriptor.id),
          HarmonySensorService.sensorUpdateSignature(descriptor)
        );
      }
      registeredCount += 1;
    }
    return registeredCount;
  }

  private static isWebhookWriteAccepted(result: WebhookResult, allowConflict: boolean): boolean {
    return HarmonySensorService.isWebhookSuccess(result) ||
      (allowConflict && result.responseCode === 409);
  }

  private static isWebhookSuccess(result: WebhookResult): boolean {
    return result.responseCode >= 200 && result.responseCode < 300;
  }

  private static sensorRegistrationSignatureKey(baseUrl: string, webhookId: string, sensorId: string): string {
    return `${baseUrl}|${webhookId}|${sensorId}`;
  }

  private static sensorRegistrationSignature(descriptor: SensorDescriptor): string {
    return [
      descriptor.id,
      descriptor.name,
      descriptor.type,
      descriptor.icon,
      descriptor.enabled ? '1' : '0',
      descriptor.deviceClass ?? '',
      descriptor.unitOfMeasurement ?? '',
      descriptor.stateClass ?? '',
      descriptor.entityCategory ?? ''
    ].join(':');
  }

  private static updateSensorStatesBody(descriptors: SensorDescriptor[]): UpdateSensorStatesWebhookBody {
    const items: SensorUpdateWebhookData[] = descriptors.map((descriptor: SensorDescriptor): SensorUpdateWebhookData => {
      return {
        unique_id: descriptor.id,
        state: HarmonySensorService.webhookState(descriptor.state),
        type: descriptor.type,
        icon: descriptor.icon,
        attributes: descriptor.attributes
      };
    });

    return {
      type: 'update_sensor_states',
      data: items
    };
  }

  private static changedSensorDescriptors(
    baseUrl: string,
    webhookId: string,
    descriptors: SensorDescriptor[]
  ): SensorDescriptor[] {
    const changed: SensorDescriptor[] = [];
    for (let i = 0; i < descriptors.length; i++) {
      const descriptor = descriptors[i];
      const key = HarmonySensorService.sensorUpdateSignatureKey(baseUrl, webhookId, descriptor.id);
      const signature = HarmonySensorService.sensorUpdateSignature(descriptor);
      if (HarmonySensorService.lastSensorUpdateSignatures.get(key) !== signature) {
        changed.push(descriptor);
      }
    }
    return changed;
  }

  private static sensorUpdateResponseSummary(
    body: string,
    descriptors: SensorDescriptor[]
  ): SensorUpdateResponseSummary {
    const parsed = HarmonySensorService.sensorUpdateResponseItems(body);
    if (!parsed) {
      return {
        successfulDescriptors: descriptors,
        unregisteredDescriptors: []
      };
    }
    const successfulDescriptors: SensorDescriptor[] = [];
    const unregisteredDescriptors: SensorDescriptor[] = [];
    for (let i = 0; i < descriptors.length; i++) {
      const descriptor = descriptors[i];
      const item = parsed[descriptor.id];
      if (item?.success === false) {
        if (item.error?.code === 'not_registered') {
          unregisteredDescriptors.push(descriptor);
        }
      } else {
        successfulDescriptors.push(descriptor);
      }
    }
    return {
      successfulDescriptors,
      unregisteredDescriptors
    };
  }

  private static sensorUpdateResponseItems(body: string): Record<string, SensorUpdateResponseItem> | undefined {
    const trimmed = body.trim();
    if (trimmed.length === 0) {
      return undefined;
    }
    try {
      const parsed = JSON.parse(trimmed) as Record<string, SensorUpdateResponseItem>;
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return undefined;
      }
      return parsed;
    } catch (_) {
      return undefined;
    }
  }

  private static rememberSensorUpdateSignatures(
    baseUrl: string,
    webhookId: string,
    descriptors: SensorDescriptor[]
  ): void {
    for (let i = 0; i < descriptors.length; i++) {
      const descriptor = descriptors[i];
      HarmonySensorService.lastSensorUpdateSignatures.set(
        HarmonySensorService.sensorUpdateSignatureKey(baseUrl, webhookId, descriptor.id),
        HarmonySensorService.sensorUpdateSignature(descriptor)
      );
    }
  }

  private static sensorUpdateSignatureKey(baseUrl: string, webhookId: string, sensorId: string): string {
    return `${baseUrl}|${webhookId}|${sensorId}`;
  }

  private static sensorUpdateSignature(descriptor: SensorDescriptor): string {
    return [
      HarmonySensorService.webhookState(descriptor.state),
      descriptor.type,
      descriptor.icon,
      HarmonySensorService.attributeSignature(descriptor.attributes)
    ].join('|');
  }

  private static webhookState(state: string | number | boolean | null): string | number | boolean | null {
    if (typeof state === 'string' && state.trim().length === 0) {
      return null;
    }
    return state;
  }

  private static attributeSignature(attributes: SensorAttributes): string {
    const parts: string[] = [];
    HarmonySensorService.appendAttributeSignature(parts, 'accuracy', attributes.accuracy);
    HarmonySensorService.appendAttributeSignature(parts, 'administrative_area', attributes.administrative_area);
    HarmonySensorService.appendAttributeSignature(parts, 'app_active', attributes.app_active);
    HarmonySensorService.appendAttributeSignature(parts, 'app_memory_native_heap_allocated_size', attributes.app_memory_native_heap_allocated_size);
    HarmonySensorService.appendAttributeSignature(parts, 'app_memory_native_heap_free_size', attributes.app_memory_native_heap_free_size);
    HarmonySensorService.appendAttributeSignature(parts, 'app_memory_native_heap_size', attributes.app_memory_native_heap_size);
    HarmonySensorService.appendAttributeSignature(parts, 'app_memory_private_dirty', attributes.app_memory_private_dirty);
    HarmonySensorService.appendAttributeSignature(parts, 'app_memory_shared_dirty', attributes.app_memory_shared_dirty);
    HarmonySensorService.appendAttributeSignature(parts, 'app_memory_vss', attributes.app_memory_vss);
    HarmonySensorService.appendAttributeSignature(parts, 'approximate_location', attributes.approximate_location);
    HarmonySensorService.appendAttributeSignature(parts, 'audio_scene', attributes.audio_scene);
    HarmonySensorService.appendAttributeSignature(parts, 'background_location', attributes.background_location);
    HarmonySensorService.appendAttributeSignature(parts, 'battery_current', attributes.battery_current);
    HarmonySensorService.appendAttributeSignature(parts, 'battery_voltage', attributes.battery_voltage);
    HarmonySensorService.appendAttributeSignature(parts, 'brand', attributes.brand);
    HarmonySensorService.appendAttributeSignature(parts, 'bssid', attributes.bssid);
    HarmonySensorService.appendAttributeSignature(parts, 'color_temperature', attributes.color_temperature);
    HarmonySensorService.appendAttributeSignature(parts, 'country_code', attributes.country_code);
    HarmonySensorService.appendAttributeSignature(parts, 'country_name', attributes.country_name);
    HarmonySensorService.appendAttributeSignature(parts, 'current_headroom', attributes.current_headroom);
    HarmonySensorService.appendAttributeSignature(parts, 'display_available_height', attributes.display_available_height);
    HarmonySensorService.appendAttributeSignature(parts, 'display_available_width', attributes.display_available_width);
    HarmonySensorService.appendAttributeSignature(parts, 'display_density_pixels', attributes.display_density_pixels);
    HarmonySensorService.appendAttributeSignature(parts, 'display_height', attributes.display_height);
    HarmonySensorService.appendAttributeSignature(parts, 'display_rotation', attributes.display_rotation);
    HarmonySensorService.appendAttributeSignature(parts, 'display_scaled_density', attributes.display_scaled_density);
    HarmonySensorService.appendAttributeSignature(parts, 'display_state', attributes.display_state);
    HarmonySensorService.appendAttributeSignature(parts, 'display_version', attributes.display_version);
    HarmonySensorService.appendAttributeSignature(parts, 'display_width', attributes.display_width);
    HarmonySensorService.appendAttributeSignature(parts, 'display_x_dpi', attributes.display_x_dpi);
    HarmonySensorService.appendAttributeSignature(parts, 'display_y_dpi', attributes.display_y_dpi);
    HarmonySensorService.appendAttributeSignature(parts, 'fold_display_mode', attributes.fold_display_mode);
    HarmonySensorService.appendAttributeSignature(parts, 'fold_status', attributes.fold_status);
    HarmonySensorService.appendAttributeSignature(parts, 'foldable', attributes.foldable);
    HarmonySensorService.appendAttributeSignature(parts, 'free_size', attributes.free_size);
    HarmonySensorService.appendAttributeSignature(parts, 'frequency', attributes.frequency);
    HarmonySensorService.appendAttributeSignature(parts, 'geocoder_available', attributes.geocoder_available);
    HarmonySensorService.appendAttributeSignature(parts, 'gps_accuracy', attributes.gps_accuracy);
    HarmonySensorService.appendAttributeSignature(parts, 'hd_haptic_supported', attributes.hd_haptic_supported);
    HarmonySensorService.appendAttributeSignature(parts, 'hdr_formats', attributes.hdr_formats);
    HarmonySensorService.appendAttributeSignature(parts, 'hidden', attributes.hidden);
    HarmonySensorService.appendAttributeSignature(parts, 'infrared_luminance', attributes.infrared_luminance);
    HarmonySensorService.appendAttributeSignature(parts, 'ip_address', attributes.ip_address);
    HarmonySensorService.appendAttributeSignature(parts, 'last_update_trigger', attributes.last_update_trigger);
    HarmonySensorService.appendAttributeSignature(parts, 'latitude', attributes.latitude);
    HarmonySensorService.appendAttributeSignature(parts, 'link_speed', attributes.link_speed);
    HarmonySensorService.appendAttributeSignature(parts, 'local_vibrator_count', attributes.local_vibrator_count);
    HarmonySensorService.appendAttributeSignature(parts, 'locality', attributes.locality);
    HarmonySensorService.appendAttributeSignature(parts, 'location_sent', attributes.location_sent);
    HarmonySensorService.appendAttributeSignature(parts, 'longitude', attributes.longitude);
    HarmonySensorService.appendAttributeSignature(parts, 'manufacturer', attributes.manufacturer);
    HarmonySensorService.appendAttributeSignature(parts, 'market_name', attributes.market_name);
    HarmonySensorService.appendAttributeSignature(parts, 'max_headroom', attributes.max_headroom);
    HarmonySensorService.appendAttributeSignature(parts, 'max_volume', attributes.max_volume);
    HarmonySensorService.appendAttributeSignature(parts, 'metered', attributes.metered);
    HarmonySensorService.appendAttributeSignature(parts, 'min_volume', attributes.min_volume);
    HarmonySensorService.appendAttributeSignature(parts, 'nfc_state', attributes.nfc_state);
    HarmonySensorService.appendAttributeSignature(parts, 'options', attributes.options);
    HarmonySensorService.appendAttributeSignature(parts, 'os_full_name', attributes.os_full_name);
    HarmonySensorService.appendAttributeSignature(parts, 'output_device_count', attributes.output_device_count);
    HarmonySensorService.appendAttributeSignature(parts, 'output_device_types', attributes.output_device_types);
    HarmonySensorService.appendAttributeSignature(parts, 'place_name', attributes.place_name);
    HarmonySensorService.appendAttributeSignature(parts, 'postal_code', attributes.postal_code);
    HarmonySensorService.appendAttributeSignature(parts, 'power_mode', attributes.power_mode);
    HarmonySensorService.appendAttributeSignature(parts, 'precise_location', attributes.precise_location);
    HarmonySensorService.appendAttributeSignature(parts, 'premises', attributes.premises);
    HarmonySensorService.appendAttributeSignature(parts, 'product_model', attributes.product_model);
    HarmonySensorService.appendAttributeSignature(parts, 'road_name', attributes.road_name);
    HarmonySensorService.appendAttributeSignature(parts, 'sdk_api_version', attributes.sdk_api_version);
    HarmonySensorService.appendAttributeSignature(parts, 'sdr_nits', attributes.sdr_nits);
    HarmonySensorService.appendAttributeSignature(parts, 'security_patch', attributes.security_patch);
    HarmonySensorService.appendAttributeSignature(parts, 'sensor_updated_at', attributes.sensor_updated_at);
    HarmonySensorService.appendAttributeSignature(parts, 'signal_level', attributes.signal_level);
    HarmonySensorService.appendAttributeSignature(parts, 'source_mode', attributes.source_mode);
    HarmonySensorService.appendAttributeSignature(parts, 'step_detected', attributes.step_detected);
    HarmonySensorService.appendAttributeSignature(parts, 'sub_administrative_area', attributes.sub_administrative_area);
    HarmonySensorService.appendAttributeSignature(parts, 'sub_locality', attributes.sub_locality);
    HarmonySensorService.appendAttributeSignature(parts, 'sub_road_name', attributes.sub_road_name);
    HarmonySensorService.appendAttributeSignature(parts, 'supported_effects', attributes.supported_effects);
    HarmonySensorService.appendAttributeSignature(parts, 'timeStamp', attributes.timeStamp);
    HarmonySensorService.appendAttributeSignature(parts, 'total_size', attributes.total_size);
    HarmonySensorService.appendAttributeSignature(parts, 'used_percent', attributes.used_percent);
    HarmonySensorService.appendAttributeSignature(parts, 'used_size', attributes.used_size);
    HarmonySensorService.appendAttributeSignature(parts, 'version_code', attributes.version_code);
    HarmonySensorService.appendAttributeSignature(parts, 'vibrator_count', attributes.vibrator_count);
    HarmonySensorService.appendAttributeSignature(parts, 'volume_percent', attributes.volume_percent);
    return parts.join(',');
  }

  private static appendAttributeSignature(
    parts: string[],
    key: string,
    value: string | number | boolean | null | string[] | undefined
  ): void {
    if (value !== undefined) {
      parts.push(`${key}:${JSON.stringify(value)}`);
    }
  }

  private static webhookUrls(baseUrl: string, webhookId: string, cloudhookUrl: string): string[] {
    const urls: string[] = [];
    const trimmedCloudhook = cloudhookUrl.trim();
    if (trimmedCloudhook.length > 0) {
      urls.push(trimmedCloudhook);
    }
    urls.push(`${baseUrl}/api/webhook/${webhookId}`);
    return urls;
  }

  private static async postWebhookWithFallback(
    urls: string[],
    body: RegisterSensorWebhookBody | UpdateSensorStatesWebhookBody | UpdateLocationWebhookBody,
    allowConflict: boolean
  ): Promise<WebhookResult> {
    let lastError = 'sensor sync failed';
    let lastResult: WebhookResult = {
      responseCode: 0,
      body: '',
      failureSummary: lastError
    };
    for (let i = 0; i < urls.length; i++) {
      const result = await HarmonySensorService.postWebhook(urls[i], body);
      lastResult = result;
      if (HarmonySensorService.isWebhookWriteAccepted(result, allowConflict)) {
        return result;
      }
      lastError = result.failureSummary;
    }
    throw new Error(`${lastError}: ${NetworkService.shortText(lastResult.body)}`);
  }

  private static async postWebhook(
    url: string,
    body: RegisterSensorWebhookBody | UpdateSensorStatesWebhookBody | UpdateLocationWebhookBody | GetZonesWebhookBody
  ): Promise<WebhookResult> {
    try {
      const resp = await NetworkService.requestText(url, {
        method: NetworkHttpMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 15000,
        readTimeout: 15000
      });
      return {
        responseCode: resp.responseCode,
        body: resp.body,
        failureSummary: `sensor sync failed: HTTP ${resp.responseCode}`
      };
    } catch (err) {
      return {
        responseCode: 0,
        body: '',
        failureSummary: `sensor sync failed: ${NetworkService.errorText(err)}`
      };
    }  }

  private static async postWebhookForText(
    url: string,
    body: GetZonesWebhookBody
  ): Promise<HttpTextResult> {
    try {
      const resp = await NetworkService.requestText(url, {
        method: NetworkHttpMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 15000,
        readTimeout: 15000
      });
      return {
        responseCode: resp.responseCode,
        body: resp.body,
        failureSummary: `get_zones failed: HTTP ${resp.responseCode}`
      };
    } catch (err) {
      return {
        responseCode: 0,
        body: '',
        failureSummary: `get_zones failed: ${NetworkService.errorText(err)}`
      };
    }  }

  private static parseZones(body: string): HarmonyLocationZone[] {
    const parsed = JSON.parse(body) as Object[];
    const zones: HarmonyLocationZone[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const raw = parsed[i] as Record<string, Object | string | number | boolean | null>;
      const rawEntityId = raw['entity_id'] !== undefined ? raw['entity_id'] : raw['entityId'];
      const rawAttributes = raw['attributes'];
      if (typeof rawEntityId !== 'string' || !rawAttributes || typeof rawAttributes !== 'object') {
        continue;
      }
      const attributes = rawAttributes as Record<string, Object | string | number | boolean | null>;
      const rawLatitude = attributes['latitude'];
      const rawLongitude = attributes['longitude'];
      const rawRadius = attributes['radius'];
      if (typeof rawLatitude !== 'number' || typeof rawLongitude !== 'number' || typeof rawRadius !== 'number') {
        continue;
      }
      const friendlyName = attributes['friendly_name'];
      const entityZoneName = HarmonySensorService.zoneNameFromEntityId(rawEntityId);
      const zone: HarmonyLocationZone = {
        entityId: rawEntityId,
        name: entityZoneName.length > 0
          ? entityZoneName
          : (typeof friendlyName === 'string' && friendlyName.length > 0 ? friendlyName : rawEntityId),
        latitude: rawLatitude,
        longitude: rawLongitude,
        radius: rawRadius
      };
      zones.push(zone);
    }
    return zones;
  }

  private static zoneNameFromEntityId(entityId: string): string {
    const zonePrefix = 'zone.';
    if (entityId.startsWith(zonePrefix) && entityId.length > zonePrefix.length) {
      return entityId.slice(zonePrefix.length);
    }
    return '';
  }

  private static getNetworkSnapshot(): NetSnapshot {
    try {
      const capabilities = NetworkService.defaultNetCapabilities();
      const bearerTypes = capabilities && capabilities.bearerTypes ? capabilities.bearerTypes : [];
      return {
        networkType: HarmonySensorService.networkTypeValue(bearerTypes),
        metered: HarmonySensorService.networkIsMetered(capabilities.networkCap)
      };
    } catch (_) {
      return {
        networkType: SENSOR_TEXT_UNAVAILABLE,
        metered: false
      };
    }
  }

  private static getWifiSnapshot(): HarmonyWifiSnapshot {
    const empty: HarmonyWifiSnapshot = {
      active: false,
      connected: false,
      hotspotActive: false,
      ssid: '',
      bssid: '',
      hidden: false,
      ipAddress: ''
    };
    try {
      empty.active = wifiManager.isWifiActive();
      empty.connected = wifiManager.isConnected();
      empty.hotspotActive = wifiManager.isHotspotActive();
      if (!empty.connected) {
        return empty;
      }
      const info = wifiManager.getLinkedInfoSync();
      empty.ssid = info.ssid ?? '';
      empty.bssid = info.bssid ?? '';
      empty.hidden = info.isHidden ?? false;
      empty.rssi = typeof info.rssi === 'number' ? info.rssi : undefined;
      empty.frequency = typeof info.frequency === 'number' ? info.frequency : undefined;
      empty.linkSpeed = typeof info.linkSpeed === 'number' ? info.linkSpeed : undefined;
      empty.signalLevel = HarmonySensorService.wifiSignalLevel(empty.rssi, info.band);
      empty.ipAddress = HarmonySensorService.wifiIpAddressValue();
      return empty;
    } catch (_) {
      return empty;
    }
  }

  private static wifiSignalLevel(rssi: number | undefined, band: number | undefined): number | undefined {
    if (typeof rssi !== 'number' || typeof band !== 'number') {
      return undefined;
    }
    try {
      return wifiManager.getSignalLevel(rssi, band);
    } catch (_) {
      return undefined;
    }
  }

  private static wifiIpAddressValue(): string {
    try {
      return HarmonySensorService.ipAddressText(wifiManager.getIpInfo().ipAddress);
    } catch (_) {
      return '';
    }
  }

  private static ipAddressText(value: number): string {
    if (value <= 0) {
      return '';
    }
    const a = value & 0xff;
    const b = (value >> 8) & 0xff;
    const c = (value >> 16) & 0xff;
    const d = (value >> 24) & 0xff;
    return `${a}.${b}.${c}.${d}`;
  }

  private static getStorageSnapshot(): HarmonyStorageSnapshot {
    try {
      const totalSize = Math.max(storageStatistics.getTotalSizeSync(), 0);
      const freeSize = Math.max(storageStatistics.getFreeSizeSync(), 0);
      const usedSize = Math.max(totalSize - freeSize, 0);
      const usedPercent = totalSize > 0 ? Math.round((usedSize / totalSize) * 1000) / 10 : 0;
      return {
        totalSize,
        freeSize,
        usedSize,
        usedPercent
      };
    } catch (_) {
      return {};
    }
  }

  private static getDisplaySnapshot(): HarmonyDisplaySnapshot {
    const empty: HarmonyDisplaySnapshot = {
      available: false,
      state: SENSOR_TEXT_UNAVAILABLE,
      width: 0,
      height: 0,
      availableWidth: 0,
      availableHeight: 0,
      orientation: SENSOR_TEXT_UNAVAILABLE,
      screenShape: SENSOR_TEXT_UNAVAILABLE,
      hdrFormats: [],
      sourceMode: SENSOR_TEXT_UNAVAILABLE,
      foldable: false,
      foldStatus: SENSOR_TEXT_UNAVAILABLE,
      foldDisplayMode: SENSOR_TEXT_UNAVAILABLE,
    };
    try {
      const current = display.getDefaultDisplaySync();
      const snapshot: HarmonyDisplaySnapshot = {
        available: true,
        state: HarmonySensorService.displayStateValue(current.state),
        width: current.width ?? 0,
        height: current.height ?? 0,
        availableWidth: current.availableWidth ?? 0,
        availableHeight: current.availableHeight ?? 0,
        refreshRate: HarmonySensorService.roundOptional(current.refreshRate, 10),
        rotation: HarmonySensorService.displayRotationDegrees(current.rotation),
        orientation: HarmonySensorService.displayOrientationValue(current.orientation),
        densityDPI: HarmonySensorService.roundOptional(current.densityDPI, 1),
        densityPixels: HarmonySensorService.roundOptional(current.densityPixels, 100),
        scaledDensity: HarmonySensorService.roundOptional(current.scaledDensity, 100),
        xDPI: HarmonySensorService.roundOptional(current.xDPI, 10),
        yDPI: HarmonySensorService.roundOptional(current.yDPI, 10),
        screenShape: HarmonySensorService.screenShapeValue(current.screenShape),
        hdrFormats: HarmonySensorService.displayHdrFormats(current.hdrFormats),
        sourceMode: HarmonySensorService.displaySourceModeValue(current.sourceMode),
        foldable: HarmonySensorService.displayFoldable(),
        foldStatus: HarmonySensorService.displayFoldStatusValue(),
        foldDisplayMode: HarmonySensorService.displayFoldDisplayModeValue()
      };
      try {
        const brightness = display.getBrightnessInfo(current.id);
        snapshot.brightnessSdrNits = HarmonySensorService.roundOptional(brightness.sdrNits, 10);
        snapshot.brightnessCurrentHeadroom = HarmonySensorService.roundOptional(brightness.currentHeadroom, 100);
        snapshot.brightnessMaxHeadroom = HarmonySensorService.roundOptional(brightness.maxHeadroom, 100);
      } catch (_) {
      }
      return snapshot;
    } catch (_) {
      return empty;
    }
  }

  private static volumeDescriptor(
    id: string,
    name: string,
    streamUsage: audio.StreamUsage,
    prefs: SensorPreferenceSnapshot
  ): SensorDescriptor {
    const volume = HarmonySensorService.audioVolumeValue(streamUsage);
    return {
      id,
      name,
      type: 'sensor',
      icon: SENSOR_ICON_GENERIC,
      state: HarmonySensorService.numberOrUnavailable(volume.volumePercent),
      attributes: {
        min_volume: volume.minVolume,
        max_volume: volume.maxVolume,
        volume_percent: volume.volumePercent
      },
      enabled: HarmonySensorService.isSensorEnabled(id, prefs),
      unitOfMeasurement: '%',
      stateClass: 'measurement',
    };
  }

  private static appMemoryPss(): number | undefined {
    return HarmonySensorService.bigIntToNumber((): bigint => hidebug.getPss());
  }

  private static appMemoryAttributes(): SensorAttributes {
    return {
      app_memory_vss: HarmonySensorService.bigIntToNumber((): bigint => hidebug.getVss()),
      app_memory_native_heap_size: HarmonySensorService.bigIntToNumber((): bigint => hidebug.getNativeHeapSize()),
      app_memory_native_heap_allocated_size: HarmonySensorService.bigIntToNumber((): bigint => hidebug.getNativeHeapAllocatedSize()),
      app_memory_native_heap_free_size: HarmonySensorService.bigIntToNumber((): bigint => hidebug.getNativeHeapFreeSize()),
      app_memory_shared_dirty: HarmonySensorService.bigIntToNumber((): bigint => hidebug.getSharedDirty()),
      app_memory_private_dirty: HarmonySensorService.bigIntToNumber((): bigint => hidebug.getPrivateDirty())
    };
  }

  private static bigIntToNumber(read: () => bigint): number | undefined {
    try {
      return Number(read());
    } catch (_) {
      return undefined;
    }
  }

  private static audioVolumeValue(streamUsage: audio.StreamUsage): HarmonyAudioVolumeSnapshot {
    try {
      const manager = audio.getAudioManager().getVolumeManager();
      const current = manager.getVolumeByStream(streamUsage);
      const minVolume = manager.getMinVolumeByStream(streamUsage);
      const maxVolume = manager.getMaxVolumeByStream(streamUsage);
      const range = maxVolume - minVolume;
      const volumePercent = range > 0 ? Math.round(((current - minVolume) / range) * 100) : 0;
      const snapshot: HarmonyAudioVolumeSnapshot = {
        minVolume,
        maxVolume,
        volumePercent: Math.max(0, Math.min(volumePercent, 100))
      };
      return snapshot;
    } catch (_) {
      return {};
    }
  }

  private static hasNotMeteredCap(networkCap: NetworkNetCap[] | undefined): boolean {
    if (!networkCap) {
      return false;
    }
    for (let i = 0; i < networkCap.length; i++) {
      if (NetworkService.isNotMeteredCap(networkCap[i])) {
        return true;
      }
    }
    return false;
  }

  private static networkIsMetered(networkCap: NetworkNetCap[] | undefined): boolean {
    return !HarmonySensorService.hasNotMeteredCap(networkCap);
  }

  private static hasCellularBearer(bearerTypes: NetworkNetBearType[]): boolean {
    for (let i = 0; i < bearerTypes.length; i++) {
      if (NetworkService.isCellularBearer(bearerTypes[i])) {
        return true;
      }
    }
    return false;
  }

  private static hasEthernetBearer(bearerTypes: NetworkNetBearType[]): boolean {
    for (let i = 0; i < bearerTypes.length; i++) {
      if (NetworkService.isEthernetBearer(bearerTypes[i])) {
        return true;
      }
    }
    return false;
  }

  private static hasVpnBearer(bearerTypes: NetworkNetBearType[]): boolean {
    for (let i = 0; i < bearerTypes.length; i++) {
      if (NetworkService.isVpnBearer(bearerTypes[i])) {
        return true;
      }
    }
    return false;
  }

  private static hasWifiBearer(bearerTypes: NetworkNetBearType[]): boolean {
    for (let i = 0; i < bearerTypes.length; i++) {
      if (NetworkService.isWifiBearer(bearerTypes[i])) {
        return true;
      }
    }
    return false;
  }

  private static networkTypeValue(bearerTypes: NetworkNetBearType[]): string {
    if (HarmonySensorService.hasCellularBearer(bearerTypes)) {
      return 'cellular';
    }
    if (HarmonySensorService.hasEthernetBearer(bearerTypes)) {
      return 'ethernet';
    }
    if (HarmonySensorService.hasVpnBearer(bearerTypes)) {
      return 'vpn';
    }
    if (HarmonySensorService.hasWifiBearer(bearerTypes)) {
      return 'wifi';
    }
    return SENSOR_TEXT_UNKNOWN;
  }

  private static networkTypeAttributes(metered: boolean): SensorAttributes {
    return {
      metered,
      options: ['bluetooth', 'cellular', 'ethernet', 'lowpan', 'usb', 'vpn', 'wifi', 'wifi_aware']
    };
  }

  private static networkTypeIcon(networkType: string): string {
    switch (networkType) {
      case 'cellular':
        return 'mdi:signal-cellular-3';
      case 'ethernet':
        return 'mdi:ethernet';
      case 'usb':
        return 'mdi:usb';
      case 'wifi':
      case 'wifi_aware':
        return 'mdi:wifi';
      default:
        return 'mdi:network';
    }
  }

  private static batteryLevelValue(): number {
    const value = typeof batteryInfo.batterySOC === 'number' ? batteryInfo.batterySOC : 0;
    if (value < 0) {
      return 0;
    }
    if (value > 100) {
      return 100;
    }
    return Math.round(value);
  }

  private static batteryStateValue(): string {
    switch (batteryInfo.chargingStatus) {
      case batteryInfo.BatteryChargeState.ENABLE:
        return 'charging';
      case batteryInfo.BatteryChargeState.DISABLE:
        return 'not_charging';
      case batteryInfo.BatteryChargeState.FULL:
        return 'full';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static batteryStateAttributes(): SensorAttributes {
    return {
      options: ['charging', 'discharging', 'full', 'not_charging']
    };
  }

  private static batteryHealthValue(): string {
    switch (batteryInfo.healthStatus) {
      case batteryInfo.BatteryHealthState.GOOD:
        return 'good';
      case batteryInfo.BatteryHealthState.OVERHEAT:
        return 'overheated';
      case batteryInfo.BatteryHealthState.OVERVOLTAGE:
        return 'over_voltage';
      case batteryInfo.BatteryHealthState.COLD:
        return 'cold';
      case batteryInfo.BatteryHealthState.DEAD:
        return 'dead';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static batteryHealthAttributes(): SensorAttributes {
    return {
      options: ['cold', 'dead', 'good', 'overheated', 'over_voltage', 'failed']
    };
  }

  private static batteryTemperatureValue(): number | undefined {
    if (typeof batteryInfo.batteryTemperature !== 'number') {
      return undefined;
    }
    const value = batteryInfo.batteryTemperature;
    return Math.round(value) / 10;
  }

  private static batteryVoltageValue(): number | undefined {
    if (typeof batteryInfo.voltage !== 'number') {
      return undefined;
    }
    const value = batteryInfo.voltage;
    return Math.round(value / 1000) / 1000;
  }

  private static batteryCurrentValue(): number | undefined {
    if (typeof batteryInfo.nowCurrent !== 'number') {
      return undefined;
    }
    const value = batteryInfo.nowCurrent;
    return Math.round(value);
  }

  private static batteryPowerValue(voltage: number | undefined, current: number | undefined): number | undefined {
    if (typeof voltage !== 'number' || typeof current !== 'number') {
      return undefined;
    }
    return Math.round((voltage * current / 1000) * 1000) / 1000;
  }

  private static batteryCapacityLevelValue(): string {
    switch (batteryInfo.batteryCapacityLevel) {
      case batteryInfo.BatteryCapacityLevel.LEVEL_FULL:
        return 'full';
      case batteryInfo.BatteryCapacityLevel.LEVEL_HIGH:
        return 'high';
      case batteryInfo.BatteryCapacityLevel.LEVEL_NORMAL:
        return 'normal';
      case batteryInfo.BatteryCapacityLevel.LEVEL_LOW:
        return 'low';
      case batteryInfo.BatteryCapacityLevel.LEVEL_CRITICAL:
        return 'critical';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static batteryCapacityLevelAttributes(): SensorAttributes {
    return {
      options: ['full', 'high', 'normal', 'low', 'critical']
    };
  }

  private static bluetoothEnabled(): boolean {
    return HarmonySensorService.bluetoothStateValue() === 'on';
  }

  private static bluetoothStateValue(): string {
    try {
      switch (bluetoothAccess.getState()) {
        case bluetoothAccess.BluetoothState.STATE_ON:
          return 'on';
        case bluetoothAccess.BluetoothState.STATE_TURNING_ON:
          return 'turning_on';
        case bluetoothAccess.BluetoothState.STATE_TURNING_OFF:
          return 'turning_off';
        case bluetoothAccess.BluetoothState.STATE_BLE_ON:
          return 'ble_on';
        case bluetoothAccess.BluetoothState.STATE_BLE_TURNING_ON:
          return 'ble_turning_on';
        case bluetoothAccess.BluetoothState.STATE_BLE_TURNING_OFF:
          return 'ble_turning_off';
        default:
          return 'off';
      }
    } catch (_) {
      return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static ringerModeValue(): string {
    try {
      const manager = audio.getAudioManager().getVolumeManager().getVolumeGroupManagerSync(audio.DEFAULT_VOLUME_GROUP_ID);
      switch (manager.getRingerModeSync()) {
        case audio.AudioRingMode.RINGER_MODE_SILENT:
          return 'silent';
        case audio.AudioRingMode.RINGER_MODE_VIBRATE:
          return 'vibrate';
        case audio.AudioRingMode.RINGER_MODE_NORMAL:
          return 'normal';
        default:
          return SENSOR_TEXT_UNKNOWN;
      }
    } catch (_) {
      return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static ringerModeAttributes(): SensorAttributes {
    return {
      options: ['silent', 'vibrate', 'normal']
    };
  }

  private static audioRouteSnapshot(): HarmonyAudioRouteSnapshot {
    let outputDeviceTypes: string[] = [];
    try {
      const devices = audio.getAudioManager().getRoutingManager().getDevicesSync(audio.DeviceFlag.OUTPUT_DEVICES_FLAG);
      for (let i = 0; i < devices.length; i++) {
        outputDeviceTypes.push(HarmonySensorService.audioDeviceTypeValue(devices[i].deviceType));
      }
    } catch (_) {
      outputDeviceTypes = [];
    }
    const snapshot: HarmonyAudioRouteSnapshot = {
      outputDeviceTypes,
      headphoneConnected: HarmonySensorService.hasHeadphoneOutput(outputDeviceTypes),
      speakerActive: HarmonySensorService.containsText(outputDeviceTypes, 'speaker'),
      audioScene: HarmonySensorService.audioSceneValue()
    };
    return snapshot;
  }

  private static audioRouteAttributes(snapshot: HarmonyAudioRouteSnapshot): SensorAttributes {
    return {
      audio_scene: snapshot.audioScene,
      output_device_types: snapshot.outputDeviceTypes,
      output_device_count: snapshot.outputDeviceTypes.length
    };
  }

  private static hasHeadphoneOutput(values: string[]): boolean {
    for (let i = 0; i < values.length; i++) {
      const value = values[i];
      if (value === 'wired_headset' ||
        value === 'wired_headphones' ||
        value === 'usb_headset' ||
        value === 'bluetooth_sco' ||
        value === 'bluetooth_a2dp' ||
        value === 'hearing_aid' ||
        value === 'nearlink') {
        return true;
      }
    }
    return false;
  }

  private static audioDeviceTypeValue(value: audio.DeviceType): string {
    switch (value) {
      case audio.DeviceType.EARPIECE:
        return 'earpiece';
      case audio.DeviceType.SPEAKER:
        return 'speaker';
      case audio.DeviceType.WIRED_HEADSET:
        return 'wired_headset';
      case audio.DeviceType.WIRED_HEADPHONES:
        return 'wired_headphones';
      case audio.DeviceType.BLUETOOTH_SCO:
        return 'bluetooth_sco';
      case audio.DeviceType.BLUETOOTH_A2DP:
        return 'bluetooth_a2dp';
      case audio.DeviceType.MIC:
        return 'mic';
      case audio.DeviceType.USB_HEADSET:
        return 'usb_headset';
      case audio.DeviceType.DISPLAY_PORT:
        return 'display_port';
      case audio.DeviceType.REMOTE_CAST:
        return 'remote_cast';
      case audio.DeviceType.USB_DEVICE:
        return 'usb_device';
      case audio.DeviceType.HDMI:
        return 'hdmi';
      case audio.DeviceType.LINE_DIGITAL:
        return 'line_digital';
      case audio.DeviceType.REMOTE_DAUDIO:
        return 'remote_daudio';
      case audio.DeviceType.HEARING_AID:
        return 'hearing_aid';
      case audio.DeviceType.NEARLINK:
        return 'nearlink';
      default:
        return 'unknown';
    }
  }

  private static audioSceneValue(): string {
    try {
      switch (audio.getAudioManager().getAudioSceneSync()) {
        case audio.AudioScene.AUDIO_SCENE_DEFAULT:
          return 'default';
        case audio.AudioScene.AUDIO_SCENE_RINGING:
          return 'ringing';
        case audio.AudioScene.AUDIO_SCENE_PHONE_CALL:
          return 'phone_call';
        case audio.AudioScene.AUDIO_SCENE_VOICE_CHAT:
          return 'voice_chat';
        default:
          return SENSOR_TEXT_UNKNOWN;
      }
    } catch (_) {
      return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static thermalLevelValue(): string {
    try {
      switch (thermal.getLevel()) {
        case thermal.ThermalLevel.COOL:
          return 'cool';
        case thermal.ThermalLevel.NORMAL:
          return 'normal';
        case thermal.ThermalLevel.WARM:
          return 'warm';
        case thermal.ThermalLevel.HOT:
          return 'hot';
        case thermal.ThermalLevel.OVERHEATED:
          return 'overheated';
        case thermal.ThermalLevel.WARNING:
          return 'warning';
        case thermal.ThermalLevel.EMERGENCY:
          return 'emergency';
        case thermal.ThermalLevel.ESCAPE:
          return 'escape';
        default:
          return SENSOR_TEXT_UNKNOWN;
      }
    } catch (_) {
      return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static thermalLevelAttributes(): SensorAttributes {
    return {
      options: ['cool', 'normal', 'warm', 'hot', 'overheated', 'warning', 'emergency', 'escape']
    };
  }

  private static vibratorEffectSupported(): boolean {
    return HarmonySensorService.supportedVibratorEffects().length > 0;
  }

  private static vibratorEffectAttributes(): SensorAttributes {
    const info = HarmonySensorService.vibratorInfo();
    let localCount = 0;
    let hdHapticSupported = false;
    for (let i = 0; i < info.length; i++) {
      if (info[i].isLocalVibrator) {
        localCount += 1;
      }
      if (info[i].isHdHapticSupported) {
        hdHapticSupported = true;
      }
    }
    return {
      vibrator_count: info.length,
      local_vibrator_count: localCount,
      hd_haptic_supported: hdHapticSupported,
      supported_effects: HarmonySensorService.supportedVibratorEffects()
    };
  }

  private static vibratorInfo(): vibrator.VibratorInfo[] {
    try {
      return vibrator.getVibratorInfoSync();
    } catch (_) {
      return [];
    }
  }

  private static supportedVibratorEffects(): string[] {
    const candidates: string[] = [
      vibrator.EffectId.EFFECT_CLOCK_TIMER,
      vibrator.HapticFeedback.EFFECT_SOFT,
      vibrator.HapticFeedback.EFFECT_HARD,
      vibrator.HapticFeedback.EFFECT_SHARP,
      vibrator.HapticFeedback.EFFECT_NOTICE_SUCCESS,
      vibrator.HapticFeedback.EFFECT_NOTICE_FAILURE,
      vibrator.HapticFeedback.EFFECT_NOTICE_WARNING
    ];
    const supported: string[] = [];
    for (let i = 0; i < candidates.length; i++) {
      try {
        if (vibrator.isSupportEffectSync(candidates[i])) {
          supported.push(candidates[i]);
        }
      } catch (_) {
      }
    }
    return supported;
  }

  private static async refreshGeocodedLocationIfNeeded(
    prefs: SensorPreferenceSnapshot,
    lastLocation: HarmonyLocationSnapshot | undefined
  ): Promise<void> {
    if (!HarmonySensorService.isSensorEnabled('geocoded_location', prefs) || !lastLocation) {
      return;
    }
    const current = HarmonySensorService.geocodedLocationValue();
    if (current.sourceTimeStamp === lastLocation.timeStamp) {
      return;
    }
    let available = false;
    try {
      available = geoLocationManager.isGeocoderAvailable();
    } catch (_) {
      HarmonySensorService.saveGeocodedLocation({
        geocoderAvailable: false,
        latitude: lastLocation.latitude,
        longitude: lastLocation.longitude,
        sourceTimeStamp: lastLocation.timeStamp
      });
      return;
    }
    if (!available) {
      HarmonySensorService.saveGeocodedLocation({
        geocoderAvailable: false,
        latitude: lastLocation.latitude,
        longitude: lastLocation.longitude,
        sourceTimeStamp: lastLocation.timeStamp
      });
      return;
    }
    try {
      const addresses = await geoLocationManager.getAddressesFromLocation({
        latitude: lastLocation.latitude,
        longitude: lastLocation.longitude,
        maxItems: 1
      });
      const address = addresses.length > 0 ? addresses[0] : undefined;
      HarmonySensorService.saveGeocodedLocation({
        geocoderAvailable: true,
        latitude: lastLocation.latitude,
        longitude: lastLocation.longitude,
        sourceTimeStamp: lastLocation.timeStamp,
        placeName: address?.placeName ?? '',
        countryCode: address?.countryCode ?? '',
        countryName: address?.countryName ?? '',
        administrativeArea: address?.administrativeArea ?? '',
        subAdministrativeArea: address?.subAdministrativeArea ?? '',
        locality: address?.locality ?? '',
        subLocality: address?.subLocality ?? '',
        roadName: address?.roadName ?? '',
        subRoadName: address?.subRoadName ?? '',
        premises: address?.premises ?? '',
        postalCode: address?.postalCode ?? ''
      });
    } catch (_) {
      HarmonySensorService.saveGeocodedLocation({
        geocoderAvailable: false,
        latitude: lastLocation.latitude,
        longitude: lastLocation.longitude,
        sourceTimeStamp: lastLocation.timeStamp
      });
    }
  }

  private static geocodedLocationState(value: GeocodedLocationValue): string {
    const parts: string[] = [
      value.placeName ?? '',
      value.roadName ?? '',
      value.locality ?? '',
      value.administrativeArea ?? '',
      value.countryName ?? ''
    ];
    for (let i = 0; i < parts.length; i++) {
      const candidate = parts[i].trim();
      if (candidate.length > 0) {
        return candidate;
      }
    }
    return SENSOR_TEXT_UNAVAILABLE;
  }

  private static geocodedLocationAttributes(value: GeocodedLocationValue): SensorAttributes {
    return {
      geocoder_available: value.geocoderAvailable ?? false,
      latitude: value.latitude ?? null,
      longitude: value.longitude ?? null,
      timeStamp: value.sourceTimeStamp ?? null,
      place_name: value.placeName ?? '',
      country_code: value.countryCode ?? '',
      country_name: value.countryName ?? '',
      administrative_area: value.administrativeArea ?? '',
      sub_administrative_area: value.subAdministrativeArea ?? '',
      locality: value.locality ?? '',
      sub_locality: value.subLocality ?? '',
      road_name: value.roadName ?? '',
      sub_road_name: value.subRoadName ?? '',
      premises: value.premises ?? '',
      postal_code: value.postalCode ?? ''
    };
  }

  private static saveGeocodedLocation(value: GeocodedLocationValue): void {
    const json = JSON.stringify(value);
    if (!AppStorage.set<string>('sensorGeocodedLocationJson', json)) {
      AppStorage.setOrCreate<string>('sensorGeocodedLocationJson', json);
    }
  }

  private static geocodedLocationValue(): GeocodedLocationValue {
    try {
      const parsed = JSON.parse(AppStorage.get<string>('sensorGeocodedLocationJson') ?? '{}') as GeocodedLocationValue;
      if (!parsed || typeof parsed !== 'object') {
        return {};
      }
      return parsed;
    } catch (_) {
      return {};
    }
  }

  private static hardwareSensorValues(): HardwareSensorValues {
    try {
      const parsed = JSON.parse(AppStorage.get<string>('sensorHardwareValuesJson') ?? '{}') as HardwareSensorValues;
      if (!parsed || typeof parsed !== 'object') {
        return {};
      }
      return parsed;
    } catch (_) {
      return {};
    }
  }

  private static multimodalSensorValues(): MultimodalSensorValues {
    try {
      const parsed = JSON.parse(AppStorage.get<string>('sensorMultimodalValuesJson') ?? '{}') as MultimodalSensorValues;
      if (!parsed || typeof parsed !== 'object') {
        return {};
      }
      return parsed;
    } catch (_) {
      return {};
    }
  }

  private static operatingHandState(value: number | undefined): string {
    switch (value) {
      case motion.OperatingHandStatus.LEFT_HAND_OPERATED:
        return 'left_hand';
      case motion.OperatingHandStatus.RIGHT_HAND_OPERATED:
        return 'right_hand';
      default:
        return 'unknown';
    }
  }

  private static holdingHandState(value: number | undefined): string {
    switch (value) {
      case motion.HoldingHandStatus.NOT_HELD:
        return 'not_held';
      case motion.HoldingHandStatus.LEFT_HAND_HELD:
        return 'left_hand';
      case motion.HoldingHandStatus.RIGHT_HAND_HELD:
        return 'right_hand';
      case motion.HoldingHandStatus.BOTH_HANDS_HELD:
        return 'both_hands';
      default:
        return 'unknown';
    }
  }

  private static numberOrUnavailable(value: number | undefined): number | null {
    return typeof value === 'number' ? value : null;
  }

  private static roundOptional(value: number | undefined, factor: number): number | undefined {
    if (typeof value !== 'number') {
      return undefined;
    }
    return Math.round(value * factor) / factor;
  }

  private static wifiMeasurementState(snapshot: HarmonyWifiSnapshot, value: number | undefined): number | null {
    if (!snapshot.connected || typeof value !== 'number') {
      return null;
    }
    return value;
  }

  private static locationPermissionValue(): string {
    const approximate = HarmonySensorService.hasPermission('ohos.permission.APPROXIMATELY_LOCATION');
    const precise = HarmonySensorService.hasPermission('ohos.permission.LOCATION');
    const background = HarmonySensorService.hasPermission('ohos.permission.LOCATION_IN_BACKGROUND');
    if (background && precise) {
      return 'background';
    }
    if (precise) {
      return 'precise';
    }
    if (approximate) {
      return 'approximate';
    }
    return 'denied';
  }

  private static locationPermissionAttributes(): SensorAttributes {
    return {
      approximate_location: HarmonySensorService.hasPermission('ohos.permission.APPROXIMATELY_LOCATION'),
      precise_location: HarmonySensorService.hasPermission('ohos.permission.LOCATION'),
      background_location: HarmonySensorService.hasPermission('ohos.permission.LOCATION_IN_BACKGROUND'),
      options: ['denied', 'approximate', 'precise', 'background']
    };
  }

  private static nfcEnabled(): boolean {
    try {
      return nfcController.isNfcOpen();
    } catch (_) {
      return false;
    }
  }

  private static nfcStateValue(): string {
    try {
      switch (nfcController.getNfcState()) {
        case nfcController.NfcState.STATE_OFF:
          return 'off';
        case nfcController.NfcState.STATE_TURNING_ON:
          return 'turning_on';
        case nfcController.NfcState.STATE_ON:
          return 'on';
        case nfcController.NfcState.STATE_TURNING_OFF:
          return 'turning_off';
        default:
          return SENSOR_TEXT_UNKNOWN;
      }
    } catch (_) {
      return SENSOR_TEXT_UNAVAILABLE;
    }
  }

  private static displayStateValue(value: display.DisplayState): string {
    switch (value) {
      case display.DisplayState.STATE_OFF:
        return 'off';
      case display.DisplayState.STATE_ON:
        return 'on';
      case display.DisplayState.STATE_DOZE:
        return 'doze';
      case display.DisplayState.STATE_DOZE_SUSPEND:
        return 'doze_suspend';
      case display.DisplayState.STATE_VR:
        return 'vr';
      case display.DisplayState.STATE_ON_SUSPEND:
        return 'on_suspend';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static displayStateAttributes(): SensorAttributes {
    return {
      options: ['unknown', 'off', 'on', 'doze', 'doze_suspend', 'vr', 'on_suspend']
    };
  }

  private static displayOrientationValue(value: display.Orientation): string {
    switch (value) {
      case display.Orientation.PORTRAIT:
        return 'portrait';
      case display.Orientation.LANDSCAPE:
        return 'landscape';
      case display.Orientation.PORTRAIT_INVERTED:
        return 'portrait_inverted';
      case display.Orientation.LANDSCAPE_INVERTED:
        return 'landscape_inverted';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static displayRotationDegrees(value: number | undefined): number | undefined {
    switch (value) {
      case 0:
        return 0;
      case 1:
        return 90;
      case 2:
        return 180;
      case 3:
        return 270;
      default:
        return undefined;
    }
  }

  private static displayOrientationAttributes(snapshot: HarmonyDisplaySnapshot): SensorAttributes {
    return {
      display_rotation: snapshot.rotation,
      options: ['portrait', 'landscape', 'portrait_inverted', 'landscape_inverted']
    };
  }

  private static displayResolutionValue(snapshot: HarmonyDisplaySnapshot): string {
    if (!snapshot.available || snapshot.width <= 0 || snapshot.height <= 0) {
      return SENSOR_TEXT_UNAVAILABLE;
    }
    return `${snapshot.width}x${snapshot.height}`;
  }

  private static displayResolutionAttributes(snapshot: HarmonyDisplaySnapshot): SensorAttributes {
    return {
      display_width: snapshot.width,
      display_height: snapshot.height,
      display_available_width: snapshot.availableWidth,
      display_available_height: snapshot.availableHeight
    };
  }

  private static displayDensityAttributes(snapshot: HarmonyDisplaySnapshot): SensorAttributes {
    return {
      display_density_pixels: snapshot.densityPixels,
      display_scaled_density: snapshot.scaledDensity,
      display_x_dpi: snapshot.xDPI,
      display_y_dpi: snapshot.yDPI
    };
  }

  private static displayBrightnessAttributes(snapshot: HarmonyDisplaySnapshot): SensorAttributes {
    return {
      sdr_nits: snapshot.brightnessSdrNits,
      current_headroom: snapshot.brightnessCurrentHeadroom,
      max_headroom: snapshot.brightnessMaxHeadroom
    };
  }

  private static screenShapeValue(value: display.ScreenShape | undefined): string {
    switch (value) {
      case display.ScreenShape.RECTANGLE:
        return 'rectangle';
      case display.ScreenShape.ROUND:
        return 'round';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static screenShapeAttributes(): SensorAttributes {
    return {
      options: ['rectangle', 'round']
    };
  }

  private static displayHdrFormats(values: Object[] | undefined): string[] {
    if (!values) {
      return [];
    }
    const result: string[] = [];
    for (let i = 0; i < values.length; i++) {
      result.push(`${values[i]}`);
    }
    return result;
  }

  private static displayHdrFormatCount(snapshot: HarmonyDisplaySnapshot): number | undefined {
    if (!snapshot.available) {
      return undefined;
    }
    return snapshot.hdrFormats.length;
  }

  private static displaySourceModeValue(value: display.DisplaySourceMode | undefined): string {
    switch (value) {
      case display.DisplaySourceMode.NONE:
        return 'none';
      case display.DisplaySourceMode.MAIN:
        return 'main';
      case display.DisplaySourceMode.MIRROR:
        return 'mirror';
      case display.DisplaySourceMode.EXTEND:
        return 'extend';
      case display.DisplaySourceMode.ALONE:
        return 'alone';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static displayFoldable(): boolean {
    try {
      return display.isFoldable();
    } catch (_) {
      return false;
    }
  }

  private static displayFoldStatusValue(): string {
    try {
      switch (display.getFoldStatus()) {
        case display.FoldStatus.FOLD_STATUS_EXPANDED:
          return 'expanded';
        case display.FoldStatus.FOLD_STATUS_FOLDED:
          return 'folded';
        case display.FoldStatus.FOLD_STATUS_HALF_FOLDED:
          return 'half_folded';
        case display.FoldStatus.FOLD_STATUS_EXPANDED_WITH_SECOND_EXPANDED:
          return 'expanded_with_second_expanded';
        case display.FoldStatus.FOLD_STATUS_EXPANDED_WITH_SECOND_HALF_FOLDED:
          return 'expanded_with_second_half_folded';
        case display.FoldStatus.FOLD_STATUS_FOLDED_WITH_SECOND_EXPANDED:
          return 'folded_with_second_expanded';
        case display.FoldStatus.FOLD_STATUS_FOLDED_WITH_SECOND_HALF_FOLDED:
          return 'folded_with_second_half_folded';
        case display.FoldStatus.FOLD_STATUS_HALF_FOLDED_WITH_SECOND_EXPANDED:
          return 'half_folded_with_second_expanded';
        case display.FoldStatus.FOLD_STATUS_HALF_FOLDED_WITH_SECOND_HALF_FOLDED:
          return 'half_folded_with_second_half_folded';
        default:
          return SENSOR_TEXT_UNKNOWN;
      }
    } catch (_) {
      return SENSOR_TEXT_UNAVAILABLE;
    }
  }

  private static foldStatusAttributes(snapshot: HarmonyDisplaySnapshot): SensorAttributes {
    return {
      foldable: snapshot.foldable,
      fold_status: snapshot.foldStatus,
      options: [
        'expanded',
        'folded',
        'half_folded',
        'expanded_with_second_expanded',
        'expanded_with_second_half_folded',
        'folded_with_second_expanded',
        'folded_with_second_half_folded',
        'half_folded_with_second_expanded',
        'half_folded_with_second_half_folded'
      ]
    };
  }

  private static displayFoldDisplayModeValue(): string {
    try {
      switch (display.getFoldDisplayMode()) {
        case display.FoldDisplayMode.FOLD_DISPLAY_MODE_FULL:
          return 'full';
        case display.FoldDisplayMode.FOLD_DISPLAY_MODE_MAIN:
          return 'main';
        case display.FoldDisplayMode.FOLD_DISPLAY_MODE_SUB:
          return 'sub';
        case display.FoldDisplayMode.FOLD_DISPLAY_MODE_COORDINATION:
          return 'coordination';
        default:
          return SENSOR_TEXT_UNKNOWN;
      }
    } catch (_) {
      return SENSOR_TEXT_UNAVAILABLE;
    }
  }

  private static foldDisplayModeAttributes(snapshot: HarmonyDisplaySnapshot): SensorAttributes {
    return {
      foldable: snapshot.foldable,
      fold_display_mode: snapshot.foldDisplayMode,
      options: ['full', 'main', 'sub', 'coordination']
    };
  }

  private static hasPermission(permission: Permissions): boolean {
    try {
      return abilityAccessCtrl.createAtManager().getSelfPermissionStatus(permission) ===
        abilityAccessCtrl.PermissionStatus.GRANTED;
    } catch (_) {
      return false;
    }
  }

  private static batteryStateIcon(batteryState: string): string {
    switch (batteryState) {
      case 'charging':
        return 'mdi:battery-plus';
      case 'discharging':
        return 'mdi:battery-minus';
      case 'full':
        return 'mdi:battery-charging';
      case 'not_charging':
        return 'mdi:battery';
      default:
        return 'mdi:battery-unknown';
    }
  }

  private static chargerTypeValue(): string {
    switch (batteryInfo.pluggedType) {
      case batteryInfo.BatteryPluggedType.AC:
        return 'ac';
      case batteryInfo.BatteryPluggedType.USB:
        return 'usb';
      case batteryInfo.BatteryPluggedType.WIRELESS:
        return 'wireless';
      default:
        return 'none';
    }
  }

  private static chargerTypeAttributes(): SensorAttributes {
    return {
      options: ['ac', 'usb', 'wireless', 'dock', 'none']
    };
  }

  private static chargerTypeIcon(chargerType: string): string {
    switch (chargerType) {
      case 'ac':
        return 'mdi:power-plug';
      case 'usb':
        return 'mdi:usb-port';
      case 'wireless':
        return 'mdi:battery-charging-wireless';
      default:
        return 'mdi:battery';
    }
  }

  private static batteryLevelIcon(level: number, batteryState: string, chargerType: string): string {
    const baseIcon = batteryState === 'charging' || batteryState === 'full'
      ? (chargerType === 'wireless' ? 'mdi:battery-charging-wireless' : 'mdi:battery-charging')
      : 'mdi:battery';
    if (level <= 9) {
      return `${baseIcon}-outline`;
    }
    if (level >= 100) {
      return baseIcon;
    }
    const bucket = Math.floor(level / 10) * 10;
    return `${baseIcon}-${bucket}`;
  }

  private static nonEmptyText(value: string): string {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : SENSOR_TEXT_UNAVAILABLE;
  }

  private static productModelValue(): string {
    const marketName = deviceInfo.marketName ? deviceInfo.marketName.trim() : '';
    if (marketName.length > 0) {
      return marketName;
    }
    const productAlias = deviceInfo.productModelAlias ? deviceInfo.productModelAlias.trim() : '';
    if (productAlias.length > 0) {
      return productAlias;
    }
    return HarmonySensorService.nonEmptyText(deviceInfo.productModel ?? '');
  }

  private static powerIsActive(): boolean {
    try {
      return power.isActive();
    } catch (_) {
      return false;
    }
  }

  private static powerIsStandby(): boolean {
    try {
      return power.isStandby();
    } catch (_) {
      return false;
    }
  }

  private static powerSaveEnabled(): boolean {
    const mode = HarmonySensorService.powerModeValue();
    return mode === 'power_save' || mode === 'extreme_power_save' || mode === 'custom_power_save';
  }

  private static powerModeValue(): string {
    try {
      const mode = power.getPowerMode();
      switch (mode) {
        case power.DevicePowerMode.MODE_POWER_SAVE:
          return 'power_save';
        case power.DevicePowerMode.MODE_PERFORMANCE:
          return 'performance';
        case power.DevicePowerMode.MODE_EXTREME_POWER_SAVE:
          return 'extreme_power_save';
        case power.DevicePowerMode.MODE_CUSTOM_POWER_SAVE:
          return 'custom_power_save';
        default:
          return 'normal';
      }
    } catch (_) {
      return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static currentTimeZoneValue(): string {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone ?? SENSOR_TEXT_UNKNOWN;
    } catch (_) {
      return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static containsText(values: string[], target: string): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true;
      }
    }
    return false;
  }

  private static normalizeBaseUrl(input: string): string {
    const trimmed = input.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.slice(0, trimmed.length - 1);
    }
    return trimmed;
  }

  private static stringifyError(err: Object | string | number | boolean): string {
    if (err instanceof Error) {
      return err.message;
    }
    try {
      return JSON.stringify(err);
    } catch (_) {
      return String(err);
    }
  }

  private static shortText(input: string, maxLen: number = 120): string {
    const normalized = input.replace(/\s+/g, ' ').trim();
    if (normalized.length <= maxLen) {
      return normalized;
    }
    return `${normalized.slice(0, maxLen)}...`;
  }
}
