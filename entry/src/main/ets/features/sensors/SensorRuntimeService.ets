// Coordinates sensor preferences, permissions, and Home Assistant sensor publishing.
// UI hosts call this layer instead of directly invoking HarmonySensorService.
import common from '@ohos.app.ability.common';
import batteryInfo from '@ohos.batteryInfo';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import type { Permissions } from '@ohos.abilityAccessCtrl';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { HarmonyLocationSentMode, HarmonySensorService, SensorPreferenceSnapshot } from '../../services/HarmonySensorService';
import { NetworkService } from '../../services/NetworkService';
import { ServerManager } from '../../services/ServerManager';
import { Localization } from '../../shared/i18n/Localization';
import {
  HarmonyGeofenceStatus,
  HarmonyGeofenceTransition,
  HarmonyLocationService,
  HarmonyLocationSnapshot,
  HarmonyLocationZone
} from '../../services/HarmonyLocationService';
import { HarmonySensorSyncResult, WebhookResult } from '../../services/HarmonySensorModels';
import { HaLocationRuntimeService } from '../location/HaLocationRuntimeService';
import { LocationSensorCoordinator } from './LocationSensorCoordinator';
import { SensorGroup, SensorUpdateFrequency } from './SensorModels';
import { SensorRuntimeFlags, SensorRuntimePresenter } from './SensorRuntimePresenter';

const HARDWARE_SENSOR_SYNC_MIN_INTERVAL_MS: number = 15000;
const MULTIMODAL_SENSOR_SYNC_MIN_INTERVAL_MS: number = 5000;

export interface SensorRuntimeSnapshot {
  baseUrl: string;
  webhookId: string;
  cloudhookUrl: string;
  registered: boolean;
  flags: SensorRuntimeFlags;
  locationHistoryJson: string;
  locationSentMode: string;
  locationDiagnosticsJson: string;
  locationGeofenceStatus: string;
  sensorUpdateFrequency: string;
}

export interface SensorRuntimeCallbacks {
  context: () => common.Context;
  snapshot: () => SensorRuntimeSnapshot;
  applyFlags: (flags: SensorRuntimeFlags) => void;
  setLocationHistoryJson: (value: string) => void;
  setLocationSentMode: (value: string) => void;
  setLocationDiagnosticsJson: (value: string) => void;
  setLocationGeofenceStatus: (value: string) => void;
  setMessage: (value: string) => void;
  bumpSwitchRevision: () => void;
  stringifyError: (err: Error | string | number | boolean | Object | ArrayBuffer) => string;
}

export class SensorRuntimeService {
  private readonly locationService: HarmonyLocationService = new HarmonyLocationService();
  private latestLocationSnapshot: HarmonyLocationSnapshot | undefined = undefined;
  private latestLocationEnabled: boolean = false;
  private locationZones: HarmonyLocationZone[] = [];
  private currentLocationZoneName: string = '';
  private locationZonesRefreshing: boolean = false;
  private geofenceRefreshing: boolean = false;
  private lastLocationRefreshAt: number = 0;
  private publicSensorSyncing: boolean = false;
  private publicSensorSyncPending: boolean = false;
  private pendingPublicSensorSyncReason: string = 'manual_sync';
  private backgroundLocationPermissionPending: boolean = false;
  private deviceTrackerClearKey: string = '';
  private periodicSensorTimer: number = -1;
  private hardwareSensorSyncTimer: number = -1;
  private multimodalSensorSyncTimer: number = -1;
  private lastHardwareSensorSyncAt: number = 0;
  private lastMultimodalSensorSyncAt: number = 0;

  static migratedFlags(): SensorRuntimeFlags {
    return {
      batterySOCEnabled: false,
      chargingStatusEnabled: false,
      pluggedTypeEnabled: false,
      bearerTypesEnabled: false,
      lastUpdateTriggerEnabled: false,
      locationBackgroundEnabled: false,
      zoneBackgroundEnabled: false,
      accurateLocationEnabled: false,
      directSensorIds: []
    };
  }

  startLocationSensorsIfNeeded(callbacks: SensorRuntimeCallbacks): void {
    HaLocationRuntimeService.ensureRunning(callbacks.context(), 'location_runtime_start');
    this.latestLocationEnabled = this.locationService.getLocationEnabled();
    this.locationService.startLocationEnabledWatch((enabled: boolean): void => {
      this.latestLocationEnabled = enabled;
      HaLocationRuntimeService.setLocationEnabled(enabled);
      this.syncPublicSensors('location_enabled_changed', callbacks);
    });
    if (!this.needsForegroundLocation(callbacks.snapshot().flags)) {
      return;
    }
    this.locationService.startLocationWatch((snapshot: HarmonyLocationSnapshot): void => {
      this.handleLocationSnapshot(snapshot, 'location_changed', callbacks);
    });
    this.locationService.getCurrentLocation()
      .then((snapshot: HarmonyLocationSnapshot | undefined): void => {
        if (snapshot) {
          this.handleLocationSnapshot(snapshot, 'location_current', callbacks);
        }
      })
      .catch((): void => {});
  }

  stop(): void {
    this.stopPeriodicSensorUpdates();
    this.stopRealtimeSensorSyncRetries();
    this.locationService.stopLocationWatch();
    this.locationService.stopLocationEnabledWatch();
    this.locationService.stopGeofences().catch((): void => {});
  }

  reset(): void {
    this.stopPeriodicSensorUpdates();
    this.latestLocationSnapshot = undefined;
    this.latestLocationEnabled = this.locationService.getLocationEnabled();
    this.locationZones = [];
    this.currentLocationZoneName = '';
    this.stopRealtimeSensorSyncRetries();
  }

  requestLocationPermissionAndEnable(
    reason: string,
    callbacks: SensorRuntimeCallbacks,
    onFinished?: () => void
  ): void {
    this.locationService.requestPreciseLocationPermission(callbacks.context())
      .then((granted: boolean): void => {
        if (!granted) {
          this.disableLocationFlags(callbacks);
          callbacks.setMessage(Localization.t('sensor_location_permission_denied'));
          callbacks.bumpSwitchRevision();
          onFinished?.();
          return;
        }
        const flags = callbacks.snapshot().flags;
        callbacks.applyFlags({
          batterySOCEnabled: flags.batterySOCEnabled,
          chargingStatusEnabled: flags.chargingStatusEnabled,
          pluggedTypeEnabled: flags.pluggedTypeEnabled,
          bearerTypesEnabled: flags.bearerTypesEnabled,
          lastUpdateTriggerEnabled: flags.lastUpdateTriggerEnabled,
          locationBackgroundEnabled: true,
          zoneBackgroundEnabled: false,
          accurateLocationEnabled: true,
          directSensorIds: flags.directSensorIds
        });
        this.latestLocationEnabled = this.locationService.getLocationEnabled();
        this.startLocationSensorsIfNeeded(callbacks);
        this.refreshLocationZones(false, callbacks);
        HaLocationRuntimeService.ensureRunning(callbacks.context(), reason);
        this.syncCurrentLocation(reason, callbacks, onFinished);
      })
      .catch((): void => {
        this.disableLocationFlags(callbacks);
        callbacks.setMessage(Localization.t('sensor_location_permission_failed'));
        callbacks.bumpSwitchRevision();
        onFinished?.();
      });
  }

  preferences(flags: SensorRuntimeFlags): SensorPreferenceSnapshot {
    return SensorRuntimePresenter.preferences(flags);
  }

  locationSentMode(value: string): HarmonyLocationSentMode {
    return SensorRuntimePresenter.locationSentMode(value);
  }

  setLocationSentMode(value: string, callbacks: SensorRuntimeCallbacks): void {
    if (value === 'zone' || value === 'never' || value === 'exact') {
      callbacks.setLocationSentMode(value);
      this.syncPublicSensors('location_sent_mode_changed', callbacks);
    }
  }

  setLocationSharingMode(value: string, callbacks: SensorRuntimeCallbacks): void {
    if (value === 'never') {
      this.clearDeviceTrackerLocation('location_sharing_disabled', callbacks);
      const flags = callbacks.snapshot().flags;
      callbacks.setLocationSentMode('never');
      callbacks.applyFlags({
        batterySOCEnabled: flags.batterySOCEnabled,
        chargingStatusEnabled: flags.chargingStatusEnabled,
        pluggedTypeEnabled: flags.pluggedTypeEnabled,
        bearerTypesEnabled: flags.bearerTypesEnabled,
        lastUpdateTriggerEnabled: flags.lastUpdateTriggerEnabled,
        locationBackgroundEnabled: false,
        zoneBackgroundEnabled: false,
        accurateLocationEnabled: false,
        directSensorIds: flags.directSensorIds
      });
      HaLocationRuntimeService.stop();
      this.stopLocationRuntimeIfUnused(callbacks);
      callbacks.bumpSwitchRevision();
      this.syncPublicSensors('location_sent_mode_changed', callbacks);
      return;
    }
    if (value !== 'zone' && value !== 'exact') {
      return;
    }
    const permissionRequest = value === 'zone'
      ? this.locationService.requestApproximateLocationPermission(callbacks.context())
      : this.locationService.requestPreciseLocationPermission(callbacks.context());
    permissionRequest
      .then((granted: boolean): void => {
        if (!granted) {
          const flags = callbacks.snapshot().flags;
          callbacks.setMessage(Localization.t('sensor_location_sharing_denied'));
          callbacks.setLocationSentMode('never');
          callbacks.applyFlags({
            batterySOCEnabled: flags.batterySOCEnabled,
            chargingStatusEnabled: flags.chargingStatusEnabled,
            pluggedTypeEnabled: flags.pluggedTypeEnabled,
            bearerTypesEnabled: flags.bearerTypesEnabled,
            lastUpdateTriggerEnabled: flags.lastUpdateTriggerEnabled,
            locationBackgroundEnabled: flags.locationBackgroundEnabled,
            zoneBackgroundEnabled: false,
            accurateLocationEnabled: false,
            directSensorIds: flags.directSensorIds
          });
          callbacks.bumpSwitchRevision();
          HaLocationRuntimeService.stop();
          this.stopLocationRuntimeIfUnused(callbacks);
          this.syncPublicSensors('location_sent_mode_changed', callbacks);
          return;
        }
        const flags = callbacks.snapshot().flags;
        callbacks.setLocationSentMode(value);
        callbacks.applyFlags({
          batterySOCEnabled: flags.batterySOCEnabled,
          chargingStatusEnabled: flags.chargingStatusEnabled,
          pluggedTypeEnabled: flags.pluggedTypeEnabled,
          bearerTypesEnabled: flags.bearerTypesEnabled,
          lastUpdateTriggerEnabled: flags.lastUpdateTriggerEnabled,
          locationBackgroundEnabled: flags.locationBackgroundEnabled,
          zoneBackgroundEnabled: value === 'zone',
          accurateLocationEnabled: value === 'exact',
          directSensorIds: flags.directSensorIds
        });
        this.latestLocationEnabled = this.locationService.getLocationEnabled();
        this.startLocationSensorsIfNeeded(callbacks);
        this.refreshLocationZones(false, callbacks);
        HaLocationRuntimeService.ensureRunning(callbacks.context(), 'location_sent_mode_changed');
        this.syncCurrentLocation('location_sent_mode_changed', callbacks);
      });
  }

  toggleBackgroundLocationSharing(callbacks: SensorRuntimeCallbacks): void {
    const snapshot = callbacks.snapshot();
    const flags = snapshot.flags;
    const nextEnabled = !flags.locationBackgroundEnabled;
    if (!nextEnabled) {
      callbacks.applyFlags({
        batterySOCEnabled: flags.batterySOCEnabled,
        chargingStatusEnabled: flags.chargingStatusEnabled,
        pluggedTypeEnabled: flags.pluggedTypeEnabled,
        bearerTypesEnabled: flags.bearerTypesEnabled,
        lastUpdateTriggerEnabled: flags.lastUpdateTriggerEnabled,
        locationBackgroundEnabled: false,
        zoneBackgroundEnabled: flags.zoneBackgroundEnabled,
        accurateLocationEnabled: flags.accurateLocationEnabled,
        directSensorIds: flags.directSensorIds
      });
      if (!this.needsForegroundLocation(callbacks.snapshot().flags)) {
        this.stopLocationRuntime(callbacks);
        HaLocationRuntimeService.stop();
      } else if (!this.hasAnyLocationSensorEnabled(callbacks.snapshot().flags)) {
        this.stopLocationGeofences(callbacks);
        HaLocationRuntimeService.stop();
      }
      callbacks.bumpSwitchRevision();
      this.syncPublicSensors('sensor_preferences_changed', callbacks);
      return;
    }
    if (snapshot.locationSentMode !== 'exact' || !flags.accurateLocationEnabled) {
      callbacks.bumpSwitchRevision();
      return;
    }
    this.backgroundLocationPermissionPending = true;
    this.locationService.requestBackgroundLocationPermission(callbacks.context(), true)
      .then((granted: boolean): void => {
        if (!granted) {
          const current = callbacks.snapshot().flags;
          callbacks.applyFlags({
            batterySOCEnabled: current.batterySOCEnabled,
            chargingStatusEnabled: current.chargingStatusEnabled,
            pluggedTypeEnabled: current.pluggedTypeEnabled,
            bearerTypesEnabled: current.bearerTypesEnabled,
            lastUpdateTriggerEnabled: current.lastUpdateTriggerEnabled,
            locationBackgroundEnabled: false,
            zoneBackgroundEnabled: current.zoneBackgroundEnabled,
            accurateLocationEnabled: current.accurateLocationEnabled,
            directSensorIds: current.directSensorIds
          });
          callbacks.setMessage(Localization.t('sensor_background_location_denied'));
          callbacks.bumpSwitchRevision();
          return;
        }
        this.applyBackgroundLocationGranted(callbacks, 'sensor_preferences_changed');
      });
  }

  reconcileBackgroundLocationPermission(callbacks: SensorRuntimeCallbacks): void {
    if (!this.backgroundLocationPermissionPending) {
      return;
    }
    this.backgroundLocationPermissionPending = false;
    if (!this.locationService.hasBackgroundLocationPermission()) {
      callbacks.bumpSwitchRevision();
      return;
    }
    this.applyBackgroundLocationGranted(callbacks, 'background_location_permission_return');
  }

  isSensorEnabled(sensorId: string, flags: SensorRuntimeFlags): boolean {
    return SensorRuntimePresenter.isSensorEnabled(sensorId, flags);
  }

  setSensorEnabled(sensorId: string, enabled: boolean, callbacks: SensorRuntimeCallbacks): boolean {
    const result = SensorRuntimePresenter.withSensorEnabled(sensorId, enabled, callbacks.snapshot().flags);
    if (!result.supported) {
      return false;
    }
    callbacks.applyFlags(result.flags);
    if (result.shouldStopLocationRuntime) {
      this.stopLocationRuntime(callbacks);
    }
    return true;
  }

  setSensorEnabledWithPermission(
    sensorId: string,
    enabled: boolean,
    callbacks: SensorRuntimeCallbacks,
    onChanged: () => void
  ): void {
    if (!enabled) {
      if (this.setSensorEnabled(sensorId, false, callbacks)) {
        onChanged();
      }
      return;
    }
    if (sensorId === 'geocoded_location') {
      this.enableGeocodedLocationSensor(callbacks, onChanged);
      return;
    }
    const permissions = this.requiredDirectSensorPermissions(sensorId);
    if (permissions.length === 0) {
      if (this.setSensorEnabled(sensorId, true, callbacks)) {
        onChanged();
      }
      return;
    }
    this.requestDirectSensorPermissions(callbacks.context(), permissions)
      .then((granted: boolean): void => {
        if (!granted) {
          callbacks.setMessage(Localization.t('sensor_permission_or_pending'));
          callbacks.bumpSwitchRevision();
          return;
        }
        if (this.setSensorEnabled(sensorId, true, callbacks)) {
          onChanged();
        }
      })
      .catch((): void => {
        callbacks.setMessage(Localization.t('sensor_permission_or_pending'));
        callbacks.bumpSwitchRevision();
      });
  }

  refreshLocationZones(syncAfterRefresh: boolean, callbacks: SensorRuntimeCallbacks): void {
    const snapshot = callbacks.snapshot();
    if (!snapshot.registered || this.locationZonesRefreshing) {
      return;
    }
    this.locationZonesRefreshing = true;
    SensorRuntimeService.resolveAllowedBaseUrl(callbacks.context())
      .then((baseUrl: string): Promise<HarmonyLocationZone[]> => {
        if (baseUrl.length === 0) {
          return Promise.resolve([]);
        }
        return HarmonySensorService.fetchZones(baseUrl, snapshot.webhookId, snapshot.cloudhookUrl);
      })
      .then((zones: HarmonyLocationZone[]): void => {
        this.locationZones = zones;
        if (this.latestLocationSnapshot) {
          this.updateCurrentLocationZone(this.latestLocationSnapshot);
        }
        this.refreshLocationGeofences(callbacks);
        if (syncAfterRefresh) {
          this.syncPublicSensors('zones_refreshed', callbacks);
        }
      })
      .catch((): void => {})
      .finally((): void => {
        this.locationZonesRefreshing = false;
      });
  }

  refreshCurrentLocationForDiagnostics(trigger: string, callbacks: SensorRuntimeCallbacks): void {
    if (!this.needsForegroundLocation(callbacks.snapshot().flags)) {
      return;
    }
    const now = Date.now();
    if (now - this.lastLocationRefreshAt < 30000) {
      return;
    }
    this.lastLocationRefreshAt = now;
    this.locationService.getCurrentLocation()
      .then((snapshot: HarmonyLocationSnapshot | undefined): void => {
        if (snapshot) {
          this.handleLocationSnapshot(snapshot, trigger, callbacks);
        } else {
          this.recordLocationDiagnostics(trigger, 'update_location_skipped_no_location', callbacks);
        }
      })
      .catch((err: Error | string | number | boolean | Object): void => {
        this.recordLocationDiagnostics(trigger, `location_refresh_error:${callbacks.stringifyError(err)}`, callbacks);
      });
  }

  refreshPeriodicSensorTimer(callbacks: SensorRuntimeCallbacks): void {
    this.stopPeriodicSensorUpdates();
    const snapshot = callbacks.snapshot();
    if (!snapshot.registered || !this.hasAnyEnabledSensor(snapshot.flags)) {
      return;
    }
    const delayMs = this.periodicSensorDelayMs(snapshot.sensorUpdateFrequency);
    this.periodicSensorTimer = setTimeout((): void => {
      this.periodicSensorTimer = -1;
      this.syncPublicSensors('sensor_periodic', callbacks);
    }, delayMs);
  }

  syncPublicSensors(reason: string, callbacks: SensorRuntimeCallbacks): void {
    const snapshot = callbacks.snapshot();
    if (!snapshot.registered) {
      return;
    }
    if (this.publicSensorSyncing) {
      if (this.isRealtimeSensorSyncThrottled(reason)) {
        this.scheduleRealtimeSensorSyncRetry(reason, callbacks);
      } else {
        this.publicSensorSyncPending = true;
        this.pendingPublicSensorSyncReason = reason;
      }
      return;
    }
    if (this.isRealtimeSensorSyncThrottled(reason)) {
      this.scheduleRealtimeSensorSyncRetry(reason, callbacks);
      return;
    }
    this.markRealtimeSensorSyncStarted(reason);
    if (AppStorage.get<string>('lastUpdateTrigger') !== reason) {
      AppStorage.setOrCreate<string>('lastUpdateTrigger', reason);
    }
    this.refreshPeriodicSensorTimer(callbacks);
    this.reconcileDeviceTrackerLocationState(reason, snapshot, callbacks);
    this.publicSensorSyncing = true;
    SensorRuntimeService.resolveAllowedBaseUrl(callbacks.context()).then((baseUrl: string) => {
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
        SensorRuntimePresenter.preferences(snapshot.flags),
        this.latestLocationSnapshot,
        this.latestLocationEnabled,
        this.currentLocationZoneName,
        SensorRuntimePresenter.locationSentMode(snapshot.locationSentMode),
        this.shouldSendLocationUpdate(reason),
        reason
      );
    }).then((result): void => {
      if (LocationSensorCoordinator.shouldRecordDiagnostics(reason, result.locationSummary)) {
        this.recordLocationDiagnostics(reason, result.locationSummary, callbacks);
      }
    }).catch((error: Error | string | number | boolean | Object | ArrayBuffer): void => {
      callbacks.setMessage(callbacks.stringifyError(error));
      if (LocationSensorCoordinator.isLocationReason(reason)) {
        this.recordLocationDiagnostics(reason, `error:${callbacks.stringifyError(error)}`, callbacks);
      }
    }).finally((): void => {
      this.publicSensorSyncing = false;
      if (this.publicSensorSyncPending) {
        const pendingReason = this.pendingPublicSensorSyncReason;
        this.publicSensorSyncPending = false;
        this.pendingPublicSensorSyncReason = 'manual_sync';
        this.syncPublicSensors(pendingReason, callbacks);
      }
    });
  }

  hasAnyLocationSensorEnabled(flags: SensorRuntimeFlags): boolean {
    return SensorRuntimePresenter.hasAnyLocationSensorEnabled(flags);
  }

  needsForegroundLocation(flags: SensorRuntimeFlags): boolean {
    return SensorRuntimePresenter.needsForegroundLocation(flags);
  }

  enabledSensorCount(flags: SensorRuntimeFlags): number {
    return SensorRuntimePresenter.enabledSensorCount(flags);
  }

  sensorGroups(flags: SensorRuntimeFlags): SensorGroup[] {
    return SensorRuntimePresenter.sensorGroups(flags);
  }

  private stopPeriodicSensorUpdates(): void {
    if (this.periodicSensorTimer < 0) {
      return;
    }
    clearTimeout(this.periodicSensorTimer);
    this.periodicSensorTimer = -1;
  }

  private stopRealtimeSensorSyncRetries(): void {
    if (this.hardwareSensorSyncTimer >= 0) {
      clearTimeout(this.hardwareSensorSyncTimer);
      this.hardwareSensorSyncTimer = -1;
    }
    if (this.multimodalSensorSyncTimer >= 0) {
      clearTimeout(this.multimodalSensorSyncTimer);
      this.multimodalSensorSyncTimer = -1;
    }
  }

  private periodicSensorDelayMs(frequency: string): number {
    if (frequency === SensorUpdateFrequency.FAST_ALWAYS) {
      return 60000;
    }
    if (frequency === SensorUpdateFrequency.FAST_WHILE_CHARGING) {
      if (batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.ENABLE ||
        batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.FULL) {
        return 60000;
      }
    }
    return 900000;
  }

  private isRealtimeSensorSyncThrottled(reason: string): boolean {
    const now = Date.now();
    if (reason === 'hardware_sensor_event') {
      return now - this.lastHardwareSensorSyncAt < HARDWARE_SENSOR_SYNC_MIN_INTERVAL_MS;
    }
    if (reason === 'multimodal_motion_event') {
      return now - this.lastMultimodalSensorSyncAt < MULTIMODAL_SENSOR_SYNC_MIN_INTERVAL_MS;
    }
    return false;
  }

  private scheduleRealtimeSensorSyncRetry(reason: string, callbacks: SensorRuntimeCallbacks): void {
    if (reason === 'hardware_sensor_event') {
      if (this.hardwareSensorSyncTimer >= 0) {
        return;
      }
      const delayMs = this.realtimeSensorSyncDelayMs(reason);
      this.hardwareSensorSyncTimer = setTimeout((): void => {
        this.hardwareSensorSyncTimer = -1;
        this.syncPublicSensors(reason, callbacks);
      }, delayMs);
      return;
    }
    if (reason === 'multimodal_motion_event') {
      if (this.multimodalSensorSyncTimer >= 0) {
        return;
      }
      const delayMs = this.realtimeSensorSyncDelayMs(reason);
      this.multimodalSensorSyncTimer = setTimeout((): void => {
        this.multimodalSensorSyncTimer = -1;
        this.syncPublicSensors(reason, callbacks);
      }, delayMs);
    }
  }

  private realtimeSensorSyncDelayMs(reason: string): number {
    const now = Date.now();
    if (reason === 'hardware_sensor_event') {
      return Math.max(HARDWARE_SENSOR_SYNC_MIN_INTERVAL_MS - (now - this.lastHardwareSensorSyncAt), 1);
    }
    if (reason === 'multimodal_motion_event') {
      return Math.max(MULTIMODAL_SENSOR_SYNC_MIN_INTERVAL_MS - (now - this.lastMultimodalSensorSyncAt), 1);
    }
    return 1;
  }

  private markRealtimeSensorSyncStarted(reason: string): void {
    const now = Date.now();
    if (reason === 'hardware_sensor_event') {
      this.lastHardwareSensorSyncAt = now;
    } else if (reason === 'multimodal_motion_event') {
      this.lastMultimodalSensorSyncAt = now;
    }
  }

  private hasAnyEnabledSensor(flags: SensorRuntimeFlags): boolean {
    return SensorRuntimePresenter.enabledSensorCount(flags) > 0;
  }

  private enableGeocodedLocationSensor(callbacks: SensorRuntimeCallbacks, onChanged: () => void): void {
    this.locationService.requestApproximateLocationPermission(callbacks.context())
      .then((granted: boolean): void => {
        if (!granted) {
          callbacks.setMessage(Localization.t('sensor_location_permission_denied'));
          callbacks.bumpSwitchRevision();
          return;
        }
        if (!this.setSensorEnabled('geocoded_location', true, callbacks)) {
          return;
        }
        this.latestLocationEnabled = this.locationService.getLocationEnabled();
        this.startLocationSensorsIfNeeded(callbacks);
        this.syncCurrentLocation('geocoded_location_enabled', callbacks, onChanged);
      })
      .catch((): void => {
        callbacks.setMessage(Localization.t('sensor_location_permission_failed'));
        callbacks.bumpSwitchRevision();
      });
  }

  private requiredDirectSensorPermissions(sensorId: string): Permissions[] {
    if (sensorId === 'bluetooth_state') {
      return ['ohos.permission.ACCESS_BLUETOOTH' as Permissions];
    }
    if (sensorId === 'steps_sensor') {
      return ['ohos.permission.ACTIVITY_MOTION' as Permissions];
    }
    if (sensorId === 'harmony_operating_hand') {
      return ['ohos.permission.ACTIVITY_MOTION' as Permissions];
    }
    if (sensorId === 'harmony_holding_hand') {
      return ['ohos.permission.DETECT_GESTURE' as Permissions];
    }
    return [];
  }

  private async requestDirectSensorPermissions(
    context: common.Context,
    permissions: Permissions[]
  ): Promise<boolean> {
    const missing: Permissions[] = [];
    for (let i = 0; i < permissions.length; i++) {
      if (!this.hasPermission(permissions[i])) {
        missing.push(permissions[i]);
      }
    }
    if (missing.length === 0) {
      return true;
    }
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, missing);
      if (result.authResults.length < missing.length) {
        return false;
      }
      for (let i = 0; i < missing.length; i++) {
        if (result.authResults[i] !== 0) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  private hasPermission(permission: Permissions): boolean {
    try {
      return abilityAccessCtrl.createAtManager().getSelfPermissionStatus(permission) ===
        abilityAccessCtrl.PermissionStatus.GRANTED;
    } catch (_) {
      return false;
    }
  }

  private disableLocationFlags(callbacks: SensorRuntimeCallbacks): void {
    const flags = callbacks.snapshot().flags;
    callbacks.applyFlags({
      batterySOCEnabled: flags.batterySOCEnabled,
      chargingStatusEnabled: flags.chargingStatusEnabled,
      pluggedTypeEnabled: flags.pluggedTypeEnabled,
      bearerTypesEnabled: flags.bearerTypesEnabled,
      lastUpdateTriggerEnabled: flags.lastUpdateTriggerEnabled,
      locationBackgroundEnabled: false,
      zoneBackgroundEnabled: false,
      accurateLocationEnabled: false,
      directSensorIds: flags.directSensorIds
    });
  }

  private reconcileDeviceTrackerLocationState(
    reason: string,
    snapshot: SensorRuntimeSnapshot,
    callbacks: SensorRuntimeCallbacks
  ): void {
    if (this.hasAnyLocationSensorEnabled(snapshot.flags)) {
      this.deviceTrackerClearKey = '';
      return;
    }
    this.clearDeviceTrackerLocation(reason, callbacks);
  }

  private clearDeviceTrackerLocation(reason: string, callbacks: SensorRuntimeCallbacks): void {
    const snapshot = callbacks.snapshot();
    if (!snapshot.registered) {
      return;
    }
    const clearKey = `${snapshot.baseUrl}|${snapshot.webhookId}`;
    if (this.deviceTrackerClearKey === clearKey) {
      return;
    }
    this.deviceTrackerClearKey = clearKey;
    SensorRuntimeService.resolveAllowedBaseUrl(callbacks.context()).then((baseUrl: string) => {
      if (baseUrl.length === 0) {
        const result: WebhookResult = {
          responseCode: 0,
          body: '',
          failureSummary: 'blocked_by_connection_policy'
        };
        return Promise.resolve(result);
      }
      return HarmonySensorService.clearDeviceTrackerLocation(baseUrl, snapshot.webhookId, snapshot.cloudhookUrl);
    }).then((result): void => {
      this.recordLocationDiagnostics(reason,
        `clear_location:${result.responseCode}:${NetworkService.shortText(result.body)}`, callbacks);
    }).catch((error: Error | string | number | boolean | Object | ArrayBuffer): void => {
      this.deviceTrackerClearKey = '';
      this.recordLocationDiagnostics(reason, `clear_location_error:${callbacks.stringifyError(error)}`, callbacks);
    });
  }

  private applyBackgroundLocationGranted(callbacks: SensorRuntimeCallbacks, reason: string): void {
    this.backgroundLocationPermissionPending = false;
    const current = callbacks.snapshot().flags;
    const sentMode = callbacks.snapshot().locationSentMode;
    callbacks.applyFlags({
      batterySOCEnabled: current.batterySOCEnabled,
      chargingStatusEnabled: current.chargingStatusEnabled,
      pluggedTypeEnabled: current.pluggedTypeEnabled,
      bearerTypesEnabled: current.bearerTypesEnabled,
      lastUpdateTriggerEnabled: current.lastUpdateTriggerEnabled,
      locationBackgroundEnabled: true,
      zoneBackgroundEnabled: sentMode === 'never' ? false : current.zoneBackgroundEnabled,
      accurateLocationEnabled: sentMode === 'never' ? true : current.accurateLocationEnabled,
      directSensorIds: current.directSensorIds
    });
    if (sentMode === 'never') {
      callbacks.setLocationSentMode('exact');
    }
    this.latestLocationEnabled = this.locationService.getLocationEnabled();
    this.startLocationSensorsIfNeeded(callbacks);
    this.refreshLocationZones(false, callbacks);
    HaLocationRuntimeService.ensureRunning(callbacks.context(), reason);
    callbacks.bumpSwitchRevision();
    this.syncPublicSensors('sensor_preferences_changed', callbacks);
  }

  private shouldSendLocationUpdate(reason: string): boolean {
    if (!this.latestLocationEnabled) {
      return false;
    }
    if (!this.latestLocationSnapshot) {
      return false;
    }
    return LocationSensorCoordinator.shouldSendLocationUpdate(reason);
  }

  private syncCurrentLocation(reason: string, callbacks: SensorRuntimeCallbacks, onFinished?: () => void): void {
    this.locationService.getCurrentLocation()
      .then((snapshot: HarmonyLocationSnapshot | undefined): void => {
        if (snapshot) {
          this.handleLocationSnapshot(snapshot, reason, callbacks);
        }
        callbacks.bumpSwitchRevision();
        this.syncPublicSensors(reason, callbacks);
        onFinished?.();
      })
      .catch((): void => {
        callbacks.bumpSwitchRevision();
        this.syncPublicSensors(reason, callbacks);
        onFinished?.();
      });
  }

  private stopLocationRuntime(callbacks: SensorRuntimeCallbacks): void {
    this.locationService.stopLocationWatch();
    this.stopLocationGeofences(callbacks);
    this.latestLocationSnapshot = undefined;
  }

  private stopLocationRuntimeIfUnused(callbacks: SensorRuntimeCallbacks): void {
    if (!this.needsForegroundLocation(callbacks.snapshot().flags)) {
      this.stopLocationRuntime(callbacks);
      return;
    }
    if (!this.hasAnyLocationSensorEnabled(callbacks.snapshot().flags)) {
      this.stopLocationGeofences(callbacks);
    }
  }

  private stopLocationGeofences(callbacks: SensorRuntimeCallbacks): void {
    this.locationService.stopGeofences().catch((): void => {});
    callbacks.setLocationGeofenceStatus('stopped');
    this.currentLocationZoneName = '';
  }

  private handleLocationSnapshot(
    snapshot: HarmonyLocationSnapshot,
    trigger: string,
    callbacks: SensorRuntimeCallbacks
  ): void {
    this.latestLocationSnapshot = snapshot;
    this.updateCurrentLocationZone(snapshot);
    HaLocationRuntimeService.setLatestLocation(snapshot, this.currentLocationZoneName);
    this.appendLocationHistory(snapshot, trigger, 'pending', callbacks);
    if (this.locationZones.length === 0) {
      this.refreshLocationZones(true, callbacks);
    }
    this.syncPublicSensors(trigger, callbacks);
  }

  private refreshLocationGeofences(callbacks: SensorRuntimeCallbacks): void {
    if (!this.hasAnyLocationSensorEnabled(callbacks.snapshot().flags) ||
      this.locationZones.length === 0 ||
      this.geofenceRefreshing) {
      return;
    }
    this.geofenceRefreshing = true;
    this.locationService.refreshGeofences(
      callbacks.context(),
      this.locationZones,
      (transition: HarmonyGeofenceTransition): void => {
        this.handleGeofenceTransition(transition, callbacks);
      }
    ).then((status: HarmonyGeofenceStatus): void => {
      callbacks.setLocationGeofenceStatus(status.summary);
    }).catch((err: Error | string | number | boolean | Object): void => {
      callbacks.setLocationGeofenceStatus(`geofence_error:${callbacks.stringifyError(err)}`);
    }).finally((): void => {
      this.geofenceRefreshing = false;
    });
  }

  private handleGeofenceTransition(
    transition: HarmonyGeofenceTransition,
    callbacks: SensorRuntimeCallbacks
  ): void {
    if (transition.event === 'geofence_enter' || transition.event === 'geofence_dwell') {
      this.currentLocationZoneName = transition.zone.name;
    } else if (transition.event === 'geofence_exit' && this.currentLocationZoneName === transition.zone.name) {
      this.currentLocationZoneName = '';
    }
    this.locationService.getCurrentLocation()
      .then((snapshot: HarmonyLocationSnapshot | undefined): void => {
        if (snapshot) {
          this.latestLocationSnapshot = snapshot;
          this.updateCurrentLocationZone(snapshot);
          this.appendLocationHistory(snapshot, transition.event, 'pending', callbacks);
        }
        this.syncPublicSensors(transition.event, callbacks);
      })
      .catch((): void => {
        this.syncPublicSensors(transition.event, callbacks);
      });
  }

  private updateCurrentLocationZone(snapshot: HarmonyLocationSnapshot): void {
    this.currentLocationZoneName = LocationSensorCoordinator.currentZoneName(snapshot, this.locationZones);
  }

  private appendLocationHistory(
    snapshot: HarmonyLocationSnapshot,
    trigger: string,
    result: string,
    callbacks: SensorRuntimeCallbacks
  ): void {
    callbacks.setLocationHistoryJson(LocationSensorCoordinator.appendHistory(
      callbacks.snapshot().locationHistoryJson,
      snapshot,
      trigger,
      this.currentLocationZoneName,
      result
    ));
  }

  private recordLocationDiagnostics(
    trigger: string,
    result: string,
    callbacks: SensorRuntimeCallbacks
  ): void {
    const diagnostics = LocationSensorCoordinator.recordDiagnostics({
      historyJson: callbacks.snapshot().locationHistoryJson,
      snapshot: this.latestLocationSnapshot,
      zoneName: this.currentLocationZoneName,
      trigger,
      sentMode: SensorRuntimePresenter.locationSentMode(callbacks.snapshot().locationSentMode),
      geofenceStatus: callbacks.snapshot().locationGeofenceStatus,
      result
    });
    callbacks.setLocationDiagnosticsJson(diagnostics.summary);
    if (diagnostics.historyChanged) {
      callbacks.setLocationHistoryJson(diagnostics.historyJson);
    }
  }

  private static async resolveAllowedBaseUrl(context: common.Context): Promise<string> {
    const serverId = ServerManager.getActiveServerIdSync(context);
    if (serverId.length === 0) {
      return '';
    }
    const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, serverId);
    return policy.allowed ? policy.baseUrl : '';
  }

}
