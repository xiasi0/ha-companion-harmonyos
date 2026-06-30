// HarmonyOS location capability wrapper for permission, current location, and history tracking.
// Higher-level sensor flows call this service instead of touching platform location APIs directly.
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import geoLocationManager from '@ohos.geoLocationManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { Permissions } from '@ohos.abilityAccessCtrl';

export interface HarmonyLocationSnapshot {
  latitude: number;
  longitude: number;
  accuracy: number;
  timeStamp: number;
  altitude?: number;
  speed?: number;
  direction?: number;
  altitudeAccuracy?: number;
}

export interface HarmonyLocationZone {
  entityId: string;
  name: string;
  latitude: number;
  longitude: number;
  radius: number;
}

export interface HarmonyLocationHistoryEntry {
  timeStamp: number;
  latitude: number;
  longitude: number;
  accuracy: number;
  trigger: string;
  zoneName: string;
  result: string;
}

export interface HarmonyGeofenceTransition {
  zone: HarmonyLocationZone;
  event: string;
}

export interface HarmonyGeofenceStatus {
  active: boolean;
  summary: string;
  registeredCount: number;
}

const GEOFENCE_EXPIRATION_MS = 24 * 60 * 60 * 1000;
const DOMAIN = 0x0000;
const TAG = 'HALocationService';

interface PermissionRequestError {
  code?: number;
}

export class HarmonyLocationService {
  private locationCallback: ((location: geoLocationManager.Location) => void) | undefined = undefined;
  private enabledCallback: ((enabled: boolean) => void) | undefined = undefined;
  private geofenceIds: number[] = [];

  async requestLocationPermission(context: common.Context): Promise<boolean> {
    return this.requestPreciseLocationPermission(context);
  }

  async requestApproximateLocationPermission(context: common.Context): Promise<boolean> {
    try {
      if (this.hasPermission('ohos.permission.APPROXIMATELY_LOCATION')) {
        return true;
      }
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, ['ohos.permission.APPROXIMATELY_LOCATION']);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (_) {
      return false;
    }
  }

  async requestPreciseLocationPermission(context: common.Context): Promise<boolean> {
    try {
      if (this.hasPermission('ohos.permission.APPROXIMATELY_LOCATION') &&
        this.hasPermission('ohos.permission.LOCATION')) {
        return true;
      }
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, [
        'ohos.permission.APPROXIMATELY_LOCATION',
        'ohos.permission.LOCATION'
      ]);
      return result.authResults.length > 1 && result.authResults[0] === 0 && result.authResults[1] === 0;
    } catch (_) {
      return false;
    }
  }

  async requestBackgroundLocationPermission(context: common.Context, precise: boolean = true): Promise<boolean> {
    try {
      const foregroundGranted = precise
        ? await this.requestPreciseLocationPermission(context)
        : await this.requestApproximateLocationPermission(context);
      if (!foregroundGranted) {
        return false;
      }
      if (!await this.ensureLocationSwitchEnabled(context)) {
        return false;
      }
      if (this.hasPermission('ohos.permission.LOCATION_IN_BACKGROUND')) {
        return true;
      }
      const result = await abilityAccessCtrl.createAtManager().requestPermissionOnSetting(
        context,
        ['ohos.permission.LOCATION_IN_BACKGROUND' as Permissions]
      );
      return result.length > 0 && result[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (err) {
      if ((err as PermissionRequestError).code === 12100011) {
        return true;
      }
      hilog.warn(DOMAIN, TAG, 'Request background location failed. Cause: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  hasBackgroundLocationPermission(): boolean {
    return this.hasPermission('ohos.permission.LOCATION_IN_BACKGROUND');
  }

  private async ensureLocationSwitchEnabled(context: common.Context): Promise<boolean> {
    if (this.getLocationEnabled()) {
      return true;
    }
    try {
      return await abilityAccessCtrl.createAtManager().requestGlobalSwitch(
        context,
        abilityAccessCtrl.SwitchType.LOCATION
      );
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

  startLocationWatch(onChange: (snapshot: HarmonyLocationSnapshot) => void): void {
    if (this.locationCallback) {
      return;
    }
    const request: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.ACCURACY,
      scenario: geoLocationManager.LocationRequestScenario.DAILY_LIFE_SERVICE,
      timeInterval: 30,
      distanceInterval: 25,
      maxAccuracy: 100
    };
    this.locationCallback = (location: geoLocationManager.Location): void => {
      onChange({
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        timeStamp: location.timeStamp,
        altitude: location.altitude,
        speed: location.speed,
        direction: location.direction,
        altitudeAccuracy: location.altitudeAccuracy
      });
    };
    try {
      geoLocationManager.on('locationChange', request, this.locationCallback);
    } catch (_) {
      this.locationCallback = undefined;
    }
  }

  stopLocationWatch(): void {
    if (!this.locationCallback) {
      return;
    }
    const callback = this.locationCallback;
    this.locationCallback = undefined;
    try {
      geoLocationManager.off('locationChange', callback);
    } catch (_) {
    }
  }

  startLocationEnabledWatch(onChange: (enabled: boolean) => void): void {
    if (this.enabledCallback) {
      return;
    }
    this.enabledCallback = (enabled: boolean): void => {
      onChange(enabled);
    };
    try {
      geoLocationManager.on('locationEnabledChange', this.enabledCallback);
    } catch (_) {
      this.enabledCallback = undefined;
    }
  }

  stopLocationEnabledWatch(): void {
    if (!this.enabledCallback) {
      return;
    }
    const callback = this.enabledCallback;
    this.enabledCallback = undefined;
    try {
      geoLocationManager.off('locationEnabledChange', callback);
    } catch (_) {
    }
  }

  async refreshGeofences(
    zones: HarmonyLocationZone[],
    onTransition: (transition: HarmonyGeofenceTransition) => void
  ): Promise<HarmonyGeofenceStatus> {
    await this.stopGeofences();
    if (zones.length === 0) {
      return {
        active: false,
        summary: 'no_zones',
        registeredCount: 0
      };
    }
    let supportedCoordTypes: geoLocationManager.CoordinateSystemType[] = [];
    try {
      supportedCoordTypes = geoLocationManager.getGeofenceSupportedCoordTypes();
    } catch (_) {
      return {
        active: false,
        summary: 'geofence_unsupported',
        registeredCount: 0
      };
    }
    if (!HarmonyLocationService.hasCoordinateType(supportedCoordTypes, geoLocationManager.CoordinateSystemType.WGS84)) {
      return {
        active: false,
        summary: 'wgs84_geofence_unsupported',
        registeredCount: 0
      };
    }
    const maxGeofences = Math.min(zones.length, 100);
    try {
      for (let i = 0; i < maxGeofences; i++) {
        const zone = zones[i];
        const radius = Math.max(zone.radius, 100);
        const request: geoLocationManager.GnssGeofenceRequest = {
          geofence: {
            latitude: zone.latitude,
            longitude: zone.longitude,
            coordinateSystemType: geoLocationManager.CoordinateSystemType.WGS84,
            radius,
            expiration: GEOFENCE_EXPIRATION_MS
          },
          monitorTransitionEvents: [
            geoLocationManager.GeofenceTransitionEvent.GEOFENCE_TRANSITION_EVENT_ENTER,
            geoLocationManager.GeofenceTransitionEvent.GEOFENCE_TRANSITION_EVENT_EXIT,
            geoLocationManager.GeofenceTransitionEvent.GEOFENCE_TRANSITION_EVENT_DWELL
          ],
          geofenceTransitionCallback: (_err: Error, transition: geoLocationManager.GeofenceTransition): void => {
            if (!transition) {
              return;
            }
            onTransition({
              zone,
              event: HarmonyLocationService.geofenceEventName(transition.transitionEvent)
            });
          }
        };
        const geofenceId = await geoLocationManager.addGnssGeofence(request);
        this.geofenceIds.push(geofenceId);
      }
      return {
        active: this.geofenceIds.length > 0,
        summary: `active:${this.geofenceIds.length}`,
        registeredCount: this.geofenceIds.length
      };
    } catch (err) {
      await this.stopGeofences();
      return {
        active: false,
        summary: `geofence_failed:${HarmonyLocationService.stringifyError(err)}`,
        registeredCount: 0
      };
    }
  }

  async stopGeofences(): Promise<void> {
    const ids = this.geofenceIds;
    this.geofenceIds = [];
    for (let i = 0; i < ids.length; i++) {
      try {
        await geoLocationManager.removeGnssGeofence(ids[i]);
      } catch (_) {
      }
    }
  }

  getLocationEnabled(): boolean {
    try {
      return geoLocationManager.isLocationEnabled();
    } catch (_) {
      return false;
    }
  }

  async getCurrentLocation(): Promise<HarmonyLocationSnapshot | undefined> {
    try {
      const location = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.DAILY_LIFE_SERVICE,
        maxAccuracy: 100,
        timeoutMs: 10000
      });
      return {
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
        timeStamp: location.timeStamp,
        altitude: location.altitude,
        speed: location.speed,
        direction: location.direction,
        altitudeAccuracy: location.altitudeAccuracy
      };
    } catch (_) {
      return undefined;
    }
  }

  static findContainingZone(
    snapshot: HarmonyLocationSnapshot | undefined,
    zones: HarmonyLocationZone[]
  ): HarmonyLocationZone | undefined {
    if (!snapshot) {
      return undefined;
    }
    for (let i = 0; i < zones.length; i++) {
      const zone = zones[i];
      const distance = HarmonyLocationService.distanceMeters(
        snapshot.latitude,
        snapshot.longitude,
        zone.latitude,
        zone.longitude
      );
      if (distance - zone.radius - Math.max(snapshot.accuracy, 0) <= 0) {
        return zone;
      }
    }
    return undefined;
  }

  static historyEntry(
    snapshot: HarmonyLocationSnapshot,
    trigger: string,
    zoneName: string,
    result: string
  ): HarmonyLocationHistoryEntry {
    return {
      timeStamp: snapshot.timeStamp,
      latitude: snapshot.latitude,
      longitude: snapshot.longitude,
      accuracy: snapshot.accuracy,
      trigger,
      zoneName,
      result
    };
  }

  private static hasCoordinateType(
    types: geoLocationManager.CoordinateSystemType[],
    target: geoLocationManager.CoordinateSystemType
  ): boolean {
    for (let i = 0; i < types.length; i++) {
      if (types[i] === target) {
        return true;
      }
    }
    return false;
  }

  private static geofenceEventName(event: geoLocationManager.GeofenceTransitionEvent): string {
    if (event === geoLocationManager.GeofenceTransitionEvent.GEOFENCE_TRANSITION_EVENT_ENTER) {
      return 'geofence_enter';
    }
    if (event === geoLocationManager.GeofenceTransitionEvent.GEOFENCE_TRANSITION_EVENT_EXIT) {
      return 'geofence_exit';
    }
    if (event === geoLocationManager.GeofenceTransitionEvent.GEOFENCE_TRANSITION_EVENT_DWELL) {
      return 'geofence_dwell';
    }
    return 'geofence_unknown';
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

  private static distanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const earthRadius = 6371000;
    const dLat = HarmonyLocationService.degreesToRadians(lat2 - lat1);
    const dLon = HarmonyLocationService.degreesToRadians(lon2 - lon1);
    const rLat1 = HarmonyLocationService.degreesToRadians(lat1);
    const rLat2 = HarmonyLocationService.degreesToRadians(lat2);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(rLat1) * Math.cos(rLat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  private static degreesToRadians(value: number): number {
    return value * Math.PI / 180;
  }
}
