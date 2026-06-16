// Persistent settings bridge between AppStorage and HarmonyOS preferences.
// Values are scoped per active server when the setting is server-specific.
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { normalizeSensorUpdateFrequency, SensorUpdateFrequency } from '../features/sensors/SensorModels';
import type { SensorRuntimeFlags } from '../features/sensors/SensorRuntimePresenter';
import { HomeNetworkService, HomeNetworkSettings } from './HomeNetworkService';
import { AppSettingsKeys, AppSettingsScopedKeys } from './AppSettingsKeys';
import { AppSettingsValueCodec } from './AppSettingsValueCodec';
import { HarmonySensorService } from './HarmonySensorService';
import { ServerInstanceStore } from './ServerInstanceStore';

export interface ServerConnectionPolicySettings {
  externalUrl: string;
  internalUrl: string;
  secureConnectionChoice: string;
  homeNetwork: HomeNetworkSettings;
}

export class AppSettingsStore {
  private static readonly MISSING_HOME_WIFI_SSIDS_JSON = '__missing_home_wifi_ssids_json__';

  static async loadWebsocketMode(context: common.Context): Promise<string> {
    const pref = await AppSettingsStore.getPreferences(context);
    const serverId = AppSettingsStore.activeServerId(context);
    return AppSettingsStore.normalizeWebsocketMode(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.WEBSOCKET_MODE, 'system'));
  }

  static async loadServiceCardUpdateFrequency(context: common.Context): Promise<string> {
    const runtimeWebsocketMode = AppStorage.get<string>('websocketMode');
    const runtimeFrequency = AppStorage.get<string>('serviceCardUpdateFrequency');
    if (runtimeWebsocketMode !== undefined || runtimeFrequency !== undefined) {
      return AppSettingsStore.normalizeServiceCardUpdateFrequency(runtimeFrequency ?? 'default', runtimeWebsocketMode ?? 'system');
    }
    const pref = await AppSettingsStore.getPreferences(context);
    const serverId = AppSettingsStore.activeServerId(context);
    const websocketMode = AppSettingsStore.normalizeWebsocketMode(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.WEBSOCKET_MODE, 'system'));
    const value = AppSettingsStore.normalizeServiceCardUpdateFrequency(
      await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SERVICE_CARD_UPDATE_FREQUENCY, 'default'),
      websocketMode
    );
    if (websocketMode === 'always') {
      await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SERVICE_CARD_UPDATE_FREQUENCY, value);
      await AppSettingsStore.flush(pref);
    }
    return value;
  }

  static async saveWebsocketMode(context: common.Context, value: string): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    const websocketMode = AppSettingsStore.normalizeWebsocketMode(value);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.WEBSOCKET_MODE, websocketMode);
    if (websocketMode === 'always') {
      await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SERVICE_CARD_UPDATE_FREQUENCY, 'default');
    }
    await AppSettingsStore.flush(pref);
  }

  static async saveSensorFlags(context: common.Context, flags: SensorRuntimeFlags): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_BATTERY_SOC, flags.batterySOCEnabled);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_CHARGING_STATUS, flags.chargingStatusEnabled);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_PLUGGED_TYPE, flags.pluggedTypeEnabled);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_BEARER_TYPES, flags.bearerTypesEnabled);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_LAST_UPDATE_TRIGGER, flags.lastUpdateTriggerEnabled);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_LOCATION_BACKGROUND, flags.locationBackgroundEnabled);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_ZONE_BACKGROUND, flags.zoneBackgroundEnabled);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_ACCURATE_LOCATION, flags.accurateLocationEnabled);
    await AppSettingsStore.putActiveValue(
      context,
      pref,
      AppSettingsKeys.SENSOR_DIRECT_ENABLED_JSON,
      HarmonySensorService.directSensorIdsToJson(flags.directSensorIds)
    );
    await AppSettingsStore.flush(pref);
  }

  static async saveLocationSentMode(context: common.Context, value: string): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.LOCATION_SENT_MODE, AppSettingsStore.normalizeLocationSentMode(value));
    await AppSettingsStore.flush(pref);
  }

  static async saveSensorUpdateFrequency(context: common.Context, value: string): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_UPDATE_FREQUENCY, AppSettingsStore.normalizeSensorUpdateFrequency(value));
    await AppSettingsStore.flush(pref);
  }

  static async saveLocationHistoryJson(context: common.Context, value: string): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.LOCATION_HISTORY_JSON, value);
    await AppSettingsStore.flush(pref);
  }

  static async saveLocationDiagnosticsJson(context: common.Context, value: string): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.LOCATION_DIAGNOSTICS_JSON, value);
    await AppSettingsStore.flush(pref);
  }

  static async saveLocationGeofenceStatus(context: common.Context, value: string): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.LOCATION_GEOFENCE_STATUS, value);
    await AppSettingsStore.flush(pref);
  }

  static async saveHomeNetwork(
    context: common.Context,
    wifiSsids: string[],
    prioritizeInternal: boolean
  ): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    const settings = HomeNetworkService.settingsFromStored(
      wifiSsids,
      '',
      prioritizeInternal
    );
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.HOME_WIFI_SSIDS_JSON, JSON.stringify(settings.wifiSsids));
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.HOME_NETWORK_NAME, '');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.PRIORITIZE_INTERNAL, settings.prioritizeInternal);
    await AppSettingsStore.flush(pref);
  }

  static async loadHomeNetwork(context: common.Context): Promise<HomeNetworkSettings> {
    const pref = await AppSettingsStore.getPreferences(context);
    const serverId = AppSettingsStore.activeServerId(context);
    return AppSettingsStore.loadHomeNetworkForServer(pref, serverId);
  }

  static async loadServerConnectionPolicySettings(
    context: common.Context,
    serverId: string
  ): Promise<ServerConnectionPolicySettings> {
    const pref = await AppSettingsStore.getPreferences(context);
    const normalizedServerId = AppSettingsStore.normalizeServerId(serverId);
    return {
      externalUrl: AppSettingsValueCodec.stringField(
        await AppSettingsStore.getValue(pref, normalizedServerId, AppSettingsKeys.SERVER_EXTERNAL_URL, '')
      ),
      internalUrl: AppSettingsValueCodec.stringField(
        await AppSettingsStore.getValue(pref, normalizedServerId, AppSettingsKeys.SERVER_INTERNAL_URL, '')
      ),
      secureConnectionChoice: AppSettingsStore.normalizeSecureConnectionChoice(
        await AppSettingsStore.getValue(pref, normalizedServerId, AppSettingsKeys.SECURE_CONNECTION_CHOICE, '')
      ),
      homeNetwork: await AppSettingsStore.loadHomeNetworkForServer(pref, normalizedServerId)
    };
  }

  private static async loadHomeNetworkForServer(
    pref: preferences.Preferences,
    serverId: string
  ): Promise<HomeNetworkSettings> {
    const rawWifiSsidsValue = await AppSettingsStore.getValue(
      pref,
      serverId,
      AppSettingsKeys.HOME_WIFI_SSIDS_JSON,
      AppSettingsStore.MISSING_HOME_WIFI_SSIDS_JSON
    );
    const rawWifiSsids = AppSettingsValueCodec.stringArrayField(
      rawWifiSsidsValue
    );
    const shouldUseLegacyHomeNetworkName = rawWifiSsidsValue === AppSettingsStore.MISSING_HOME_WIFI_SSIDS_JSON;
    const legacyHomeNetworkName = AppSettingsValueCodec.stringField(
      await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.HOME_NETWORK_NAME, '')
    );
    const settings = HomeNetworkService.settingsFromStored(
      rawWifiSsids,
      shouldUseLegacyHomeNetworkName ? legacyHomeNetworkName : '',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.PRIORITIZE_INTERNAL, false))
    );
    if (shouldUseLegacyHomeNetworkName && rawWifiSsids.length === 0 && settings.wifiSsids.length > 0) {
      await AppSettingsStore.putValue(pref, AppSettingsStore.valueKey(serverId, AppSettingsKeys.HOME_WIFI_SSIDS_JSON), JSON.stringify(settings.wifiSsids));
      await AppSettingsStore.flush(pref);
    }
    return settings;
  }

  static async saveCurrentAppStorage(context: common.Context): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SERVER_NAME_OVERRIDE, AppStorage.get<string>('serverNameOverride') ?? '');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SERVER_EXTERNAL_URL, AppStorage.get<string>('serverExternalUrl') ?? '');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SERVER_INTERNAL_URL, AppStorage.get<string>('serverInternalUrl') ?? '');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SECURE_CONNECTION_CHOICE, AppStorage.get<string>('secureConnectionChoice') ?? '');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.HOME_NETWORK_NAME, '');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.TRUST_SERVER, AppStorage.get<boolean>('trustServer') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.APP_LOCK_ENABLED, AppStorage.get<boolean>('appLockEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.APP_LOCK_HOME_BYPASS, AppStorage.get<boolean>('appLockHomeBypass') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SESSION_TIMEOUT, AppStorage.get<string>('sessionTimeout') ?? '0');
    const websocketMode = AppSettingsStore.normalizeWebsocketMode(AppStorage.get<string>('websocketMode') ?? 'system');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.WEBSOCKET_MODE, websocketMode);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_BATTERY_SOC, AppStorage.get<boolean>('sensorBatterySOCEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_CHARGING_STATUS, AppStorage.get<boolean>('sensorChargingStatusEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_PLUGGED_TYPE, AppStorage.get<boolean>('sensorPluggedTypeEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_BEARER_TYPES, AppStorage.get<boolean>('sensorBearerTypesEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_LAST_UPDATE_TRIGGER, AppStorage.get<boolean>('sensorLastUpdateTriggerEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_LOCATION_BACKGROUND, AppStorage.get<boolean>('sensorLocationEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_ZONE_BACKGROUND, AppStorage.get<boolean>('sensorZoneBackgroundEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_ACCURATE_LOCATION, AppStorage.get<boolean>('sensorAccurateLocationEnabled') ?? false);
    await AppSettingsStore.putActiveValue(
      context,
      pref,
      AppSettingsKeys.SENSOR_DIRECT_ENABLED_JSON,
      HarmonySensorService.directSensorIdsToJson(
        HarmonySensorService.directSensorIdsFromJson(AppStorage.get<string>('sensorDirectEnabledJson') ?? '[]')
      )
    );
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.LOCATION_HISTORY_JSON, AppStorage.get<string>('locationHistoryJson') ?? '[]');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.LOCATION_SENT_MODE, AppSettingsStore.normalizeLocationSentMode(AppStorage.get<string>('locationSentMode') ?? 'never'));
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.LOCATION_DIAGNOSTICS_JSON, AppStorage.get<string>('locationDiagnosticsJson') ?? '');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.LOCATION_GEOFENCE_STATUS, AppStorage.get<string>('locationGeofenceStatus') ?? 'not_started');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SENSOR_DEFAULT_MIGRATION_VERSION, AppStorage.get<number>('sensorDefaultMigrationVersion') ?? 4);
    await AppSettingsStore.putActiveValue(
      context,
      pref,
      AppSettingsKeys.SENSOR_UPDATE_FREQUENCY,
      AppSettingsStore.normalizeSensorUpdateFrequency(AppStorage.get<string>('sensorUpdateFrequency') ?? SensorUpdateFrequency.NORMAL)
    );
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.FULL_SCREEN_ENABLED, AppStorage.get<boolean>('fullScreenEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SCREEN_ORIENTATION, AppStorage.get<string>('screenOrientation') ?? 'system');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.KEEP_SCREEN_ON_ENABLED, AppStorage.get<boolean>('keepScreenOnEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.PAGE_ZOOM_LEVEL, AppStorage.get<string>('pageZoomLevel') ?? '100');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.PINCH_TO_ZOOM_ENABLED, AppStorage.get<boolean>('pinchToZoomEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.AUTO_PLAY_VIDEO_ENABLED, AppStorage.get<boolean>('autoPlayVideoEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.ALWAYS_SHOW_FIRST_VIEW, AppStorage.get<boolean>('alwaysShowFirstViewOnAppStartEnabled') ?? false);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.APP_LANGUAGE, AppStorage.get<string>('appLanguage') ?? 'default');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.APP_THEME, AppStorage.get<string>('appTheme') ?? 'light');
    const serviceCardUpdateFrequency = AppSettingsStore.normalizeServiceCardUpdateFrequency(
      AppStorage.get<string>('serviceCardUpdateFrequency') ?? 'default',
      websocketMode
    );
    AppSettingsStore.setAppStorage<string>('serviceCardUpdateFrequency', serviceCardUpdateFrequency);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SERVICE_CARD_UPDATE_FREQUENCY, serviceCardUpdateFrequency);
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.GESTURE_SWIPE_LEFT_TWO, AppStorage.get<string>('gestureSwipeLeftTwoAction') ?? 'none');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.GESTURE_SWIPE_LEFT_THREE, AppStorage.get<string>('gestureSwipeLeftThreeAction') ?? 'none');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.GESTURE_SWIPE_RIGHT_TWO, AppStorage.get<string>('gestureSwipeRightTwoAction') ?? 'none');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.GESTURE_SWIPE_RIGHT_THREE, AppStorage.get<string>('gestureSwipeRightThreeAction') ?? 'none');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.GESTURE_SWIPE_UP_TWO, AppStorage.get<string>('gestureSwipeUpTwoAction') ?? 'none');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.GESTURE_SWIPE_UP_THREE, AppStorage.get<string>('gestureSwipeUpThreeAction') ?? 'none');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.GESTURE_SWIPE_DOWN_TWO, AppStorage.get<string>('gestureSwipeDownTwoAction') ?? 'none');
    await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.GESTURE_SWIPE_DOWN_THREE, AppStorage.get<string>('gestureSwipeDownThreeAction') ?? 'none');
    await AppSettingsStore.flush(pref);
  }

  static async restoreToAppStorage(context: common.Context): Promise<void> {
    const pref = await AppSettingsStore.getPreferences(context);
    const serverId = AppSettingsStore.activeServerId(context);
    AppSettingsStore.setAppStorage<string>(
      'serverNameOverride',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SERVER_NAME_OVERRIDE, ''))
    );
    AppSettingsStore.setAppStorage<string>(
      'serverExternalUrl',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SERVER_EXTERNAL_URL, ''))
    );
    AppSettingsStore.setAppStorage<string>(
      'serverInternalUrl',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SERVER_INTERNAL_URL, ''))
    );
    AppSettingsStore.setAppStorage<string>(
      'secureConnectionChoice',
      AppSettingsStore.normalizeSecureConnectionChoice(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SECURE_CONNECTION_CHOICE, ''))
    );
    AppSettingsStore.setAppStorage<string>(
      'homeNetworkName',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.HOME_NETWORK_NAME, ''))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'trustServer',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.TRUST_SERVER, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'appLockEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.APP_LOCK_ENABLED, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'appLockHomeBypass',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.APP_LOCK_HOME_BYPASS, false))
    );
    AppSettingsStore.setAppStorage<string>(
      'sessionTimeout',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SESSION_TIMEOUT, '0'))
    );
    const websocketMode = AppSettingsStore.normalizeWebsocketMode(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.WEBSOCKET_MODE, 'system'));
    AppSettingsStore.setAppStorage<string>('websocketMode', websocketMode);
    AppSettingsStore.setAppStorage<boolean>(
      'sensorBatterySOCEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_BATTERY_SOC, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'sensorChargingStatusEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_CHARGING_STATUS, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'sensorPluggedTypeEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_PLUGGED_TYPE, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'sensorBearerTypesEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_BEARER_TYPES, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'sensorLastUpdateTriggerEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_LAST_UPDATE_TRIGGER, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'sensorLocationEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_LOCATION_BACKGROUND, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'sensorZoneBackgroundEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_ZONE_BACKGROUND, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'sensorAccurateLocationEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_ACCURATE_LOCATION, false))
    );
    AppSettingsStore.setAppStorage<string>(
      'sensorDirectEnabledJson',
      HarmonySensorService.directSensorIdsToJson(
        HarmonySensorService.directSensorIdsFromJson(
          AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_DIRECT_ENABLED_JSON, '[]'))
        )
      )
    );
    AppSettingsStore.setAppStorage<string>(
      'locationHistoryJson',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.LOCATION_HISTORY_JSON, '[]'))
    );
    AppSettingsStore.setAppStorage<string>(
      'locationSentMode',
      AppSettingsStore.normalizeLocationSentMode(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.LOCATION_SENT_MODE, 'never'))
    );
    AppSettingsStore.setAppStorage<string>(
      'locationDiagnosticsJson',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.LOCATION_DIAGNOSTICS_JSON, ''))
    );
    AppSettingsStore.setAppStorage<string>(
      'locationGeofenceStatus',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.LOCATION_GEOFENCE_STATUS, 'not_started'))
    );
    AppSettingsStore.setAppStorage<number>(
      'sensorDefaultMigrationVersion',
      AppSettingsValueCodec.numberField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_DEFAULT_MIGRATION_VERSION, 4), 4)
    );
    AppSettingsStore.setAppStorage<string>(
      'sensorUpdateFrequency',
      AppSettingsStore.normalizeSensorUpdateFrequency(
        AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SENSOR_UPDATE_FREQUENCY, SensorUpdateFrequency.NORMAL))
      )
    );
    AppSettingsStore.setAppStorage<boolean>(
      'fullScreenEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.FULL_SCREEN_ENABLED, false))
    );
    AppSettingsStore.setAppStorage<string>(
      'screenOrientation',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SCREEN_ORIENTATION, 'system'))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'keepScreenOnEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.KEEP_SCREEN_ON_ENABLED, false))
    );
    AppSettingsStore.setAppStorage<string>(
      'pageZoomLevel',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.PAGE_ZOOM_LEVEL, '100'))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'pinchToZoomEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.PINCH_TO_ZOOM_ENABLED, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'autoPlayVideoEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.AUTO_PLAY_VIDEO_ENABLED, false))
    );
    AppSettingsStore.setAppStorage<boolean>(
      'alwaysShowFirstViewOnAppStartEnabled',
      AppSettingsValueCodec.booleanField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.ALWAYS_SHOW_FIRST_VIEW, false))
    );
    AppSettingsStore.setAppStorage<string>(
      'appLanguage',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.APP_LANGUAGE, 'default'))
    );
    AppSettingsStore.setAppStorage<string>(
      'appTheme',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.APP_THEME, 'light'))
    );
    const storedServiceCardUpdateFrequency = await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.SERVICE_CARD_UPDATE_FREQUENCY, 'default');
    const serviceCardUpdateFrequency = AppSettingsStore.normalizeServiceCardUpdateFrequency(storedServiceCardUpdateFrequency, websocketMode);
    AppSettingsStore.setAppStorage<string>('serviceCardUpdateFrequency', serviceCardUpdateFrequency);
    if (serviceCardUpdateFrequency !== AppSettingsValueCodec.stringField(storedServiceCardUpdateFrequency)) {
      await AppSettingsStore.putActiveValue(context, pref, AppSettingsKeys.SERVICE_CARD_UPDATE_FREQUENCY, serviceCardUpdateFrequency);
      await AppSettingsStore.flush(pref);
    }
    AppSettingsStore.setAppStorage<string>(
      'gestureSwipeLeftTwoAction',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.GESTURE_SWIPE_LEFT_TWO, 'none'))
    );
    AppSettingsStore.setAppStorage<string>(
      'gestureSwipeLeftThreeAction',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.GESTURE_SWIPE_LEFT_THREE, 'none'))
    );
    AppSettingsStore.setAppStorage<string>(
      'gestureSwipeRightTwoAction',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.GESTURE_SWIPE_RIGHT_TWO, 'none'))
    );
    AppSettingsStore.setAppStorage<string>(
      'gestureSwipeRightThreeAction',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.GESTURE_SWIPE_RIGHT_THREE, 'none'))
    );
    AppSettingsStore.setAppStorage<string>(
      'gestureSwipeUpTwoAction',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.GESTURE_SWIPE_UP_TWO, 'none'))
    );
    AppSettingsStore.setAppStorage<string>(
      'gestureSwipeUpThreeAction',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.GESTURE_SWIPE_UP_THREE, 'none'))
    );
    AppSettingsStore.setAppStorage<string>(
      'gestureSwipeDownTwoAction',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.GESTURE_SWIPE_DOWN_TWO, 'none'))
    );
    AppSettingsStore.setAppStorage<string>(
      'gestureSwipeDownThreeAction',
      AppSettingsValueCodec.stringField(await AppSettingsStore.getValue(pref, serverId, AppSettingsKeys.GESTURE_SWIPE_DOWN_THREE, 'none'))
    );
  }

  static async removeServerSettings(context: common.Context, serverId: string): Promise<void> {
    const normalized = serverId.trim().replace(/[^A-Za-z0-9_-]/g, '_');
    if (normalized.length === 0) {
      return;
    }
    const pref = await AppSettingsStore.getPreferences(context);
    for (let i = 0; i < AppSettingsScopedKeys.length; i++) {
      await AppSettingsStore.deleteValue(pref, AppSettingsStore.scopedKey(normalized, AppSettingsScopedKeys[i]));
    }
    await AppSettingsStore.flush(pref);
  }

  private static setAppStorage<T>(key: string, value: T): void {
    if (!AppStorage.set<T>(key, value)) {
      AppStorage.setOrCreate<T>(key, value);
    }
  }

  private static normalizeWebsocketMode(value: preferences.ValueType | string): string {
    return value === 'always' ? 'always' : 'system';
  }

  static normalizeServiceCardUpdateFrequency(value: preferences.ValueType | string, websocketMode: string = 'system'): string {
    if (websocketMode === 'always') {
      return 'default';
    }
    if (value === 'fast' || value === 'normal') {
      return value;
    }
    return 'default';
  }

  static normalizeSensorUpdateFrequency(value: preferences.ValueType | string): string {
    if (typeof value !== 'string') {
      return SensorUpdateFrequency.NORMAL;
    }
    return normalizeSensorUpdateFrequency(value);
  }

  private static normalizeSecureConnectionChoice(value: preferences.ValueType | string): string {
    if (value === 'most' || value === 'less') {
      return value;
    }
    return '';
  }

  private static normalizeLocationSentMode(value: preferences.ValueType | string): string {
    if (value === 'exact' || value === 'zone') {
      return value;
    }
    return 'never';
  }

  private static activeServerId(context: common.Context): string {
    try {
      return AppSettingsStore.normalizeServerId(ServerInstanceStore.loadRuntimeSync(context).activeServerId);
    } catch (_) {
      return '';
    }
  }

  private static normalizeServerId(serverId: string): string {
    return serverId.trim().replace(/[^A-Za-z0-9_-]/g, '_');
  }

  private static valueKey(serverId: string, key: string): string {
    return serverId.length > 0 ? AppSettingsStore.scopedKey(serverId, key) : key;
  }

  private static scopedKey(serverId: string, key: string): string {
    return `server_${serverId}_${key}`;
  }

  private static async getPreferences(context: common.Context): Promise<preferences.Preferences> {
    try {
      return await preferences.getPreferences(context, AppSettingsKeys.PREFERENCES_NAME);
    } catch (error) {
      throw AppSettingsStore.errorFrom(error);
    }
  }

  private static async getValue(
    pref: preferences.Preferences,
    serverId: string,
    key: string,
    defaultValue: preferences.ValueType
  ): Promise<preferences.ValueType> {
    try {
      if (serverId.length === 0) {
        return await pref.get(key, defaultValue);
      }
      return await pref.get(AppSettingsStore.valueKey(serverId, key), defaultValue);
    } catch (error) {
      throw AppSettingsStore.errorFrom(error);
    }
  }

  private static async putValue(
    pref: preferences.Preferences,
    key: string,
    value: preferences.ValueType
  ): Promise<void> {
    try {
      await pref.put(key, value);
    } catch (error) {
      throw AppSettingsStore.errorFrom(error);
    }
  }

  private static async deleteValue(pref: preferences.Preferences, key: string): Promise<void> {
    try {
      await pref.delete(key);
    } catch (error) {
      throw AppSettingsStore.errorFrom(error);
    }
  }

  private static async flush(pref: preferences.Preferences): Promise<void> {
    try {
      await pref.flush();
    } catch (error) {
      throw AppSettingsStore.errorFrom(error);
    }
  }

  private static async putActiveValue(
    context: common.Context,
    pref: preferences.Preferences,
    key: string,
    value: preferences.ValueType
  ): Promise<void> {
    const serverId = AppSettingsStore.activeServerId(context);
    if (serverId.length === 0) {
      await AppSettingsStore.putValue(pref, key, value);
      return;
    }
    await AppSettingsStore.putValue(pref, AppSettingsStore.scopedKey(serverId, key), value);
  }

  private static async deleteActiveValue(
    context: common.Context,
    pref: preferences.Preferences,
    key: string
  ): Promise<void> {
    const serverId = AppSettingsStore.activeServerId(context);
    if (serverId.length === 0) {
      await AppSettingsStore.deleteValue(pref, key);
      return;
    }
    await AppSettingsStore.deleteValue(pref, AppSettingsStore.scopedKey(serverId, key));
  }

  private static errorFrom(error: Error): Error {
    return error;
  }
}
