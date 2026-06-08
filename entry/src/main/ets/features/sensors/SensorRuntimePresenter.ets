import { HarmonyLocationSentMode, HarmonySensorService, SensorPreferenceSnapshot } from '../../services/HarmonySensorService';
import { SensorCatalog } from './SensorCatalog';
import { SensorEntry, SensorGroup } from './SensorModels';

export interface SensorRuntimeFlags {
  batterySOCEnabled: boolean;
  chargingStatusEnabled: boolean;
  pluggedTypeEnabled: boolean;
  bearerTypesEnabled: boolean;
  lastUpdateTriggerEnabled: boolean;
  locationBackgroundEnabled: boolean;
  zoneBackgroundEnabled: boolean;
  accurateLocationEnabled: boolean;
  directSensorIds: string[];
}

export interface SensorToggleResult {
  supported: boolean;
  flags: SensorRuntimeFlags;
  shouldStopLocationRuntime: boolean;
}

export class SensorRuntimePresenter {
  static preferences(flags: SensorRuntimeFlags): SensorPreferenceSnapshot {
    return {
      batterySOCEnabled: flags.batterySOCEnabled,
      chargingStatusEnabled: flags.chargingStatusEnabled,
      pluggedTypeEnabled: flags.pluggedTypeEnabled,
      bearerTypesEnabled: flags.bearerTypesEnabled,
      lastUpdateTriggerEnabled: flags.lastUpdateTriggerEnabled,
      locationBackgroundEnabled: flags.locationBackgroundEnabled,
      zoneBackgroundEnabled: flags.zoneBackgroundEnabled,
      accurateLocationEnabled: flags.accurateLocationEnabled,
      directSensorIds: flags.directSensorIds
    };
  }

  static locationSentMode(value: string): HarmonyLocationSentMode {
    if (value === 'exact') {
      return 'exact';
    }
    if (value === 'zone') {
      return 'zone';
    }
    if (value === 'never') {
      return 'never';
    }
    return 'never';
  }

  static isSensorEnabled(sensorId: string, flags: SensorRuntimeFlags): boolean {
    return HarmonySensorService.isSensorEnabled(sensorId, SensorRuntimePresenter.preferences(flags));
  }

  static hasAnyLocationSensorEnabled(flags: SensorRuntimeFlags): boolean {
    return flags.locationBackgroundEnabled || flags.zoneBackgroundEnabled || flags.accurateLocationEnabled;
  }

  static needsForegroundLocation(flags: SensorRuntimeFlags): boolean {
    return SensorRuntimePresenter.hasAnyLocationSensorEnabled(flags) ||
      SensorRuntimePresenter.containsText(flags.directSensorIds, 'geocoded_location');
  }

  static withSensorEnabled(sensorId: string, enabled: boolean, flags: SensorRuntimeFlags): SensorToggleResult {
    if (!HarmonySensorService.isSupportedPublicSensor(sensorId)) {
      return {
        supported: false,
        flags,
        shouldStopLocationRuntime: false
      };
    }
    const next: SensorRuntimeFlags = {
      batterySOCEnabled: sensorId === 'battery_level' ? enabled : flags.batterySOCEnabled,
      chargingStatusEnabled: sensorId === 'battery_state' ? enabled : flags.chargingStatusEnabled,
      pluggedTypeEnabled: sensorId === 'charger_type' ? enabled : flags.pluggedTypeEnabled,
      bearerTypesEnabled: sensorId === 'network_type' ? enabled : flags.bearerTypesEnabled,
      lastUpdateTriggerEnabled: sensorId === 'last_update_trigger' ? enabled : flags.lastUpdateTriggerEnabled,
      locationBackgroundEnabled: sensorId === 'location_background' ? enabled : flags.locationBackgroundEnabled,
      zoneBackgroundEnabled: sensorId === 'zone_background' ? enabled : flags.zoneBackgroundEnabled,
      accurateLocationEnabled: sensorId === 'accurate_location' ? enabled : flags.accurateLocationEnabled,
      directSensorIds: HarmonySensorService.isCorePublicSensor(sensorId)
        ? flags.directSensorIds
        : SensorRuntimePresenter.withDirectSensorId(sensorId, enabled, flags.directSensorIds)
    };
    return {
      supported: true,
      flags: next,
      shouldStopLocationRuntime: !SensorRuntimePresenter.needsForegroundLocation(next)
    };
  }

  static enabledSensorCount(flags: SensorRuntimeFlags): number {
    const sensorIds = [
      'battery_level',
      'battery_state',
      'charger_type',
      'network_type',
      'last_update_trigger',
      'location_background',
      'zone_background',
      'accurate_location'
    ];
    let count = 0;
    for (let i = 0; i < sensorIds.length; i++) {
      if (SensorRuntimePresenter.isSensorEnabled(sensorIds[i], flags)) {
        count += 1;
      }
    }
    return count + flags.directSensorIds.length;
  }

  static sensorGroups(flags: SensorRuntimeFlags): SensorGroup[] {
    const prefs = SensorRuntimePresenter.preferences(flags);
    return SensorCatalog.groups().map((group: SensorGroup): SensorGroup => {
      const sensors: SensorEntry[] = group.sensors.map((sensor: SensorEntry): SensorEntry => {
        const mapped: SensorEntry = {
          id: sensor.id,
          title: sensor.title,
          icon: sensor.icon,
          enabled: HarmonySensorService.isSupportedPublicSensor(sensor.id) ?
            HarmonySensorService.isSensorEnabled(sensor.id, prefs) : false,
          summary: HarmonySensorService.sensorSummary(sensor.id, prefs)
        };
        return mapped;
      });
      const mappedGroup: SensorGroup = {
        title: group.title,
        sensors
      };
      return mappedGroup;
    });
  }

  static directSensorIdsFromJson(value: string): string[] {
    return HarmonySensorService.directSensorIdsFromJson(value);
  }

  static directSensorIdsToJson(value: string[]): string {
    return HarmonySensorService.directSensorIdsToJson(value);
  }

  private static withDirectSensorId(sensorId: string, enabled: boolean, ids: string[]): string[] {
    const result: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      if (ids[i] !== sensorId && !SensorRuntimePresenter.containsText(result, ids[i])) {
        result.push(ids[i]);
      }
    }
    if (enabled) {
      result.push(sensorId);
    }
    return result;
  }

  private static containsText(values: string[], target: string): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true;
      }
    }
    return false;
  }
}
