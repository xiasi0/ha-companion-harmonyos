// Relational database store for service card bindings and cached card state.
// Keep schema migration and persistence concerns here; runtime refresh belongs in coordinators.
import common from '@ohos.app.ability.common';
import { relationalStore } from '@kit.ArkData';

export class CardType {
  static readonly LIGHT: string = 'light';
  static readonly MEDIA: string = 'media';
  static readonly SCENE: string = 'scene';
  static readonly CAMERA: string = 'camera';
  static readonly CLIMATE: string = 'climate';
}

export class CardTargetType {
  static readonly ENTITY: string = 'entity';
  static readonly AREA: string = 'area';
  static readonly DEVICE: string = 'device';
  static readonly CUSTOM: string = 'custom';
}

export interface HaEntityCatalogRecord {
  serverInstanceId: string;
  entityId: string;
  domain: string;
  entityName: string;
  areaId: string;
  areaName: string;
  deviceId: string;
  deviceName: string;
  entityCategory: string;
  deviceClass: string;
  unitOfMeasurement: string;
  icon: string;
  state: string;
  updatedAt: number;
}

export interface HaAreaCatalogRecord {
  serverInstanceId: string;
  areaId: string;
  areaName: string;
  updatedAt: number;
}

export interface HaCatalogMetaRecord {
  serverInstanceId: string;
  syncedAt: number;
  expiresAt: number;
  entityCount: number;
  areaCount: number;
  schemaVersion: number;
  lastError: string;
}

export interface CardBindingRecord {
  formId: string;
  formName: string;
  formDimension: string;
  cardType: string;
  serverInstanceId: string;
  targetType: string;
  targetId: string;
  targetName: string;
  areaId: string;
  areaName: string;
  configJson: string;
  state: string;
  displayJson: string;
  updatedAt: number;
}

class HaEntityCatalogPayload implements HaEntityCatalogRecord {
  serverInstanceId: string = '';
  entityId: string = '';
  domain: string = '';
  entityName: string = '';
  areaId: string = '';
  areaName: string = '';
  deviceId: string = '';
  deviceName: string = '';
  entityCategory: string = '';
  deviceClass: string = '';
  unitOfMeasurement: string = '';
  icon: string = '';
  state: string = 'unknown';
  updatedAt: number = 0;
}

class HaAreaCatalogPayload implements HaAreaCatalogRecord {
  serverInstanceId: string = '';
  areaId: string = '';
  areaName: string = '';
  updatedAt: number = 0;
}

class HaCatalogMetaPayload implements HaCatalogMetaRecord {
  serverInstanceId: string = '';
  syncedAt: number = 0;
  expiresAt: number = 0;
  entityCount: number = 0;
  areaCount: number = 0;
  schemaVersion: number = 1;
  lastError: string = '';
}

class CardBindingPayload implements CardBindingRecord {
  formId: string = '';
  formName: string = '';
  formDimension: string = '';
  cardType: string = '';
  serverInstanceId: string = '';
  targetType: string = CardTargetType.ENTITY;
  targetId: string = '';
  targetName: string = '';
  areaId: string = '';
  areaName: string = '';
  configJson: string = '{}';
  state: string = 'unknown';
  displayJson: string = '{}';
  updatedAt: number = 0;
}

interface CardSnapshotPayload {
  state: string;
  displayJson: string;
}

export class CardDataStore {
  private static readonly DB_NAME: string = 'ha_cards.db';
  private static readonly CATALOG_SCHEMA_VERSION: number = 1;
  private static store: relationalStore.RdbStore | undefined = undefined;
  private static storePromise: Promise<relationalStore.RdbStore> | undefined = undefined;

  static emptyRecord(cardType: string = ''): CardBindingRecord {
    const record = new CardBindingPayload();
    record.cardType = cardType;
    return record;
  }

  static hasBinding(record: CardBindingRecord): boolean {
    return record.formId.trim().length > 0 &&
      record.cardType.trim().length > 0 &&
      record.serverInstanceId.trim().length > 0 &&
      record.targetId.trim().length > 0;
  }

  static async upsertEntityCatalog(context: common.Context, record: HaEntityCatalogRecord): Promise<void> {
    const normalized = CardDataStore.normalizeEntity(record);
    if (normalized.serverInstanceId.length === 0 || normalized.entityId.length === 0) {
      return;
    }
    try {
      const store = await CardDataStore.getStore(context);
      await store.insert('ha_entity_catalog', CardDataStore.entityBucket(normalized), relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
  }

  static async upsertAreaCatalog(context: common.Context, record: HaAreaCatalogRecord): Promise<void> {
    const normalized = CardDataStore.normalizeArea(record);
    if (normalized.serverInstanceId.length === 0 || normalized.areaId.length === 0) {
      return;
    }
    try {
      const store = await CardDataStore.getStore(context);
      await store.insert('ha_area_catalog', CardDataStore.areaBucket(normalized), relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
  }

  static async saveCatalogMeta(context: common.Context, record: HaCatalogMetaRecord): Promise<void> {
    const normalized = CardDataStore.normalizeMeta(record);
    if (normalized.serverInstanceId.length === 0) {
      return;
    }
    try {
      const store = await CardDataStore.getStore(context);
      await store.insert('ha_catalog_meta', CardDataStore.metaBucket(normalized), relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
  }

  static async loadCatalogMeta(context: common.Context, serverInstanceId: string): Promise<HaCatalogMetaRecord> {
    try {
      const store = await CardDataStore.getStore(context);
      const result = store.querySqlSync(
        'SELECT server_instance_id, synced_at, expires_at, entity_count, area_count, schema_version, last_error FROM ha_catalog_meta WHERE server_instance_id = ?',
        [serverInstanceId.trim()]
      );
      try {
        if (!result.goToFirstRow()) {
          return new HaCatalogMetaPayload();
        }
        const record = new HaCatalogMetaPayload();
        record.serverInstanceId = result.getString(0);
        record.syncedAt = result.getLong(1);
        record.expiresAt = result.getLong(2);
        record.entityCount = result.getLong(3);
        record.areaCount = result.getLong(4);
        record.schemaVersion = result.getLong(5);
        record.lastError = result.getString(6);
        return record;
      } finally {
        CardDataStore.closeResult(result);
      }
    } catch (_) {
      return new HaCatalogMetaPayload();
    }
  }

  static async listEntityCatalog(context: common.Context, serverInstanceId: string, domain: string = ''): Promise<HaEntityCatalogRecord[]> {
    const records: HaEntityCatalogRecord[] = [];
    try {
      const store = await CardDataStore.getStore(context);
      const server = serverInstanceId.trim();
      const normalizedDomain = domain.trim();
      const sql = normalizedDomain.length > 0
        ? 'SELECT server_instance_id, entity_id, domain, entity_name, area_id, area_name, device_id, device_name, entity_category, device_class, unit_of_measurement, icon, state, updated_at FROM ha_entity_catalog WHERE server_instance_id = ? AND domain = ? ORDER BY entity_name, entity_id'
        : 'SELECT server_instance_id, entity_id, domain, entity_name, area_id, area_name, device_id, device_name, entity_category, device_class, unit_of_measurement, icon, state, updated_at FROM ha_entity_catalog WHERE server_instance_id = ? ORDER BY domain, entity_name, entity_id';
      const args: relationalStore.ValueType[] = normalizedDomain.length > 0 ? [server, normalizedDomain] : [server];
      const result = store.querySqlSync(sql, args);
      try {
        if (!result.goToFirstRow()) {
          return records;
        }
        do {
          records.push(CardDataStore.readEntityCatalogRow(result));
        } while (result.goToNextRow());
      } finally {
        CardDataStore.closeResult(result);
      }
    } catch (_) {
      return records;
    }
    return records;
  }

  static async loadEntityCatalog(context: common.Context, serverInstanceId: string, entityId: string): Promise<HaEntityCatalogRecord> {
    try {
      const store = await CardDataStore.getStore(context);
      const result = store.querySqlSync(
        'SELECT server_instance_id, entity_id, domain, entity_name, area_id, area_name, device_id, device_name, entity_category, device_class, unit_of_measurement, icon, state, updated_at FROM ha_entity_catalog WHERE server_instance_id = ? AND entity_id = ?',
        [serverInstanceId.trim(), entityId.trim()]
      );
      try {
        if (!result.goToFirstRow()) {
          return new HaEntityCatalogPayload();
        }
        return CardDataStore.readEntityCatalogRow(result);
      } finally {
        CardDataStore.closeResult(result);
      }
    } catch (_) {
      return new HaEntityCatalogPayload();
    }
  }

  static async upsertBinding(context: common.Context, record: CardBindingRecord): Promise<void> {
    const normalized = CardDataStore.normalizeBinding(record);
    if (normalized.formId.length === 0 || normalized.cardType.length === 0 || normalized.serverInstanceId.length === 0) {
      throw new Error('missing card binding identity');
    }
    try {
      const store = await CardDataStore.getStore(context);
      await store.insert('card_instance', CardDataStore.instanceBucket(normalized), relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      await store.insert('card_binding', CardDataStore.bindingBucket(normalized), relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      await CardDataStore.saveSnapshot(store, normalized);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
  }

  static async registerInstance(context: common.Context, formId: string, formName: string, formDimension: string, cardType: string): Promise<void> {
    const record = CardDataStore.emptyRecord(cardType);
    record.formId = formId.trim();
    record.formName = formName.trim();
    record.formDimension = formDimension.trim();
    record.updatedAt = Date.now();
    if (record.formId.length === 0) {
      return;
    }
    try {
      const store = await CardDataStore.getStore(context);
      const current = CardDataStore.queryOne(store, CardDataStore.bindingSelectSql('WHERE i.form_id = ?'), [record.formId]);
      if (current.formId.length > 0 && CardDataStore.hasBinding(current)) {
        current.formName = record.formName.length > 0 ? record.formName : current.formName;
        current.formDimension = record.formDimension.length > 0 ? record.formDimension : current.formDimension;
        current.cardType = record.cardType.length > 0 ? record.cardType : current.cardType;
        current.updatedAt = record.updatedAt;
        await store.insert('card_instance', CardDataStore.instanceBucket(current), relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
        return;
      }
      await store.insert('card_instance', CardDataStore.instanceBucket(record), relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
  }

  static async loadBinding(context: common.Context, formId: string): Promise<CardBindingRecord> {
    const normalized = formId.trim();
    if (normalized.length === 0) {
      return CardDataStore.emptyRecord();
    }
    try {
      const store = await CardDataStore.getStore(context);
      return CardDataStore.queryOne(store, CardDataStore.bindingSelectSql('WHERE i.form_id = ?'), [normalized]);
    } catch (_) {
      return CardDataStore.emptyRecord();
    }
  }

  static async listBindingsByType(context: common.Context, cardType: string): Promise<CardBindingRecord[]> {
    try {
      const store = await CardDataStore.getStore(context);
      return CardDataStore.queryAll(store, CardDataStore.bindingSelectSql('WHERE i.card_type = ? ORDER BY i.updated_at DESC'), [cardType.trim()]);
    } catch (_) {
      return [];
    }
  }

  static async listFormIdsByType(context: common.Context, cardType: string): Promise<string[]> {
    const records = await CardDataStore.listBindingsByType(context, cardType);
    return records.map((record: CardBindingRecord): string => record.formId);
  }

  static async listFormIdsByServer(context: common.Context, serverInstanceId: string): Promise<string[]> {
    try {
      const store = await CardDataStore.getStore(context);
      const records = CardDataStore.queryAll(store, CardDataStore.bindingSelectSql('WHERE i.server_instance_id = ?'), [serverInstanceId.trim()]);
      return records.map((record: CardBindingRecord): string => record.formId);
    } catch (_) {
      return [];
    }
  }

  static async listBoundEntityIds(context: common.Context, serverInstanceId: string): Promise<string[]> {
    const ids: string[] = [];
    try {
      const store = await CardDataStore.getStore(context);
      const result = store.querySqlSync(
        'SELECT DISTINCT target_id FROM card_binding WHERE server_instance_id = ? AND target_type = ? AND target_id <> ?',
        [serverInstanceId.trim(), CardTargetType.ENTITY, '']
      );
      try {
        if (!result.goToFirstRow()) {
          return ids;
        }
        do {
          ids.push(result.getString(0));
        } while (result.goToNextRow());
      } finally {
        CardDataStore.closeResult(result);
      }
    } catch (_) {
      return ids;
    }
    return ids;
  }

  static async updateState(context: common.Context, formId: string, state: string, displayJson?: string): Promise<CardBindingRecord> {
    const current = await CardDataStore.loadBinding(context, formId);
    if (!CardDataStore.hasBinding(current)) {
      return current;
    }
    current.state = state.trim().length > 0 ? state.trim() : current.state;
    if (displayJson !== undefined) {
      current.displayJson = displayJson.trim().length > 0 ? displayJson : '{}';
    }
    current.updatedAt = Date.now();
    try {
      const store = await CardDataStore.getStore(context);
      await CardDataStore.saveSnapshot(store, current);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
    return current;
  }

  static async clear(context: common.Context, formId: string): Promise<void> {
    const normalized = formId.trim();
    if (normalized.length === 0) {
      return;
    }
    try {
      const store = await CardDataStore.getStore(context);
      await store.executeSql('DELETE FROM card_runtime_snapshot WHERE form_id = ?', [normalized]);
      await store.executeSql('DELETE FROM card_binding WHERE form_id = ?', [normalized]);
      await store.executeSql('DELETE FROM card_instance WHERE form_id = ?', [normalized]);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
  }

  static async clearByServer(context: common.Context, serverInstanceId: string): Promise<string[]> {
    const normalized = serverInstanceId.trim();
    if (normalized.length === 0) {
      return [];
    }
    const ids = await CardDataStore.listFormIdsByServer(context, normalized);
    try {
      const store = await CardDataStore.getStore(context);
      await store.executeSql('DELETE FROM card_runtime_snapshot WHERE server_instance_id = ?', [normalized]);
      await store.executeSql('DELETE FROM card_binding WHERE server_instance_id = ?', [normalized]);
      await store.executeSql('DELETE FROM card_instance WHERE server_instance_id = ?', [normalized]);
      await store.executeSql('DELETE FROM ha_entity_catalog WHERE server_instance_id = ?', [normalized]);
      await store.executeSql('DELETE FROM ha_area_catalog WHERE server_instance_id = ?', [normalized]);
      await store.executeSql('DELETE FROM ha_catalog_meta WHERE server_instance_id = ?', [normalized]);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
    return ids;
  }

  static async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    if (CardDataStore.store) {
      return CardDataStore.store;
    }
    if (!CardDataStore.storePromise) {
      CardDataStore.storePromise = CardDataStore.openStore(context);
    }
    return CardDataStore.storePromise;
  }

  private static async openStore(context: common.Context): Promise<relationalStore.RdbStore> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: CardDataStore.DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S2
      });
      await CardDataStore.ensureSchema(store);
      CardDataStore.store = store;
      return store;
    } catch (error) {
      CardDataStore.storePromise = undefined;
      throw CardDataStore.errorFrom(error);
    }
  }

  private static async ensureSchema(store: relationalStore.RdbStore): Promise<void> {
    try {
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS ha_entity_catalog (' +
          'server_instance_id TEXT NOT NULL, entity_id TEXT NOT NULL, domain TEXT NOT NULL, entity_name TEXT, ' +
          'area_id TEXT, area_name TEXT, device_id TEXT, device_name TEXT, entity_category TEXT, device_class TEXT, ' +
          'unit_of_measurement TEXT, icon TEXT, state TEXT, updated_at INTEGER NOT NULL, PRIMARY KEY(server_instance_id, entity_id))'
      );
      await CardDataStore.ensureColumn(store, 'ha_entity_catalog', 'state', 'TEXT');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_entity_catalog_server_domain ON ha_entity_catalog(server_instance_id, domain)');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_entity_catalog_server_area ON ha_entity_catalog(server_instance_id, area_id)');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_entity_catalog_name ON ha_entity_catalog(server_instance_id, entity_name)');
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS ha_area_catalog (' +
          'server_instance_id TEXT NOT NULL, area_id TEXT NOT NULL, area_name TEXT NOT NULL, updated_at INTEGER NOT NULL, ' +
          'PRIMARY KEY(server_instance_id, area_id))'
      );
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS ha_catalog_meta (' +
          'server_instance_id TEXT PRIMARY KEY, synced_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, ' +
          'entity_count INTEGER NOT NULL, area_count INTEGER NOT NULL, schema_version INTEGER NOT NULL, last_error TEXT)'
      );
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS card_instance (' +
          'form_id TEXT PRIMARY KEY, form_name TEXT NOT NULL, card_type TEXT NOT NULL, form_dimension TEXT, ' +
          'server_instance_id TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)'
      );
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_instance_server ON card_instance(server_instance_id)');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_instance_type ON card_instance(card_type)');
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS card_binding (' +
          'form_id TEXT PRIMARY KEY, card_type TEXT NOT NULL, server_instance_id TEXT NOT NULL, ' +
          'target_type TEXT NOT NULL, target_id TEXT NOT NULL, target_name TEXT, area_id TEXT, area_name TEXT, ' +
          'state TEXT, display_json TEXT, config_json TEXT, updated_at INTEGER NOT NULL)'
      );
      await CardDataStore.ensureColumn(store, 'card_binding', 'card_type', 'TEXT');
      await CardDataStore.ensureColumn(store, 'card_binding', 'server_instance_id', 'TEXT');
      await CardDataStore.ensureColumn(store, 'card_binding', 'target_name', 'TEXT');
      await CardDataStore.ensureColumn(store, 'card_binding', 'area_id', 'TEXT');
      await CardDataStore.ensureColumn(store, 'card_binding', 'area_name', 'TEXT');
      await CardDataStore.ensureColumn(store, 'card_binding', 'state', 'TEXT');
      await CardDataStore.ensureColumn(store, 'card_binding', 'display_json', 'TEXT');
      await CardDataStore.ensureColumn(store, 'card_binding', 'config_json', 'TEXT');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_binding_server ON card_binding(server_instance_id)');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_binding_target ON card_binding(server_instance_id, target_type, target_id)');
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS card_runtime_snapshot (' +
          'form_id TEXT PRIMARY KEY, server_instance_id TEXT NOT NULL, snapshot_json TEXT NOT NULL, optimistic_json TEXT, ' +
          'updated_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, stale INTEGER NOT NULL, last_error TEXT)'
      );
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_snapshot_server ON card_runtime_snapshot(server_instance_id)');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_snapshot_expires ON card_runtime_snapshot(expires_at)');
    } catch (error) {
      throw CardDataStore.errorFrom(error);
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
        CardDataStore.closeResult(result);
      }
      await store.executeSql(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
  }

  private static normalizeEntity(record: HaEntityCatalogRecord): HaEntityCatalogRecord {
    const next = new HaEntityCatalogPayload();
    next.serverInstanceId = record.serverInstanceId.trim();
    next.entityId = record.entityId.trim();
    next.domain = record.domain.trim();
    next.entityName = record.entityName.trim();
    next.areaId = record.areaId.trim();
    next.areaName = record.areaName.trim();
    next.deviceId = record.deviceId.trim();
    next.deviceName = record.deviceName.trim();
    next.entityCategory = record.entityCategory.trim();
    next.deviceClass = record.deviceClass.trim();
    next.unitOfMeasurement = record.unitOfMeasurement.trim();
    next.icon = record.icon.trim();
    next.state = record.state.trim().length > 0 ? record.state.trim() : 'unknown';
    next.updatedAt = record.updatedAt > 0 ? record.updatedAt : Date.now();
    return next;
  }

  private static normalizeArea(record: HaAreaCatalogRecord): HaAreaCatalogRecord {
    const next = new HaAreaCatalogPayload();
    next.serverInstanceId = record.serverInstanceId.trim();
    next.areaId = record.areaId.trim();
    next.areaName = record.areaName.trim();
    next.updatedAt = record.updatedAt > 0 ? record.updatedAt : Date.now();
    return next;
  }

  private static normalizeMeta(record: HaCatalogMetaRecord): HaCatalogMetaRecord {
    const next = new HaCatalogMetaPayload();
    next.serverInstanceId = record.serverInstanceId.trim();
    next.syncedAt = record.syncedAt > 0 ? record.syncedAt : Date.now();
    next.expiresAt = record.expiresAt > 0 ? record.expiresAt : next.syncedAt;
    next.entityCount = record.entityCount;
    next.areaCount = record.areaCount;
    next.schemaVersion = record.schemaVersion > 0 ? record.schemaVersion : CardDataStore.CATALOG_SCHEMA_VERSION;
    next.lastError = record.lastError.trim();
    return next;
  }

  private static normalizeBinding(record: CardBindingRecord): CardBindingRecord {
    const next = new CardBindingPayload();
    next.formId = record.formId.trim();
    next.formName = record.formName.trim();
    next.formDimension = record.formDimension.trim();
    next.cardType = record.cardType.trim();
    next.serverInstanceId = record.serverInstanceId.trim();
    next.targetType = record.targetType.trim().length > 0 ? record.targetType.trim() : CardTargetType.ENTITY;
    next.targetId = record.targetId.trim();
    next.targetName = record.targetName.trim();
    next.areaId = record.areaId.trim();
    next.areaName = record.areaName.trim();
    next.configJson = record.configJson.trim().length > 0 ? record.configJson.trim() : '{}';
    next.state = record.state.trim().length > 0 ? record.state.trim() : 'unknown';
    next.displayJson = record.displayJson.trim().length > 0 ? record.displayJson.trim() : '{}';
    next.updatedAt = record.updatedAt > 0 ? record.updatedAt : Date.now();
    return next;
  }

  private static entityBucket(record: HaEntityCatalogRecord): relationalStore.ValuesBucket {
    return {
      'server_instance_id': record.serverInstanceId,
      'entity_id': record.entityId,
      'domain': record.domain,
      'entity_name': record.entityName,
      'area_id': record.areaId,
      'area_name': record.areaName,
      'device_id': record.deviceId,
      'device_name': record.deviceName,
      'entity_category': record.entityCategory,
      'device_class': record.deviceClass,
      'unit_of_measurement': record.unitOfMeasurement,
      'icon': record.icon,
      'state': record.state,
      'updated_at': record.updatedAt
    };
  }

  private static areaBucket(record: HaAreaCatalogRecord): relationalStore.ValuesBucket {
    return {
      'server_instance_id': record.serverInstanceId,
      'area_id': record.areaId,
      'area_name': record.areaName,
      'updated_at': record.updatedAt
    };
  }

  private static metaBucket(record: HaCatalogMetaRecord): relationalStore.ValuesBucket {
    return {
      'server_instance_id': record.serverInstanceId,
      'synced_at': record.syncedAt,
      'expires_at': record.expiresAt,
      'entity_count': record.entityCount,
      'area_count': record.areaCount,
      'schema_version': record.schemaVersion,
      'last_error': record.lastError
    };
  }

  private static instanceBucket(record: CardBindingRecord): relationalStore.ValuesBucket {
    return {
      'form_id': record.formId,
      'form_name': record.formName,
      'card_type': record.cardType,
      'form_dimension': record.formDimension,
      'server_instance_id': record.serverInstanceId,
      'created_at': record.updatedAt,
      'updated_at': record.updatedAt
    };
  }

  private static bindingBucket(record: CardBindingRecord): relationalStore.ValuesBucket {
    return {
      'form_id': record.formId,
      'card_type': record.cardType,
      'server_instance_id': record.serverInstanceId,
      'target_type': record.targetType,
      'target_id': record.targetId,
      'target_name': record.targetName,
      'area_id': record.areaId,
      'area_name': record.areaName,
      'state': record.state,
      'display_json': record.displayJson,
      'config_json': record.configJson,
      'updated_at': record.updatedAt
    };
  }

  private static async saveSnapshot(store: relationalStore.RdbStore, record: CardBindingRecord): Promise<void> {
    const snapshot: CardSnapshotPayload = {
      state: record.state,
      displayJson: record.displayJson
    };
    try {
      await store.insert('card_runtime_snapshot', {
        'form_id': record.formId,
        'server_instance_id': record.serverInstanceId,
        'snapshot_json': JSON.stringify(snapshot),
        'optimistic_json': '',
        'updated_at': record.updatedAt,
        'expires_at': record.updatedAt,
        'stale': 0,
        'last_error': ''
      }, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    } catch (error) {
      throw CardDataStore.errorFrom(error);
    }
  }

  private static bindingSelectSql(where: string): string {
    return 'SELECT i.form_id, i.form_name, i.form_dimension, COALESCE(b.card_type, i.card_type), COALESCE(b.server_instance_id, i.server_instance_id), ' +
      'COALESCE(b.target_type, \'\'), COALESCE(b.target_id, \'\'), COALESCE(b.target_name, \'\'), ' +
      'COALESCE(b.area_id, \'\'), COALESCE(b.area_name, \'\'), COALESCE(b.config_json, \'\'), ' +
      'COALESCE(s.snapshot_json, \'\'), i.updated_at ' +
      'FROM card_instance i LEFT JOIN card_binding b ON i.form_id = b.form_id ' +
      'LEFT JOIN card_runtime_snapshot s ON i.form_id = s.form_id ' + where;
  }

  private static queryOne(store: relationalStore.RdbStore, sql: string, args: relationalStore.ValueType[]): CardBindingRecord {
    const records = CardDataStore.queryAll(store, sql, args);
    return records.length > 0 ? records[0] : CardDataStore.emptyRecord();
  }

  private static readEntityCatalogRow(result: relationalStore.ResultSet): HaEntityCatalogRecord {
    const record = new HaEntityCatalogPayload();
    try {
      record.serverInstanceId = result.getString(0);
      record.entityId = result.getString(1);
      record.domain = result.getString(2);
      record.entityName = result.getString(3);
      record.areaId = result.getString(4);
      record.areaName = result.getString(5);
      record.deviceId = result.getString(6);
      record.deviceName = result.getString(7);
      record.entityCategory = result.getString(8);
      record.deviceClass = result.getString(9);
      record.unitOfMeasurement = result.getString(10);
      record.icon = result.getString(11);
      record.state = result.getString(12);
      record.updatedAt = result.getLong(13);
    } catch (_) {
      return new HaEntityCatalogPayload();
    }
    return record;
  }

  private static queryAll(store: relationalStore.RdbStore, sql: string, args: relationalStore.ValueType[]): CardBindingRecord[] {
    const records: CardBindingRecord[] = [];
    try {
      const result = store.querySqlSync(sql, args);
      try {
        if (!result.goToFirstRow()) {
          return records;
        }
        do {
          const record = new CardBindingPayload();
          record.formId = result.getString(0);
          record.formName = result.getString(1);
          record.formDimension = result.getString(2);
          record.cardType = result.getString(3);
          record.serverInstanceId = result.getString(4);
          record.targetType = result.getString(5);
          record.targetId = result.getString(6);
          record.targetName = result.getString(7);
          record.areaId = result.getString(8);
          record.areaName = result.getString(9);
          record.configJson = result.getString(10);
          const snapshot = CardDataStore.parseSnapshot(result.getString(11));
          record.state = snapshot.state;
          record.displayJson = snapshot.displayJson;
          record.updatedAt = result.getLong(12);
          records.push(record);
        } while (result.goToNextRow());
      } finally {
        CardDataStore.closeResult(result);
      }
    } catch (_) {
      return records;
    }
    return records;
  }

  private static closeResult(result: relationalStore.ResultSet): void {
    try {
      result.close();
    } catch (_) {
    }
  }

  private static errorFrom(error: Error): Error {
    return error;
  }

  private static parseSnapshot(raw: string): CardSnapshotPayload {
    try {
      const value = JSON.parse(raw) as Record<string, string>;
      return {
        state: typeof value['state'] === 'string' && value['state'].length > 0 ? value['state'] : 'unknown',
        displayJson: typeof value['displayJson'] === 'string' && value['displayJson'].length > 0 ? value['displayJson'] : '{}'
      };
    } catch (_) {
      return {
        state: 'unknown',
        displayJson: '{}'
      };
    }
  }
}
