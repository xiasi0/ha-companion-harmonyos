import common from '@ohos.app.ability.common';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { HarmonySensorService, SensorPreferenceSnapshot } from '../../services/HarmonySensorService';
import {
  HarmonyLocationService,
  HarmonyLocationSnapshot,
  HarmonyLocationZone
} from '../../services/HarmonyLocationService';
import { HarmonySensorSyncResult } from '../../services/HarmonySensorModels';
import { LongRunningTaskService } from '../background/LongRunningTaskService';
import { LocationSensorCoordinator } from '../sensors/LocationSensorCoordinator';
import { ServerManager } from '../../services/ServerManager';
import { AppSettingsStore } from '../../services/AppSettingsStore';
import { SensorRuntimeFlags, SensorRuntimePresenter } from '../sensors/SensorRuntimePresenter';

interface LocationRuntimeSnapshot {
  baseUrl: string;
  webhookId: string;
  cloudhookUrl: string;
  registered: boolean;
  flags: SensorRuntimeFlags;
  locationHistoryJson: string;
  locationSentMode: string;
  locationGeofenceStatus: string;
}

export class HaLocationRuntimeService {
  private static readonly locationService: HarmonyLocationService = new HarmonyLocationService();
  private static context: common.Context | undefined = undefined;
  private static latestLocation: HarmonyLocationSnapshot | undefined = undefined;
  private static locationEnabled = false;
  private static zones: HarmonyLocationZone[] = [];
  private static currentZoneName = '';
  private static running = false;
  private static zonesRefreshing = false;
  private static syncing = false;
  private static pendingSyncReason = '';

  static ensureRunning(context: common.Context, reason: string = 'location_runtime_ensure'): void {
    HaLocationRuntimeService.context = context;
    const snapshot = HaLocationRuntimeService.snapshot();
    if (!snapshot.registered || !HaLocationRuntimeService.shouldUseBackgroundRuntime(snapshot)) {
      HaLocationRuntimeService.stop();
      HaLocationRuntimeService.syncSensors(reason);
      return;
    }

    LongRunningTaskService.ensureLocationActive(context as common.UIAbilityContext).catch((): void => {});
    HaLocationRuntimeService.locationEnabled = HaLocationRuntimeService.locationService.getLocationEnabled();
    HaLocationRuntimeService.startEnabledWatch();
    HaLocationRuntimeService.startLocationWatch();
    HaLocationRuntimeService.refreshCurrentLocation(reason);
  }

  static refreshOnce(context: common.Context, reason: string = 'location_background_work'): void {
    HaLocationRuntimeService.context = context;
    const snapshot = HaLocationRuntimeService.snapshot();
    if (!snapshot.registered || !HaLocationRuntimeService.shouldUseBackgroundRuntime(snapshot)) {
      return;
    }
    HaLocationRuntimeService.locationEnabled = HaLocationRuntimeService.locationService.getLocationEnabled();
    HaLocationRuntimeService.refreshCurrentLocation(reason);
  }

  static stop(): void {
    const context = HaLocationRuntimeService.context;
    HaLocationRuntimeService.running = false;
    HaLocationRuntimeService.locationService.stopLocationWatch();
    HaLocationRuntimeService.locationService.stopLocationEnabledWatch();
    HaLocationRuntimeService.locationService.stopGeofences().catch((): void => {});
    if (context) {
      LongRunningTaskService.stopLocation(context as common.UIAbilityContext).catch((): void => {});
    }
    HaLocationRuntimeService.setLocationGeofenceStatus('stopped');
  }

  static setLatestLocation(snapshot: HarmonyLocationSnapshot | undefined, zoneName: string): void {
    HaLocationRuntimeService.latestLocation = snapshot;
    HaLocationRuntimeService.currentZoneName = zoneName;
  }

  static setLocationEnabled(enabled: boolean): void {
    HaLocationRuntimeService.locationEnabled = enabled;
  }

  static locationRuntimeActive(): boolean {
    return HaLocationRuntimeService.running;
  }

  private static shouldUseBackgroundRuntime(snapshot: LocationRuntimeSnapshot): boolean {
    return snapshot.flags.locationBackgroundEnabled &&
      snapshot.locationSentMode === 'exact' &&
      snapshot.flags.accurateLocationEnabled;
  }

  private static startEnabledWatch(): void {
    HaLocationRuntimeService.locationService.startLocationEnabledWatch((enabled: boolean): void => {
      HaLocationRuntimeService.locationEnabled = enabled;
      HaLocationRuntimeService.syncSensors('location_enabled_changed');
    });
  }

  private static startLocationWatch(): void {
    HaLocationRuntimeService.running = true;
    HaLocationRuntimeService.locationService.startLocationWatch((snapshot: HarmonyLocationSnapshot): void => {
      HaLocationRuntimeService.handleLocationSnapshot(snapshot, 'location_changed');
    });
  }

  private static refreshCurrentLocation(reason: string): void {
    HaLocationRuntimeService.locationService.getCurrentLocation()
      .then((snapshot: HarmonyLocationSnapshot | undefined): void => {
        if (snapshot) {
          HaLocationRuntimeService.handleLocationSnapshot(snapshot, reason);
          return;
        }
        HaLocationRuntimeService.recordDiagnostics(reason, 'update_location_skipped_no_location');
      })
      .catch((err: Error | string | number | boolean | Object): void => {
        HaLocationRuntimeService.recordDiagnostics(reason, `location_refresh_error:${HaLocationRuntimeService.stringifyError(err)}`);
      });
  }

  private static handleLocationSnapshot(snapshot: HarmonyLocationSnapshot, reason: string): void {
    HaLocationRuntimeService.latestLocation = snapshot;
    HaLocationRuntimeService.currentZoneName = LocationSensorCoordinator.currentZoneName(
      snapshot,
      HaLocationRuntimeService.zones
    );
    HaLocationRuntimeService.appendHistory(snapshot, reason, 'pending');
    if (HaLocationRuntimeService.zones.length === 0) {
      HaLocationRuntimeService.refreshZones(true);
    }
    HaLocationRuntimeService.syncSensors(reason);
  }

  private static refreshZones(syncAfterRefresh: boolean): void {
    const snapshot = HaLocationRuntimeService.snapshot();
    if (!snapshot.registered || HaLocationRuntimeService.zonesRefreshing) {
      return;
    }
    HaLocationRuntimeService.zonesRefreshing = true;
    HaLocationRuntimeService.resolveAllowedBaseUrl()
      .then((baseUrl: string): Promise<HarmonyLocationZone[]> => {
        if (baseUrl.length === 0) {
          return Promise.resolve([]);
        }
        return HarmonySensorService.fetchZones(baseUrl, snapshot.webhookId, snapshot.cloudhookUrl);
      })
      .then((zones: HarmonyLocationZone[]): void => {
        HaLocationRuntimeService.zones = zones;
        const location = HaLocationRuntimeService.latestLocation;
        if (location) {
          HaLocationRuntimeService.currentZoneName = LocationSensorCoordinator.currentZoneName(location, zones);
        }
        if (syncAfterRefresh) {
          HaLocationRuntimeService.syncSensors('zones_refreshed');
        }
      })
      .catch((): void => {})
      .finally((): void => {
        HaLocationRuntimeService.zonesRefreshing = false;
      });
  }

  private static syncSensors(reason: string): void {
    if (AppStorage.get<string>('lastUpdateTrigger') !== reason) {
      AppStorage.setOrCreate<string>('lastUpdateTrigger', reason);
    }
    const snapshot = HaLocationRuntimeService.snapshot();
    if (!snapshot.registered) {
      return;
    }
    if (HaLocationRuntimeService.syncing) {
      HaLocationRuntimeService.pendingSyncReason = reason;
      return;
    }
    HaLocationRuntimeService.syncing = true;
    const preferences = SensorRuntimePresenter.preferences(snapshot.flags);
    const activePreferences: SensorPreferenceSnapshot = {
      batterySOCEnabled: preferences.batterySOCEnabled,
      chargingStatusEnabled: preferences.chargingStatusEnabled,
      pluggedTypeEnabled: preferences.pluggedTypeEnabled,
      bearerTypesEnabled: preferences.bearerTypesEnabled,
      lastUpdateTriggerEnabled: preferences.lastUpdateTriggerEnabled,
      locationBackgroundEnabled: preferences.locationBackgroundEnabled && HaLocationRuntimeService.running,
      zoneBackgroundEnabled: false,
      accurateLocationEnabled: preferences.accurateLocationEnabled,
      directSensorIds: preferences.directSensorIds
    };

    HaLocationRuntimeService.resolveAllowedBaseUrl().then((baseUrl: string) => {
      if (baseUrl.length === 0) {
        const result: HarmonySensorSyncResult = {
          registeredCount: 0,
          updatedCount: 0,
          locationUpdated: false,
          locationSummary: 'blocked_by_connection_policy'
        };
        return Promise.resolve(result);
      }
      return HarmonySensorService.syncPublicSensors(
        baseUrl,
        snapshot.webhookId,
        snapshot.cloudhookUrl,
        activePreferences,
        HaLocationRuntimeService.latestLocation,
        HaLocationRuntimeService.locationEnabled,
        HaLocationRuntimeService.currentZoneName,
        SensorRuntimePresenter.locationSentMode(snapshot.locationSentMode),
        HaLocationRuntimeService.shouldSendLocationUpdate(reason),
        reason,
        HaLocationRuntimeService.context
      );
    }).then((result): void => {
      if (LocationSensorCoordinator.shouldRecordDiagnostics(reason, result.locationSummary)) {
        HaLocationRuntimeService.recordDiagnostics(reason, result.locationSummary);
      }
    }).catch((err: Error | string | number | boolean | Object | ArrayBuffer): void => {
      if (LocationSensorCoordinator.isLocationReason(reason)) {
        HaLocationRuntimeService.recordDiagnostics(reason, `error:${HaLocationRuntimeService.stringifyError(err)}`);
      }
    }).finally((): void => {
      HaLocationRuntimeService.syncing = false;
      if (HaLocationRuntimeService.pendingSyncReason.length > 0) {
        const pendingReason = HaLocationRuntimeService.pendingSyncReason;
        HaLocationRuntimeService.pendingSyncReason = '';
        HaLocationRuntimeService.syncSensors(pendingReason);
      }
    });
  }

  private static appendHistory(snapshot: HarmonyLocationSnapshot, trigger: string, result: string): void {
    HaLocationRuntimeService.setLocationHistoryJson(LocationSensorCoordinator.appendHistory(
      AppStorage.get<string>('locationHistoryJson') ?? '[]',
      snapshot,
      trigger,
      HaLocationRuntimeService.currentZoneName,
      result
    ));
  }

  private static recordDiagnostics(trigger: string, result: string): void {
    const diagnostics = LocationSensorCoordinator.recordDiagnostics({
      historyJson: AppStorage.get<string>('locationHistoryJson') ?? '[]',
      snapshot: HaLocationRuntimeService.latestLocation,
      zoneName: HaLocationRuntimeService.currentZoneName,
      trigger,
      sentMode: SensorRuntimePresenter.locationSentMode(AppStorage.get<string>('locationSentMode') ?? 'never'),
      geofenceStatus: AppStorage.get<string>('locationGeofenceStatus') ?? 'not_started',
      result
    });
    HaLocationRuntimeService.setLocationDiagnosticsJson(diagnostics.summary);
    if (diagnostics.historyChanged) {
      HaLocationRuntimeService.setLocationHistoryJson(diagnostics.historyJson);
    }
  }

  private static setLocationHistoryJson(value: string): void {
    if (AppStorage.get<string>('locationHistoryJson') === value) {
      return;
    }
    AppStorage.setOrCreate<string>('locationHistoryJson', value);
    const context = HaLocationRuntimeService.context;
    if (context) {
      AppSettingsStore.saveLocationHistoryJson(context, value).catch((): void => {});
    }
  }

  private static setLocationDiagnosticsJson(value: string): void {
    if (AppStorage.get<string>('locationDiagnosticsJson') === value) {
      return;
    }
    AppStorage.setOrCreate<string>('locationDiagnosticsJson', value);
    const context = HaLocationRuntimeService.context;
    if (context) {
      AppSettingsStore.saveLocationDiagnosticsJson(context, value).catch((): void => {});
    }
  }

  private static setLocationGeofenceStatus(value: string): void {
    if (AppStorage.get<string>('locationGeofenceStatus') === value) {
      return;
    }
    AppStorage.setOrCreate<string>('locationGeofenceStatus', value);
    const context = HaLocationRuntimeService.context;
    if (context) {
      AppSettingsStore.saveLocationGeofenceStatus(context, value).catch((): void => {});
    }
  }

  private static snapshot(): LocationRuntimeSnapshot {
    const flags: SensorRuntimeFlags = {
      batterySOCEnabled: AppStorage.get<boolean>('sensorBatterySOCEnabled') ?? false,
      chargingStatusEnabled: AppStorage.get<boolean>('sensorChargingStatusEnabled') ?? false,
      pluggedTypeEnabled: AppStorage.get<boolean>('sensorPluggedTypeEnabled') ?? false,
      bearerTypesEnabled: AppStorage.get<boolean>('sensorBearerTypesEnabled') ?? false,
      lastUpdateTriggerEnabled: AppStorage.get<boolean>('sensorLastUpdateTriggerEnabled') ?? false,
      locationBackgroundEnabled: AppStorage.get<boolean>('sensorLocationEnabled') ?? false,
      zoneBackgroundEnabled: AppStorage.get<boolean>('sensorZoneBackgroundEnabled') ?? false,
      accurateLocationEnabled: AppStorage.get<boolean>('sensorAccurateLocationEnabled') ?? false,
      directSensorIds: SensorRuntimePresenter.directSensorIdsFromJson(AppStorage.get<string>('sensorDirectEnabledJson') ?? '[]')
    };
    const baseUrl = AppStorage.get<string>('haBaseUrl') ?? '';
    const webhookId = AppStorage.get<string>('haWebhookId') ?? '';
    return {
      baseUrl,
      webhookId,
      cloudhookUrl: AppStorage.get<string>('haCloudhookUrl') ?? '',
      registered: baseUrl.trim().length > 0 && webhookId.trim().length > 0,
      flags,
      locationHistoryJson: AppStorage.get<string>('locationHistoryJson') ?? '[]',
      locationSentMode: AppStorage.get<string>('locationSentMode') ?? 'never',
      locationGeofenceStatus: AppStorage.get<string>('locationGeofenceStatus') ?? 'not_started'
    };
  }

  private static async resolveAllowedBaseUrl(): Promise<string> {
    const context = HaLocationRuntimeService.context;
    if (!context) {
      return '';
    }
    const serverId = ServerManager.getActiveServerIdSync(context);
    if (serverId.length === 0) {
      return '';
    }
    const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, serverId);
    return policy.allowed ? policy.baseUrl : '';
  }

  private static shouldSendLocationUpdate(reason: string): boolean {
    if (!HaLocationRuntimeService.locationEnabled) {
      return false;
    }
    if (!HaLocationRuntimeService.latestLocation) {
      return false;
    }
    return LocationSensorCoordinator.shouldSendLocationUpdate(reason);
  }

  private static stringifyError(err: Error | string | number | boolean | Object | ArrayBuffer): string {
    if (err instanceof Error) {
      return err.message ? `${err.name}: ${err.message}` : err.name;
    }
    try {
      return JSON.stringify(err);
    } catch (_) {
      return String(err);
    }
  }
}
