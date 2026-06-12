// Persistent sensor state cache used by settings UI and sensor publishing.
import common from '@ohos.app.ability.common';
import { relationalStore } from '@kit.ArkData';
import { SensorSettingsLiveStateStore } from './SensorSettingsLiveStateStore';

export interface SensorStateRecord {
  sensorId: string;
  stateJson: string;
  summary: string;
  unitOfMeasurement: string;
  deviceClass: string;
  icon: string;
  attributesJson: string;
  updatedAt: number;
}

class SensorStatePayload implements SensorStateRecord {
  sensorId: string = '';
  stateJson: string = 'null';
  summary: string = '';
  unitOfMeasurement: string = '';
  deviceClass: string = '';
  icon: string = '';
  attributesJson: string = '{}';
  updatedAt: number = 0;
}

export class SensorStateStore {
  private static readonly DB_NAME: string = 'ha_sensor_state.db';
  private static store: relationalStore.RdbStore | undefined = undefined;
  private static storePromise: Promise<relationalStore.RdbStore> | undefined = undefined;

  static remember(records: SensorStateRecord[], disabledSensorIds: string[]): void {
    SensorSettingsLiveStateStore.applyRecords(records, disabledSensorIds);
  }

  static async loadRecords(context: common.Context): Promise<void> {
    try {
      const store = await SensorStateStore.getStore(context);
      const result = store.querySqlSync(
        'SELECT sensor_id, state_json, summary, unit_of_measurement, device_class, icon, attributes_json, updated_at, enabled ' +
          'FROM ha_sensor_state'
      );
      try {
        const records: SensorStateRecord[] = [];
        const enabledValues: boolean[] = [];
        if (result.goToFirstRow()) {
          do {
            const enabled = result.getLong(8) !== 0;
            records.push({
              sensorId: result.getString(0),
              stateJson: result.getString(1),
              summary: result.getString(2),
              unitOfMeasurement: result.getString(3),
              deviceClass: result.getString(4),
              icon: result.getString(5),
              attributesJson: result.getString(6),
              updatedAt: result.getLong(7)
            });
            enabledValues.push(enabled);
          } while (result.goToNextRow());
        }
        for (let i = 0; i < records.length; i++) {
          SensorSettingsLiveStateStore.applyRecord(records[i], enabledValues[i]);
        }
      } finally {
        SensorStateStore.closeResult(result);
      }
    } catch (_) {
    }
  }

  static async upsertRecords(
    context: common.Context | undefined,
    records: SensorStateRecord[],
    disabledSensorIds: string[]
  ): Promise<void> {
    SensorStateStore.remember(records, disabledSensorIds);
    if (!context) {
      return;
    }
    try {
      const store = await SensorStateStore.getStore(context);
      for (let i = 0; i < records.length; i++) {
        const record = SensorStateStore.normalize(records[i]);
        if (record.sensorId.length === 0) {
          continue;
        }
        await store.insert(
          'ha_sensor_state',
          SensorStateStore.recordBucket(record),
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
        );
      }
      for (let i = 0; i < disabledSensorIds.length; i++) {
        const sensorId = disabledSensorIds[i].trim();
        if (sensorId.length === 0) {
          continue;
        }
        await store.insert(
          'ha_sensor_state',
          SensorStateStore.disabledRecordBucket(sensorId),
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
        );
      }
    } catch (_) {
    }
  }

  private static async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    if (SensorStateStore.store) {
      return SensorStateStore.store;
    }
    if (!SensorStateStore.storePromise) {
      SensorStateStore.storePromise = SensorStateStore.openStore(context);
    }
    return SensorStateStore.storePromise;
  }

  private static async openStore(context: common.Context): Promise<relationalStore.RdbStore> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: SensorStateStore.DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S2
      });
      await SensorStateStore.ensureSchema(store);
      SensorStateStore.store = store;
      return store;
    } catch (error) {
      SensorStateStore.storePromise = undefined;
      throw SensorStateStore.errorFrom(error);
    }
  }

  private static async ensureSchema(store: relationalStore.RdbStore): Promise<void> {
    try {
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS ha_sensor_state (' +
          'sensor_id TEXT PRIMARY KEY, enabled INTEGER DEFAULT 1, state_json TEXT NOT NULL, summary TEXT, unit_of_measurement TEXT, ' +
          'device_class TEXT, icon TEXT, attributes_json TEXT, updated_at INTEGER NOT NULL)'
      );
      await SensorStateStore.ensureColumn(store, 'ha_sensor_state', 'enabled', 'INTEGER DEFAULT 1');
      await SensorStateStore.ensureColumn(store, 'ha_sensor_state', 'state_json', 'TEXT');
      await SensorStateStore.ensureColumn(store, 'ha_sensor_state', 'summary', 'TEXT');
      await SensorStateStore.ensureColumn(store, 'ha_sensor_state', 'unit_of_measurement', 'TEXT');
      await SensorStateStore.ensureColumn(store, 'ha_sensor_state', 'device_class', 'TEXT');
      await SensorStateStore.ensureColumn(store, 'ha_sensor_state', 'icon', 'TEXT');
      await SensorStateStore.ensureColumn(store, 'ha_sensor_state', 'attributes_json', 'TEXT');
      await SensorStateStore.ensureColumn(store, 'ha_sensor_state', 'updated_at', 'INTEGER');
    } catch (error) {
      throw SensorStateStore.errorFrom(error);
    }
  }

  private static async ensureColumn(store: relationalStore.RdbStore, table: string, column: string, definition: string): Promise<void> {
    try {
      const result = store.querySqlSync(`PRAGMA table_info(${table})`);
      try {
        if (result.goToFirstRow()) {
          do {
            if (result.getString(1) === column) {
              return;
            }
          } while (result.goToNextRow());
        }
      } finally {
        SensorStateStore.closeResult(result);
      }
      await store.executeSql(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
    } catch (error) {
      throw SensorStateStore.errorFrom(error);
    }
  }

  private static normalize(record: SensorStateRecord): SensorStateRecord {
    const next = new SensorStatePayload();
    next.sensorId = record.sensorId.trim();
    next.stateJson = record.stateJson.trim().length > 0 ? record.stateJson.trim() : 'null';
    next.summary = record.summary.trim();
    next.unitOfMeasurement = record.unitOfMeasurement.trim();
    next.deviceClass = record.deviceClass.trim();
    next.icon = record.icon.trim();
    next.attributesJson = record.attributesJson.trim().length > 0 ? record.attributesJson.trim() : '{}';
    next.updatedAt = record.updatedAt > 0 ? record.updatedAt : Date.now();
    return next;
  }

  private static recordBucket(record: SensorStateRecord): relationalStore.ValuesBucket {
    return {
      sensor_id: record.sensorId,
      enabled: 1,
      state_json: record.stateJson,
      summary: record.summary,
      unit_of_measurement: record.unitOfMeasurement,
      device_class: record.deviceClass,
      icon: record.icon,
      attributes_json: record.attributesJson,
      updated_at: record.updatedAt
    };
  }

  private static disabledRecordBucket(sensorId: string): relationalStore.ValuesBucket {
    return {
      sensor_id: sensorId,
      enabled: 0,
      state_json: 'null',
      summary: '',
      unit_of_measurement: '',
      device_class: '',
      icon: '',
      attributes_json: '{}',
      updated_at: Date.now()
    };
  }

  private static closeResult(result: relationalStore.ResultSet): void {
    try {
      result.close();
    } catch (_) {
    }
  }

  private static errorFrom(error: Error | string | number | boolean | Object): Error {
    if (error instanceof Error) {
      return error;
    }
    return new Error(String(error));
  }
}
