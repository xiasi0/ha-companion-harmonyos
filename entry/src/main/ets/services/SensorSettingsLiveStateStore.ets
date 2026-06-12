import { SensorGroup } from '../features/sensors/SensorModels';
import type { SensorStateRecord } from './SensorStateStore';

@Observed
export class SensorSettingsLiveRowState {
  id: string = '';
  title: string = '';
  icon: string = '';
  checked: boolean = false;
  summary: string = '';
  updatedAt: number = 0;
}

@Observed
export class SensorSettingsLiveGroupState {
  key: string = '';
  title: string = '';
  rows: SensorSettingsLiveRowState[] = [];
}

export class SensorSettingsLiveStateStore {
  private static rows: Map<string, SensorSettingsLiveRowState> = new Map<string, SensorSettingsLiveRowState>();
  private static pendingChecked: Map<string, boolean> = new Map<string, boolean>();

  static stateFor(sensorId: string): SensorSettingsLiveRowState {
    const existing = SensorSettingsLiveStateStore.rows.get(sensorId);
    if (existing) {
      return existing;
    }
    const created = new SensorSettingsLiveRowState();
    created.id = sensorId;
    SensorSettingsLiveStateStore.rows.set(sensorId, created);
    return created;
  }

  static applySensorGroups(groups: SensorGroup[]): void {
    for (let i = 0; i < groups.length; i++) {
      const group = groups[i];
      for (let j = 0; j < group.sensors.length; j++) {
        const sensor = group.sensors[j];
        const state = SensorSettingsLiveStateStore.stateFor(sensor.id);
        if (!SensorSettingsLiveStateStore.pendingChecked.has(sensor.id)) {
          state.checked = sensor.enabled;
        }
        if (!state.checked) {
          state.summary = '';
        }
      }
    }
  }

  static applyRecords(records: SensorStateRecord[], disabledSensorIds: string[]): void {
    for (let i = 0; i < records.length; i++) {
      SensorSettingsLiveStateStore.applyRecord(records[i], true);
    }
    for (let i = 0; i < disabledSensorIds.length; i++) {
      const state = SensorSettingsLiveStateStore.stateFor(disabledSensorIds[i]);
      if (!SensorSettingsLiveStateStore.pendingChecked.has(disabledSensorIds[i])) {
        state.checked = false;
      }
      state.summary = '';
      state.updatedAt = Date.now();
    }
  }

  static applyRecord(record: SensorStateRecord, enabled: boolean): void {
    const sensorId = record.sensorId.trim();
    if (sensorId.length === 0) {
      return;
    }
    const state = SensorSettingsLiveStateStore.stateFor(sensorId);
    if (!SensorSettingsLiveStateStore.pendingChecked.has(sensorId)) {
      state.checked = enabled;
    }
    state.summary = state.checked ? record.summary.trim() : '';
    state.updatedAt = record.updatedAt > 0 ? record.updatedAt : Date.now();
  }

  static beginPendingChecked(sensorId: string, checked: boolean): void {
    SensorSettingsLiveStateStore.pendingChecked.set(sensorId, checked);
    SensorSettingsLiveStateStore.setChecked(sensorId, checked);
  }

  static hasPendingChecked(): boolean {
    return SensorSettingsLiveStateStore.pendingChecked.size > 0;
  }

  static commitPendingChecked(sensorId: string, checked: boolean): void {
    SensorSettingsLiveStateStore.pendingChecked.delete(sensorId);
    SensorSettingsLiveStateStore.setChecked(sensorId, checked);
  }

  static revertPendingChecked(sensorId: string, checked: boolean): void {
    SensorSettingsLiveStateStore.pendingChecked.delete(sensorId);
    SensorSettingsLiveStateStore.setChecked(sensorId, checked);
  }

  static setChecked(sensorId: string, checked: boolean): void {
    const state = SensorSettingsLiveStateStore.stateFor(sensorId);
    state.checked = checked;
    if (!checked) {
      state.summary = '';
    }
    state.updatedAt = Date.now();
  }

}
