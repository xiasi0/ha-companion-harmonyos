// Collects HarmonyOS device sensor snapshots and publishes them to Home Assistant mobile_app webhooks.
// This file owns sensor payload shape, preference snapshots, and foreground update behavior.
import batteryInfo from '@ohos.batteryInfo';
import deviceInfo from '@ohos.deviceInfo';
import storageStatistics from '@ohos.file.storageStatistics';
import power from '@ohos.power';
import audio from '@ohos.multimedia.audio';
import motion from '@ohos.multimodalAwareness.motion';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import bluetoothAccess from '@ohos.bluetooth.access';
import bluetoothConnection from '@ohos.bluetooth.connection';
import bluetoothA2dp from '@ohos.bluetooth.a2dp';
import bluetoothHfp from '@ohos.bluetooth.hfp';
import bluetoothHid from '@ohos.bluetooth.hid';
import bluetoothPan from '@ohos.bluetooth.pan';
import bluetoothBle from '@ohos.bluetooth.ble';
import nfcController from '@ohos.nfc.controller';
import screenLock from '@ohos.screenLock';
import display from '@ohos.display';
import geoLocationManager from '@ohos.geoLocationManager';
import systemDateTime from '@ohos.systemDateTime';
import { hidebug } from '@kit.PerformanceAnalysisKit';
import intelligentScene from '@ohos.intelligentScene';
import settings from '@ohos.settings';
import common from '@ohos.app.ability.common';
import statistics from '@ohos.net.statistics';
import call from '@ohos.telephony.call';
import sim from '@ohos.telephony.sim';
import cellularData from '@ohos.telephony.data';
import { connection } from '@kit.NetworkKit';
import { wifiManager } from '@kit.ConnectivityKit';
import type { Permissions } from '@ohos.abilityAccessCtrl';
import { NetworkHttpMethod, NetworkNetBearType, NetworkNetCap, NetworkService } from './NetworkService';
import { SensorStateRecord, SensorStateStore } from './SensorStateStore';
import {
  GeocodedLocationValue,
  HardwareSensorValues,
  MultimodalSensorValues,
  SensorRuntimeValueStore
} from './SensorRuntimeValueStore';
import { Localization } from '../shared/i18n/Localization';
import { HarmonyLocationSnapshot, HarmonyLocationZone } from './HarmonyLocationService';
import { HarmonySensorEntityCategoryPolicy } from './HarmonySensorEntityCategoryPolicy';
import { AppVersionService } from './AppVersionService';
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

interface TrafficStatsValues {
  totalTx?: number;
  totalRx?: number;
  cellularTx?: number;
  cellularRx?: number;
}

interface MobileDataValues {
  enabled?: boolean;
  roamingEnabled?: boolean;
  defaultSlotId?: number;
}

interface BluetoothConnectionValues {
  connectedNotPairedDevices: number;
  connectedPairedDevices: number;
  pairedDevices: number;
}

interface AppProcessSensorValue {
  state: string;
  active: boolean;
}

interface SimSensorValue {
  state: string;
  attributes: SensorAttributes;
}

interface SimLabelValue {
  simType: string;
  index?: number;
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
  private static publicIpAddressCache: string = '';
  private static publicIpAddressCacheAt: number = 0;
  private static publicIpAddressRetryAfter: number = 0;

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
    'battery_power',
    'ipv6_address',
    'public_ip_address',
    'wifi_state',
    'wifi_connection',
    'wifi_bssid',
    'wifi_ip_address',
    'wifi_frequency',
    'wifi_signal_strength',
    'wifi_link_speed',
    'hotspot_state',
    'phone_state',
    'has_call',
    'voice_capability',
    'sim_1',
    'sim_2',
    'mobile_data',
    'mobile_data_roaming',
    'total_tx_traffic',
    'total_rx_traffic',
    'cellular_tx_traffic',
    'cellular_rx_traffic',
    'harmony_os_version',
    'harmony_os_security_patch',
    'last_reboot_time',
    'do_not_disturb_sensor',
    'app_memory',
    'app_process_state',
    'current_version',
    'active',
    'current_time_zone',
    'storage_sensor',
    'is_interactive',
    'is_idle',
    'power_save',
    'bluetooth_state',
    'bluetooth_connection',
    'device_security',
    'device_locked',
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
    'harmony_operating_hand',
    'harmony_holding_hand',
    'location_permission',
    'nfc_state',
    'screen_orientation',
    'screen_rotation',
    'screen_brightness',
    'screen_off_timeout',
    'geocoded_location',
    'light_sensor',
    'proximity_sensor'
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
    reason: string,
    context?: common.Context
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
    const descriptors = await HarmonySensorService.buildSensorDescriptors(
      prefs,
      lastLocation,
      locationEnabledStatus,
      locationSentMode,
      context
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

  static async loadSensorStates(context: common.Context): Promise<void> {
    await SensorStateStore.loadRecords(context);
  }

  static async refreshSensorStates(
    prefs: SensorPreferenceSnapshot,
    lastLocation: HarmonyLocationSnapshot | undefined,
    locationEnabledStatus: boolean,
    locationSentMode: HarmonyLocationSentMode,
    context?: common.Context
  ): Promise<void> {
    await HarmonySensorService.refreshGeocodedLocationIfNeeded(prefs, lastLocation);
    await HarmonySensorService.buildSensorDescriptors(
      prefs,
      lastLocation,
      locationEnabledStatus,
      locationSentMode,
      context
    );
  }

  private static async buildSensorDescriptors(
    prefs: SensorPreferenceSnapshot,
    lastLocation: HarmonyLocationSnapshot | undefined,
    locationEnabledStatus: boolean,
    locationSentMode: HarmonyLocationSentMode,
    context?: common.Context
  ): Promise<SensorDescriptor[]> {
    const netSnapshot = HarmonySensorService.getNetworkSnapshot();
    const wifiSnapshot = HarmonySensorService.getWifiSnapshot();
    const storageSnapshot = HarmonySensorService.getStorageSnapshot();
    const displaySnapshot = HarmonySensorService.getDisplaySnapshot();
    const hardwareSnapshot = HarmonySensorService.hardwareSensorValues();
    const multimodalSnapshot = HarmonySensorService.multimodalSensorValues();
    const geocodedLocation = HarmonySensorService.geocodedLocationValue();
    const audioRouteSnapshot = HarmonySensorService.audioRouteSnapshot();
    const trafficStats = await HarmonySensorService.trafficStatsValues(prefs);
    const publicIpAddress = await HarmonySensorService.publicIpAddressValue(prefs);
    const batterySOC = HarmonySensorService.batteryLevelValue();
    const batteryState = HarmonySensorService.batteryStateValue();
    const pluggedType = HarmonySensorService.chargerTypeValue();
    const batteryTemperature = HarmonySensorService.batteryTemperatureValue();
    const batteryVoltage = HarmonySensorService.batteryVoltageValue();
    const batteryCurrent = HarmonySensorService.batteryCurrentValue();
    const batteryPower = HarmonySensorService.batteryPowerValue(batteryVoltage, batteryCurrent);
    const locationAttributes = HarmonySensorService.locationAttributes(lastLocation, locationSentMode);
    const lastUpdateTrigger = AppStorage.get<string>('lastUpdateTrigger') ?? 'unknown';
    const doNotDisturbEnabled = await HarmonySensorService.doNotDisturbEnabled(prefs);
    const appVersion = AppVersionService.versionInfo();
    const appMemorySize = await HarmonySensorService.appMemorySize(prefs);
    const appProcess = await HarmonySensorService.appProcessInformation(prefs);
    const screenOffTimeout = HarmonySensorService.screenOffTimeoutValue(prefs, context);
    const phoneState = await HarmonySensorService.phoneStateValue(prefs);
    const hasCall = await HarmonySensorService.hasCallValue(prefs);
    const voiceCapability = HarmonySensorService.voiceCapabilityValue(prefs);
    const sim1 = await HarmonySensorService.simSensorValue(0, prefs);
    const sim2 = await HarmonySensorService.simSensorValue(1, prefs);
    const mobileData = await HarmonySensorService.mobileDataValues(prefs);
    const bluetoothConnectionValues = HarmonySensorService.bluetoothConnectionValues(prefs);
    const deviceSecurity = await HarmonySensorService.screenLockSecureMode(prefs);
    const deviceLocked = await HarmonySensorService.screenLocked(prefs);

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
        id: 'battery_power',
        name: 'Battery power',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(batteryPower),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('battery_power', prefs),
        deviceClass: 'power',
        unitOfMeasurement: 'W',
        stateClass: 'measurement',
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
        id: 'ipv6_address',
        name: 'IPv6 address',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(HarmonySensorService.ipv6AddressValue()),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('ipv6_address', prefs),
      },
      {
        id: 'public_ip_address',
        name: 'Public IP address',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.nonEmptyText(publicIpAddress),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('public_ip_address', prefs),
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
        id: 'phone_state',
        name: 'Phone state',
        type: 'sensor',
        icon: HarmonySensorService.phoneStateIcon(phoneState),
        state: phoneState,
        attributes: {
          options: ['idle', 'ringing', 'offhook', 'answered', 'unknown']
        },
        enabled: HarmonySensorService.isSensorEnabled('phone_state', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'has_call',
        name: 'Has call',
        type: 'binary_sensor',
        icon: 'mdi:phone-in-talk',
        state: hasCall,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('has_call', prefs),
      },
      {
        id: 'voice_capability',
        name: 'Voice capability',
        type: 'binary_sensor',
        icon: 'mdi:phone-check',
        state: voiceCapability,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('voice_capability', prefs),
      },
      {
        id: 'sim_1',
        name: 'SIM 1',
        type: 'sensor',
        icon: 'mdi:sim',
        state: sim1.state,
        attributes: sim1.attributes,
        enabled: HarmonySensorService.isSensorEnabled('sim_1', prefs),
      },
      {
        id: 'sim_2',
        name: 'SIM 2',
        type: 'sensor',
        icon: 'mdi:sim',
        state: sim2.state,
        attributes: sim2.attributes,
        enabled: HarmonySensorService.isSensorEnabled('sim_2', prefs),
      },
      {
        id: 'mobile_data',
        name: 'Mobile data',
        type: 'binary_sensor',
        icon: 'mdi:signal-cellular-3',
        state: HarmonySensorService.booleanOrNull(mobileData.enabled),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('mobile_data', prefs),
      },
      {
        id: 'mobile_data_roaming',
        name: 'Mobile data roaming',
        type: 'binary_sensor',
        icon: 'mdi:signal-cellular-outline',
        state: HarmonySensorService.booleanOrNull(mobileData.roamingEnabled),
        attributes: {
          default_cellular_data_slot_id: mobileData.defaultSlotId
        },
        enabled: HarmonySensorService.isSensorEnabled('mobile_data_roaming', prefs),
      },
      {
        id: 'total_tx_traffic',
        name: 'Total sent traffic',
        type: 'sensor',
        icon: 'mdi:upload-network',
        state: HarmonySensorService.numberOrUnavailable(trafficStats.totalTx),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('total_tx_traffic', prefs),
        deviceClass: 'data_size',
        unitOfMeasurement: 'GB',
        stateClass: 'total_increasing',
      },
      {
        id: 'total_rx_traffic',
        name: 'Total received traffic',
        type: 'sensor',
        icon: 'mdi:download-network',
        state: HarmonySensorService.numberOrUnavailable(trafficStats.totalRx),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('total_rx_traffic', prefs),
        deviceClass: 'data_size',
        unitOfMeasurement: 'GB',
        stateClass: 'total_increasing',
      },
      {
        id: 'cellular_tx_traffic',
        name: 'Mobile data sent traffic',
        type: 'sensor',
        icon: 'mdi:upload-network-outline',
        state: HarmonySensorService.numberOrUnavailable(trafficStats.cellularTx),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('cellular_tx_traffic', prefs),
        deviceClass: 'data_size',
        unitOfMeasurement: 'GB',
        stateClass: 'total_increasing',
      },
      {
        id: 'cellular_rx_traffic',
        name: 'Mobile data received traffic',
        type: 'sensor',
        icon: 'mdi:download-network-outline',
        state: HarmonySensorService.numberOrUnavailable(trafficStats.cellularRx),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('cellular_rx_traffic', prefs),
        deviceClass: 'data_size',
        unitOfMeasurement: 'GB',
        stateClass: 'total_increasing',
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
        id: 'last_reboot_time',
        name: 'Last reboot time',
        type: 'sensor',
        icon: 'mdi:restart',
        state: HarmonySensorService.lastRebootTimeValue(),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('last_reboot_time', prefs),
      },
      {
        id: 'do_not_disturb_sensor',
        name: 'Do not disturb sensor',
        type: 'binary_sensor',
        icon: 'mdi:minus-circle',
        state: doNotDisturbEnabled,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('do_not_disturb_sensor', prefs),
      },
      {
        id: 'app_memory',
        name: 'App memory',
        type: 'sensor',
        icon: 'mdi:memory',
        state: HarmonySensorService.numberOrUnavailable(appMemorySize),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('app_memory', prefs),
        unitOfMeasurement: 'MB',
        stateClass: 'measurement',
      },
      {
        id: 'app_process_state',
        name: 'App process state',
        type: 'sensor',
        icon: 'mdi:application-cog',
        state: appProcess.state,
        attributes: {
          process_state: appProcess.state,
          is_active: appProcess.active
        },
        enabled: HarmonySensorService.isSensorEnabled('app_process_state', prefs),
        deviceClass: 'enum',
      },
      {
        id: 'current_version',
        name: 'Current app version',
        type: 'sensor',
        icon: 'mdi:cellphone-arrow-down',
        state: appVersion.versionName,
        attributes: {
          app_version_name: appVersion.versionName,
          app_version_code: appVersion.versionCode
        },
        enabled: HarmonySensorService.isSensorEnabled('current_version', prefs),
      },
      {
        id: 'active',
        name: 'App active',
        type: 'binary_sensor',
        icon: 'mdi:application',
        state: AppStorage.get<boolean>('appActive') ?? false,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('active', prefs),
      },
      {
        id: 'current_time_zone',
        name: 'Current time zone',
        type: 'sensor',
        icon: 'mdi:map-clock',
        state: HarmonySensorService.currentTimeZoneValue(),
        attributes: {
          current_time_zone: HarmonySensorService.currentTimeZoneValue()
        },
        enabled: HarmonySensorService.isSensorEnabled('current_time_zone', prefs),
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
        id: 'bluetooth_connection',
        name: 'Bluetooth connection',
        type: 'sensor',
        icon: 'mdi:bluetooth-connect',
        state: bluetoothConnectionValues.connectedNotPairedDevices + bluetoothConnectionValues.connectedPairedDevices,
        attributes: {
          connectde_not_paired_devices: bluetoothConnectionValues.connectedNotPairedDevices,
          connectde_paired_devices: bluetoothConnectionValues.connectedPairedDevices,
          paired_devices: bluetoothConnectionValues.pairedDevices
        },
        enabled: HarmonySensorService.isSensorEnabled('bluetooth_connection', prefs),
        stateClass: 'measurement',
      },
      {
        id: 'device_security',
        name: 'Device security',
        type: 'binary_sensor',
        icon: 'mdi:shield-lock',
        state: deviceSecurity,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('device_security', prefs),
      },
      {
        id: 'device_locked',
        name: 'Device locked',
        type: 'binary_sensor',
        icon: 'mdi:lock',
        state: deviceLocked,
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('device_locked', prefs),
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
        id: 'screen_off_timeout',
        name: 'Screen off timeout',
        type: 'sensor',
        icon: 'mdi:timer-off-outline',
        state: HarmonySensorService.numberOrUnavailable(screenOffTimeout),
        attributes: {},
        enabled: HarmonySensorService.isSensorEnabled('screen_off_timeout', prefs),
        unitOfMeasurement: 's',
        stateClass: 'measurement',
      },
      {
        id: 'light_sensor',
        name: 'Light sensor',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(HarmonySensorService.roundOptional(hardwareSnapshot.light, 100)),
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
        id: 'proximity_sensor',
        name: 'Proximity sensor',
        type: 'sensor',
        icon: SENSOR_ICON_GENERIC,
        state: HarmonySensorService.numberOrUnavailable(hardwareSnapshot.proximityDistance),
        attributes: {
          proximity_distance: hardwareSnapshot.proximityDistance,
          sensor_updated_at: hardwareSnapshot.updatedAt
        },
        enabled: HarmonySensorService.isSensorEnabled('proximity_sensor', prefs),
        stateClass: 'measurement',
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
    const categorized = HarmonySensorEntityCategoryPolicy.apply(descriptors);
    await HarmonySensorService.rememberSensorStates(categorized, context);
    return categorized;
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

  private static async rememberSensorStates(descriptors: SensorDescriptor[], context?: common.Context): Promise<void> {
    const records: SensorStateRecord[] = [];
    const disabledSensorIds: string[] = [];
    for (let i = 0; i < descriptors.length; i++) {
      const descriptor = descriptors[i];
      if (descriptor.enabled) {
        records.push(HarmonySensorService.sensorStateRecord(descriptor));
      } else {
        disabledSensorIds.push(descriptor.id);
      }
    }
    await SensorStateStore.upsertRecords(context, records, disabledSensorIds);
  }

  private static sensorStateRecord(descriptor: SensorDescriptor): SensorStateRecord {
    return {
      sensorId: descriptor.id,
      stateJson: JSON.stringify(HarmonySensorService.webhookState(descriptor.state)),
      summary: HarmonySensorService.sensorStateSummary(descriptor),
      unitOfMeasurement: descriptor.unitOfMeasurement ?? '',
      deviceClass: descriptor.deviceClass ?? '',
      icon: descriptor.icon,
      attributesJson: JSON.stringify(descriptor.attributes),
      updatedAt: Date.now()
    };
  }

  private static sensorStateSummary(descriptor: SensorDescriptor): string {
    const state = HarmonySensorService.webhookState(descriptor.state);
    if (state === null) {
      return Localization.t('common_unavailable');
    }
    if (typeof state === 'boolean') {
      return state.toString();
    }
    if (typeof state === 'number') {
      const unit = descriptor.unitOfMeasurement ?? '';
      return unit.length > 0 ? `${state} ${unit}` : `${state}`;
    }
    const trimmed = state.trim();
    if (trimmed.length === 0 || trimmed === SENSOR_TEXT_UNAVAILABLE) {
      return Localization.t('common_unavailable');
    }
    if (trimmed === SENSOR_TEXT_UNKNOWN || trimmed === 'unknown') {
      return Localization.t('state_unknown');
    }
    return trimmed;
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
    HarmonySensorService.appendAttributeSignature(parts, 'approximate_location', attributes.approximate_location);
    HarmonySensorService.appendAttributeSignature(parts, 'audio_scene', attributes.audio_scene);
    HarmonySensorService.appendAttributeSignature(parts, 'background_location', attributes.background_location);
    HarmonySensorService.appendAttributeSignature(parts, 'bssid', attributes.bssid);
    HarmonySensorService.appendAttributeSignature(parts, 'card_type', attributes.card_type);
    HarmonySensorService.appendAttributeSignature(parts, 'connectde_not_paired_devices', attributes.connectde_not_paired_devices);
    HarmonySensorService.appendAttributeSignature(parts, 'connectde_paired_devices', attributes.connectde_paired_devices);
    HarmonySensorService.appendAttributeSignature(parts, 'color_temperature', attributes.color_temperature);
    HarmonySensorService.appendAttributeSignature(parts, 'country_code', attributes.country_code);
    HarmonySensorService.appendAttributeSignature(parts, 'country_name', attributes.country_name);
    HarmonySensorService.appendAttributeSignature(parts, 'current_headroom', attributes.current_headroom);
    HarmonySensorService.appendAttributeSignature(parts, 'default_voice_slot', attributes.default_voice_slot);
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
    HarmonySensorService.appendAttributeSignature(parts, 'has_sim', attributes.has_sim);
    HarmonySensorService.appendAttributeSignature(parts, 'hdr_formats', attributes.hdr_formats);
    HarmonySensorService.appendAttributeSignature(parts, 'hidden', attributes.hidden);
    HarmonySensorService.appendAttributeSignature(parts, 'infrared_luminance', attributes.infrared_luminance);
    HarmonySensorService.appendAttributeSignature(parts, 'ip_address', attributes.ip_address);
    HarmonySensorService.appendAttributeSignature(parts, 'is_active', attributes.is_active);
    HarmonySensorService.appendAttributeSignature(parts, 'app_version_code', attributes.app_version_code);
    HarmonySensorService.appendAttributeSignature(parts, 'app_version_name', attributes.app_version_name);
    HarmonySensorService.appendAttributeSignature(parts, 'current_time_zone', attributes.current_time_zone);
    HarmonySensorService.appendAttributeSignature(parts, 'process_state', attributes.process_state);
    HarmonySensorService.appendAttributeSignature(parts, 'last_update_trigger', attributes.last_update_trigger);
    HarmonySensorService.appendAttributeSignature(parts, 'latitude', attributes.latitude);
    HarmonySensorService.appendAttributeSignature(parts, 'link_speed', attributes.link_speed);
    HarmonySensorService.appendAttributeSignature(parts, 'locality', attributes.locality);
    HarmonySensorService.appendAttributeSignature(parts, 'location_sent', attributes.location_sent);
    HarmonySensorService.appendAttributeSignature(parts, 'longitude', attributes.longitude);
    HarmonySensorService.appendAttributeSignature(parts, 'max_headroom', attributes.max_headroom);
    HarmonySensorService.appendAttributeSignature(parts, 'max_sim_count', attributes.max_sim_count);
    HarmonySensorService.appendAttributeSignature(parts, 'max_volume', attributes.max_volume);
    HarmonySensorService.appendAttributeSignature(parts, 'metered', attributes.metered);
    HarmonySensorService.appendAttributeSignature(parts, 'min_volume', attributes.min_volume);
    HarmonySensorService.appendAttributeSignature(parts, 'nfc_state', attributes.nfc_state);
    HarmonySensorService.appendAttributeSignature(parts, 'operator_key', attributes.operator_key);
    HarmonySensorService.appendAttributeSignature(parts, 'operator_name', attributes.operator_name);
    HarmonySensorService.appendAttributeSignature(parts, 'operator_numeric', attributes.operator_numeric);
    HarmonySensorService.appendAttributeSignature(parts, 'options', attributes.options);
    HarmonySensorService.appendAttributeSignature(parts, 'os_full_name', attributes.os_full_name);
    HarmonySensorService.appendAttributeSignature(parts, 'output_device_count', attributes.output_device_count);
    HarmonySensorService.appendAttributeSignature(parts, 'output_device_types', attributes.output_device_types);
    HarmonySensorService.appendAttributeSignature(parts, 'paired_devices', attributes.paired_devices);
    HarmonySensorService.appendAttributeSignature(parts, 'place_name', attributes.place_name);
    HarmonySensorService.appendAttributeSignature(parts, 'postal_code', attributes.postal_code);
    HarmonySensorService.appendAttributeSignature(parts, 'power_mode', attributes.power_mode);
    HarmonySensorService.appendAttributeSignature(parts, 'precise_location', attributes.precise_location);
    HarmonySensorService.appendAttributeSignature(parts, 'premises', attributes.premises);
    HarmonySensorService.appendAttributeSignature(parts, 'proximity_distance', attributes.proximity_distance);
    HarmonySensorService.appendAttributeSignature(parts, 'road_name', attributes.road_name);
    HarmonySensorService.appendAttributeSignature(parts, 'sdk_api_version', attributes.sdk_api_version);
    HarmonySensorService.appendAttributeSignature(parts, 'sdr_nits', attributes.sdr_nits);
    HarmonySensorService.appendAttributeSignature(parts, 'security_patch', attributes.security_patch);
    HarmonySensorService.appendAttributeSignature(parts, 'sensor_updated_at', attributes.sensor_updated_at);
    HarmonySensorService.appendAttributeSignature(parts, 'signal_level', attributes.signal_level);
    HarmonySensorService.appendAttributeSignature(parts, 'sim_label_index', attributes.sim_label_index);
    HarmonySensorService.appendAttributeSignature(parts, 'sim_label_type', attributes.sim_label_type);
    HarmonySensorService.appendAttributeSignature(parts, 'sim_state', attributes.sim_state);
    HarmonySensorService.appendAttributeSignature(parts, 'slot_id', attributes.slot_id);
    HarmonySensorService.appendAttributeSignature(parts, 'source_mode', attributes.source_mode);
    HarmonySensorService.appendAttributeSignature(parts, 'spn', attributes.spn);
    HarmonySensorService.appendAttributeSignature(parts, 'sub_administrative_area', attributes.sub_administrative_area);
    HarmonySensorService.appendAttributeSignature(parts, 'sub_locality', attributes.sub_locality);
    HarmonySensorService.appendAttributeSignature(parts, 'sub_road_name', attributes.sub_road_name);
    HarmonySensorService.appendAttributeSignature(parts, 'timeStamp', attributes.timeStamp);
    HarmonySensorService.appendAttributeSignature(parts, 'total_size', attributes.total_size);
    HarmonySensorService.appendAttributeSignature(parts, 'used_percent', attributes.used_percent);
    HarmonySensorService.appendAttributeSignature(parts, 'used_size', attributes.used_size);
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

  private static ipv6AddressValue(): string {
    try {
      const netHandle = connection.getDefaultNetSync();
      const properties = connection.getConnectionPropertiesSync(netHandle);
      for (let i = 0; i < properties.linkAddresses.length; i++) {
        const address = properties.linkAddresses[i].address;
        if (address.family === 2 && address.address.indexOf(':') >= 0) {
          return address.address;
        }
      }
    } catch (_) {
    }
    return '';
  }

  private static async publicIpAddressValue(prefs: SensorPreferenceSnapshot): Promise<string> {
    if (!HarmonySensorService.isSensorEnabled('public_ip_address', prefs)) {
      return '';
    }
    const now = Date.now();
    if (HarmonySensorService.publicIpAddressCache.length > 0 &&
      now - HarmonySensorService.publicIpAddressCacheAt < 10 * 60 * 1000) {
      return HarmonySensorService.publicIpAddressCache;
    }
    if (now < HarmonySensorService.publicIpAddressRetryAfter) {
      return '';
    }
    try {
      const response = await NetworkService.requestText('https://api.ipify.org', {
        method: NetworkHttpMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      if (!NetworkService.isSuccessStatus(response.responseCode)) {
        HarmonySensorService.markPublicIpAddressRetry(now);
        return '';
      }
      const value = HarmonySensorService.normalizedIpText(response.body);
      if (value.length > 0) {
        HarmonySensorService.publicIpAddressCache = value;
        HarmonySensorService.publicIpAddressCacheAt = now;
        HarmonySensorService.publicIpAddressRetryAfter = 0;
      } else {
        HarmonySensorService.markPublicIpAddressRetry(now);
      }
      return value;
    } catch (_) {
      HarmonySensorService.markPublicIpAddressRetry(now);
      return '';
    }
  }

  private static markPublicIpAddressRetry(now: number): void {
    HarmonySensorService.publicIpAddressRetryAfter = now + 60 * 1000;
  }

  private static normalizedIpText(value: string): string {
    const trimmed = value.trim();
    if (/^[0-9A-Fa-f:.]+$/.test(trimmed) && (trimmed.indexOf('.') >= 0 || trimmed.indexOf(':') >= 0)) {
      return trimmed;
    }
    return '';
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
      case batteryInfo.BatteryChargeState.NONE:
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

  private static bluetoothConnectionValues(prefs: SensorPreferenceSnapshot): BluetoothConnectionValues {
    const empty: BluetoothConnectionValues = {
      connectedNotPairedDevices: 0,
      connectedPairedDevices: 0,
      pairedDevices: 0
    };
    if (!HarmonySensorService.isSensorEnabled('bluetooth_connection', prefs) || !HarmonySensorService.bluetoothEnabled()) {
      return empty;
    }

    const pairedDevices = HarmonySensorService.bluetoothPairedDevices();
    const pairedSet = new Set<string>(pairedDevices);
    const connectedSet = new Set<string>();
    HarmonySensorService.addBluetoothDevices(connectedSet, HarmonySensorService.bluetoothBleConnectedDevices());
    HarmonySensorService.addBluetoothDevices(connectedSet, HarmonySensorService.bluetoothProfileConnectedDevices((): string[] => {
      return bluetoothA2dp.createA2dpSrcProfile().getConnectedDevices();
    }));
    HarmonySensorService.addBluetoothDevices(connectedSet, HarmonySensorService.bluetoothProfileConnectedDevices((): string[] => {
      return bluetoothHfp.createHfpAgProfile().getConnectedDevices();
    }));
    HarmonySensorService.addBluetoothDevices(connectedSet, HarmonySensorService.bluetoothProfileConnectedDevices((): string[] => {
      return bluetoothHid.createHidHostProfile().getConnectedDevices();
    }));
    HarmonySensorService.addBluetoothDevices(connectedSet, HarmonySensorService.bluetoothProfileConnectedDevices((): string[] => {
      return bluetoothPan.createPanProfile().getConnectedDevices();
    }));

    let connectedPairedDevices = 0;
    connectedSet.forEach((deviceId: string): void => {
      if (pairedSet.has(deviceId)) {
        connectedPairedDevices += 1;
      }
    });
    return {
      connectedNotPairedDevices: Math.max(connectedSet.size - connectedPairedDevices, 0),
      connectedPairedDevices,
      pairedDevices: pairedDevices.length
    };
  }

  private static bluetoothPairedDevices(): string[] {
    try {
      return bluetoothConnection.getPairedDevices();
    } catch (_) {
      return [];
    }
  }

  private static bluetoothBleConnectedDevices(): string[] {
    try {
      return bluetoothBle.getConnectedBLEDevices();
    } catch (_) {
      return [];
    }
  }

  private static bluetoothProfileConnectedDevices(readValue: () => string[]): string[] {
    try {
      return readValue();
    } catch (_) {
      return [];
    }
  }

  private static addBluetoothDevices(target: Set<string>, devices: string[]): void {
    for (let i = 0; i < devices.length; i++) {
      const deviceId = devices[i].trim();
      if (deviceId.length > 0) {
        target.add(deviceId);
      }
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
    SensorRuntimeValueStore.updateGeocoded(value);
  }

  private static geocodedLocationValue(): GeocodedLocationValue {
    return SensorRuntimeValueStore.geocoded();
  }

  private static hardwareSensorValues(): HardwareSensorValues {
    return SensorRuntimeValueStore.hardware();
  }

  private static multimodalSensorValues(): MultimodalSensorValues {
    return SensorRuntimeValueStore.multimodal();
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

  private static async phoneStateValue(prefs: SensorPreferenceSnapshot): Promise<string> {
    if (!HarmonySensorService.isSensorEnabled('phone_state', prefs)) {
      return SENSOR_TEXT_UNAVAILABLE;
    }
    try {
      return HarmonySensorService.callStateValue(await call.getCallState());
    } catch (_) {
      return SENSOR_TEXT_UNAVAILABLE;
    }
  }

  private static async hasCallValue(prefs: SensorPreferenceSnapshot): Promise<boolean | null> {
    if (!HarmonySensorService.isSensorEnabled('has_call', prefs)) {
      return null;
    }
    try {
      return await call.hasCall();
    } catch (_) {
      return null;
    }
  }

  private static voiceCapabilityValue(prefs: SensorPreferenceSnapshot): boolean | null {
    if (!HarmonySensorService.isSensorEnabled('voice_capability', prefs)) {
      return null;
    }
    try {
      return call.hasVoiceCapability();
    } catch (_) {
      return null;
    }
  }

  private static async simSensorValue(slotId: number, prefs: SensorPreferenceSnapshot): Promise<SimSensorValue> {
    const sensorId = slotId === 0 ? 'sim_1' : 'sim_2';
    const baseAttributes: SensorAttributes = {
      slot_id: slotId,
      max_sim_count: HarmonySensorService.maxSimCount()
    };
    if (!HarmonySensorService.isSensorEnabled(sensorId, prefs)) {
      return {
        state: SENSOR_TEXT_UNAVAILABLE,
        attributes: baseAttributes
      };
    }

    const hasSim = await HarmonySensorService.readBoolean((): Promise<boolean> => sim.hasSimCard(slotId));
    const isActive = await HarmonySensorService.readBoolean((): Promise<boolean> => sim.isSimActive(slotId));
    const simState = HarmonySensorService.simStateValue(
      await HarmonySensorService.readNumber((): Promise<number> => sim.getSimState(slotId))
    );
    const cardType = HarmonySensorService.cardTypeValue(
      await HarmonySensorService.readNumber((): Promise<number> => sim.getCardType(slotId))
    );
    const countryCode = await HarmonySensorService.readString((): Promise<string> => sim.getISOCountryCodeForSim(slotId));
    const operatorNumeric = await HarmonySensorService.readString((): Promise<string> => sim.getSimOperatorNumeric(slotId));
    const spn = await HarmonySensorService.readString((): Promise<string> => sim.getSimSpn(slotId));
    const operatorName = await HarmonySensorService.readString((): Promise<string> => sim.getOpName(slotId));
    const operatorKey = await HarmonySensorService.readString((): Promise<string> => sim.getOpKey(slotId));
    const defaultVoiceSlot = await HarmonySensorService.defaultVoiceSlotId() === slotId;
    const simLabel = await HarmonySensorService.simLabelValue(slotId);
    const state = HarmonySensorService.simDisplayState(operatorName, spn, simState, hasSim);

    return {
      state,
      attributes: {
        slot_id: slotId,
        has_sim: hasSim,
        is_active: isActive,
        sim_state: simState,
        card_type: cardType,
        country_code: countryCode,
        operator_numeric: operatorNumeric,
        spn,
        operator_name: operatorName,
        operator_key: operatorKey,
        sim_label_type: simLabel.simType,
        sim_label_index: simLabel.index,
        default_voice_slot: defaultVoiceSlot,
        max_sim_count: baseAttributes.max_sim_count
      }
    };
  }

  private static callStateValue(value: call.CallState): string {
    switch (value) {
      case call.CallState.CALL_STATE_IDLE:
        return 'idle';
      case call.CallState.CALL_STATE_RINGING:
        return 'ringing';
      case call.CallState.CALL_STATE_OFFHOOK:
        return 'offhook';
      case call.CallState.CALL_STATE_ANSWERED:
        return 'answered';
      default:
        return 'unknown';
    }
  }

  private static phoneStateIcon(value: string): string {
    if (value === 'ringing' || value === 'offhook' || value === 'answered') {
      return 'mdi:phone-in-talk';
    }
    return 'mdi:phone';
  }

  private static simDisplayState(operatorName: string, spn: string, simState: string, hasSim: boolean | undefined): string {
    // SPN from SIM usually contains the user-friendly carrier name
    if (spn.length > 0) {
      return spn;
    }
    if (operatorName.length > 0) {
      return operatorName;
    }
    if (hasSim === false) {
      return 'not_present';
    }
    return simState;
  }

  private static simStateValue(value: number | undefined): string {
    switch (value) {
      case sim.SimState.SIM_STATE_UNKNOWN:
        return 'unknown';
      case sim.SimState.SIM_STATE_NOT_PRESENT:
        return 'not_present';
      case sim.SimState.SIM_STATE_LOCKED:
        return 'locked';
      case sim.SimState.SIM_STATE_NOT_READY:
        return 'not_ready';
      case sim.SimState.SIM_STATE_READY:
        return 'ready';
      case sim.SimState.SIM_STATE_LOADED:
        return 'loaded';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static cardTypeValue(value: number | undefined): string {
    switch (value) {
      case sim.CardType.SINGLE_MODE_SIM_CARD:
        return 'sim';
      case sim.CardType.SINGLE_MODE_USIM_CARD:
        return 'usim';
      case sim.CardType.SINGLE_MODE_RUIM_CARD:
        return 'ruim';
      case sim.CardType.DUAL_MODE_CG_CARD:
        return 'dual_mode_cg';
      case sim.CardType.CT_NATIONAL_ROAMING_CARD:
        return 'ct_national_roaming';
      case sim.CardType.CU_DUAL_MODE_CARD:
        return 'cu_dual_mode';
      case sim.CardType.DUAL_MODE_TELECOM_LTE_CARD:
        return 'dual_mode_telecom_lte';
      case sim.CardType.DUAL_MODE_UG_CARD:
        return 'dual_mode_ug';
      case sim.CardType.SINGLE_MODE_ISIM_CARD:
        return 'isim';
      case sim.CardType.UNKNOWN_CARD:
        return 'unknown';
      default:
        return SENSOR_TEXT_UNKNOWN;
    }
  }

  private static async simLabelValue(slotId: number): Promise<SimLabelValue> {
    try {
      const label = await sim.getSimLabel(slotId);
      return {
        simType: label.simType === sim.SimType.ESIM ? 'esim' : 'psim',
        index: label.index
      };
    } catch (_) {
      return {
        simType: SENSOR_TEXT_UNKNOWN,
        index: undefined
      };
    }
  }

  private static maxSimCount(): number | undefined {
    try {
      return sim.getMaxSimCount();
    } catch (_) {
      return undefined;
    }
  }

  private static async defaultVoiceSlotId(): Promise<number | undefined> {
    try {
      return await sim.getDefaultVoiceSlotId();
    } catch (_) {
      return undefined;
    }
  }

  private static async readString(readValue: () => Promise<string>): Promise<string> {
    try {
      return (await readValue()).trim();
    } catch (_) {
      return '';
    }
  }

  private static async readBoolean(readValue: () => Promise<boolean>): Promise<boolean | undefined> {
    try {
      return await readValue();
    } catch (_) {
      return undefined;
    }
  }

  private static async readNumber(readValue: () => Promise<number>): Promise<number | undefined> {
    try {
      return await readValue();
    } catch (_) {
      return undefined;
    }
  }

  private static async mobileDataValues(prefs: SensorPreferenceSnapshot): Promise<MobileDataValues> {
    const readEnabled = HarmonySensorService.isSensorEnabled('mobile_data', prefs);
    const readRoaming = HarmonySensorService.isSensorEnabled('mobile_data_roaming', prefs);
    if (!readEnabled && !readRoaming) {
      return {};
    }

    const defaultSlotId = readRoaming ?
      await HarmonySensorService.readNumber((): Promise<number> => cellularData.getDefaultCellularDataSlotId()) :
      undefined;
    const roamingEnabled = readRoaming && typeof defaultSlotId === 'number' && defaultSlotId >= 0 ?
      await HarmonySensorService.readBoolean((): Promise<boolean> => cellularData.isCellularDataRoamingEnabled(defaultSlotId)) :
      undefined;

    return {
      enabled: readEnabled ?
        await HarmonySensorService.readBoolean((): Promise<boolean> => cellularData.isCellularDataEnabled()) :
        undefined,
      roamingEnabled,
      defaultSlotId
    };
  }

  private static numberOrUnavailable(value: number | undefined): number | null {
    return typeof value === 'number' ? value : null;
  }

  private static booleanOrNull(value: boolean | undefined): boolean | null {
    return typeof value === 'boolean' ? value : null;
  }

  private static async trafficStatsValues(prefs: SensorPreferenceSnapshot): Promise<TrafficStatsValues> {
    const totalTx = await HarmonySensorService.trafficStatValue('total_tx_traffic', prefs, (): Promise<number> => {
      return statistics.getAllTxBytes();
    });
    const totalRx = await HarmonySensorService.trafficStatValue('total_rx_traffic', prefs, (): Promise<number> => {
      return statistics.getAllRxBytes();
    });
    const cellularTx = await HarmonySensorService.trafficStatValue('cellular_tx_traffic', prefs, (): Promise<number> => {
      return statistics.getCellularTxBytes();
    });
    const cellularRx = await HarmonySensorService.trafficStatValue('cellular_rx_traffic', prefs, (): Promise<number> => {
      return statistics.getCellularRxBytes();
    });
    return {
      totalTx,
      totalRx,
      cellularTx,
      cellularRx
    };
  }

  private static async trafficStatValue(
    sensorId: string,
    prefs: SensorPreferenceSnapshot,
    readValue: () => Promise<number>
  ): Promise<number | undefined> {
    if (!HarmonySensorService.isSensorEnabled(sensorId, prefs)) {
      return undefined;
    }
    try {
      return HarmonySensorService.bytesToGb(await readValue());
    } catch (_) {
      return undefined;
    }
  }

  private static bytesToGb(value: number): number | undefined {
    if (!Number.isFinite(value) || value < 0) {
      return undefined;
    }
    return Math.round((value / 1073741824) * 1000) / 1000;
  }

  private static screenOffTimeoutValue(prefs: SensorPreferenceSnapshot, context?: common.Context): number | undefined {
    if (!HarmonySensorService.isSensorEnabled('screen_off_timeout', prefs) || !context) {
      return undefined;
    }
    try {
      const value = Number(settings.getValueSync(context, settings.display.SCREEN_OFF_TIMEOUT, ''));
      // System returns ms; convert to seconds
      return Number.isFinite(value) ? Math.round(value / 1000) : undefined;
    } catch (_) {
      return undefined;
    }
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

  private static async screenLockSecureMode(prefs: SensorPreferenceSnapshot): Promise<boolean | null> {
    if (!HarmonySensorService.isSensorEnabled('device_security', prefs)) {
      return null;
    }
    try {
      return await screenLock.isSecureMode();
    } catch (_) {
      return null;
    }
  }

  private static async screenLocked(prefs: SensorPreferenceSnapshot): Promise<boolean | null> {
    if (!HarmonySensorService.isSensorEnabled('device_locked', prefs)) {
      return null;
    }
    try {
      return await screenLock.isScreenLocked();
    } catch (_) {
      return null;
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

  private static async appMemorySize(prefs: SensorPreferenceSnapshot): Promise<number | undefined> {
    if (!HarmonySensorService.isSensorEnabled('app_memory', prefs)) {
      return undefined;
    }
    try {
      // getPss() returns actual physical memory (PSS) in KB; convert to MB
      const pssKb: bigint = hidebug.getPss();
      return Number((Number(pssKb) / 1024).toFixed(1));
    } catch (_) {
      return undefined;
    }
  }

  private static async appProcessInformation(prefs: SensorPreferenceSnapshot): Promise<AppProcessSensorValue> {
    if (!HarmonySensorService.isSensorEnabled('app_process_state', prefs)) {
      return { state: SENSOR_TEXT_UNAVAILABLE, active: false };
    }
    const active = AppStorage.get<boolean>('appActive') ?? false;
    return {
      state: active ? 'foreground' : 'background',
      active
    };
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

  private static lastRebootTimeValue(): string {
    try {
      const bootTime = systemDateTime.getTime() - systemDateTime.getUptime(systemDateTime.TimeType.STARTUP);
      if (!Number.isFinite(bootTime) || bootTime <= 0) {
        return SENSOR_TEXT_UNAVAILABLE;
      }
      return HarmonySensorService.formatLocalMinute(new Date(bootTime));
    } catch (_) {
      return SENSOR_TEXT_UNAVAILABLE;
    }
  }

  private static currentTimeZoneValue(): string {
    try {
      return HarmonySensorService.nonEmptyText(systemDateTime.getTimezoneSync());
    } catch (_) {
      return SENSOR_TEXT_UNAVAILABLE;
    }
  }

  private static async doNotDisturbEnabled(prefs: SensorPreferenceSnapshot): Promise<boolean | null> {
    if (!HarmonySensorService.isSensorEnabled('do_not_disturb_sensor', prefs)) {
      return null;
    }
    try {
      return await intelligentScene.isDoNotDisturbEnabled();
    } catch (_) {
      return null;
    }
  }

  private static formatLocalMinute(value: Date): string {
    return `${value.getFullYear()}-${HarmonySensorService.padDatePart(value.getMonth() + 1)}-${HarmonySensorService.padDatePart(value.getDate())} ` +
      `${HarmonySensorService.padDatePart(value.getHours())}:${HarmonySensorService.padDatePart(value.getMinutes())}`;
  }

  private static padDatePart(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
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
