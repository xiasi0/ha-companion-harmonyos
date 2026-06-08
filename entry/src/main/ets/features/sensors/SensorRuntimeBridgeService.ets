import { HarmonySensorService } from '../../services/HarmonySensorService';
import { Localization } from '../../shared/i18n/Localization';
import { SensorGroup } from './SensorModels';
import { SensorRuntimeFlags, SensorRuntimePresenter } from './SensorRuntimePresenter';
import { SensorRuntimeCallbacks, SensorRuntimeService } from './SensorRuntimeService';

export interface SensorRuntimeBridgeState {
  sensorBatterySOCEnabled: boolean;
  sensorChargingStatusEnabled: boolean;
  sensorPluggedTypeEnabled: boolean;
  sensorBearerTypesEnabled: boolean;
  sensorLastUpdateTriggerEnabled: boolean;
  sensorLocationEnabled: boolean;
  sensorZoneBackgroundEnabled: boolean;
  sensorAccurateLocationEnabled: boolean;
  sensorDirectEnabledJson: string;
  locationHistoryJson: string;
  locationSentMode: string;
  locationDiagnosticsJson: string;
  locationGeofenceStatus: string;
  message: string;
}

export class SensorRuntimeBridgeService {
  static flags(state: SensorRuntimeBridgeState): SensorRuntimeFlags {
    return {
      batterySOCEnabled: state.sensorBatterySOCEnabled,
      chargingStatusEnabled: state.sensorChargingStatusEnabled,
      pluggedTypeEnabled: state.sensorPluggedTypeEnabled,
      bearerTypesEnabled: state.sensorBearerTypesEnabled,
      lastUpdateTriggerEnabled: state.sensorLastUpdateTriggerEnabled,
      locationBackgroundEnabled: state.sensorLocationEnabled,
      zoneBackgroundEnabled: state.sensorZoneBackgroundEnabled,
      accurateLocationEnabled: state.sensorAccurateLocationEnabled,
      directSensorIds: SensorRuntimePresenter.directSensorIdsFromJson(state.sensorDirectEnabledJson)
    };
  }

  static applyFlags(state: SensorRuntimeBridgeState, flags: SensorRuntimeFlags): void {
    state.sensorBatterySOCEnabled = flags.batterySOCEnabled;
    state.sensorChargingStatusEnabled = flags.chargingStatusEnabled;
    state.sensorPluggedTypeEnabled = flags.pluggedTypeEnabled;
    state.sensorBearerTypesEnabled = flags.bearerTypesEnabled;
    state.sensorLastUpdateTriggerEnabled = flags.lastUpdateTriggerEnabled;
    state.sensorLocationEnabled = flags.locationBackgroundEnabled;
    state.sensorZoneBackgroundEnabled = flags.zoneBackgroundEnabled;
    state.sensorAccurateLocationEnabled = flags.accurateLocationEnabled;
    state.sensorDirectEnabledJson = SensorRuntimePresenter.directSensorIdsToJson(flags.directSensorIds);
  }

  static sensorGroups(runtime: SensorRuntimeService, state: SensorRuntimeBridgeState): SensorGroup[] {
    return runtime.sensorGroups(SensorRuntimeBridgeService.flags(state));
  }

  static toggleSensor(
    runtime: SensorRuntimeService,
    state: SensorRuntimeBridgeState,
    sensorId: string,
    callbacks: SensorRuntimeCallbacks,
    onChanged: () => void
  ): void {
    if (!HarmonySensorService.isSupportedPublicSensor(sensorId)) {
      state.message = Localization.t('sensor_permission_or_pending');
      return;
    }
    if (sensorId === 'accurate_location') {
      runtime.setLocationSharingMode(state.sensorAccurateLocationEnabled ? 'never' : 'exact', callbacks);
      return;
    }
    if (sensorId === 'zone_background') {
      runtime.setLocationSharingMode(state.sensorZoneBackgroundEnabled ? 'never' : 'zone', callbacks);
      return;
    }
    if (sensorId === 'location_background') {
      runtime.toggleBackgroundLocationSharing(callbacks);
      return;
    }
    const nextEnabled = !runtime.isSensorEnabled(sensorId, SensorRuntimeBridgeService.flags(state));
    runtime.setSensorEnabledWithPermission(sensorId, nextEnabled, callbacks, onChanged);
  }
}
