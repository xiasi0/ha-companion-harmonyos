import common from '@ohos.app.ability.common';
import { relationalStore } from '@kit.ArkData';
import { CardDataStore } from '../cards/CardDataStore';

export interface NotificationRecentRecord {
  localId: number;
  notificationId: number;
  serverInstanceId: string;
  title: string;
  text: string;
  additionalText: string;
  source: string;
  dataJson: string;
  receivedAt: number;
  unread: boolean;
}

export interface NotificationRecentInput {
  notificationId: number;
  dedupeKey: string;
  serverInstanceId: string;
  title: string;
  text: string;
  additionalText: string;
  source: string;
  dataJson: string;
  receivedAt: number;
}

class NotificationRecentPayload implements NotificationRecentRecord {
  localId: number = 0;
  notificationId: number = 0;
  serverInstanceId: string = '';
  title: string = '';
  text: string = '';
  additionalText: string = '';
  source: string = '';
  dataJson: string = '';
  receivedAt: number = 0;
  unread: boolean = true;
}

export class NotificationRecentStore {
  private static readonly TABLE: string = 'notification_recent';
  private static readonly MAX_RECORDS: number = 100;
  private static schemaReady: boolean = false;
  private static schemaPromise: Promise<void> | undefined = undefined;

  static async add(context: common.Context, input: NotificationRecentInput): Promise<void> {
    try {
      const store = await NotificationRecentStore.getStore(context);
      const dedupeKey = input.dedupeKey.trim();
      if (dedupeKey.length > 0 && await NotificationRecentStore.updateExisting(store, input, dedupeKey)) {
        await NotificationRecentStore.trim(store);
        return;
      }
      await store.insert(NotificationRecentStore.TABLE, {
        'notification_id': input.notificationId,
        'dedupe_key': dedupeKey,
        'server_instance_id': input.serverInstanceId.trim(),
        'title': input.title,
        'text': input.text,
        'additional_text': input.additionalText,
        'source': input.source,
        'data_json': input.dataJson,
        'received_at': input.receivedAt,
        'unread': 1
      }, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      await NotificationRecentStore.trim(store);
    } catch (error) {
      throw NotificationRecentStore.errorFrom(error);
    }
  }

  static async listRecent(context: common.Context): Promise<NotificationRecentRecord[]> {
    const records: NotificationRecentRecord[] = [];
    try {
      const store = await NotificationRecentStore.getStore(context);
      const result = store.querySqlSync(
        'SELECT local_id, notification_id, server_instance_id, title, text, additional_text, source, data_json, received_at, unread ' +
          `FROM ${NotificationRecentStore.TABLE} ORDER BY received_at DESC, local_id DESC LIMIT ?`,
        [NotificationRecentStore.MAX_RECORDS]
      );
      try {
        if (!result.goToFirstRow()) {
          return records;
        }
        do {
          const record = new NotificationRecentPayload();
          record.localId = result.getLong(0);
          record.notificationId = result.getLong(1);
          record.serverInstanceId = result.getString(2);
          record.title = result.getString(3);
          record.text = result.getString(4);
          record.additionalText = result.getString(5);
          record.source = result.getString(6);
          record.dataJson = result.getString(7);
          record.receivedAt = result.getLong(8);
          record.unread = result.getLong(9) === 1;
          records.push(record);
        } while (result.goToNextRow());
        return records;
      } finally {
        NotificationRecentStore.closeResult(result);
      }
    } catch (_) {
      return records;
    }
  }

  static async unreadCount(context: common.Context): Promise<number> {
    try {
      const store = await NotificationRecentStore.getStore(context);
      const result = store.querySqlSync(`SELECT COUNT(*) FROM ${NotificationRecentStore.TABLE} WHERE unread = 1`);
      try {
        if (!result.goToFirstRow()) {
          return 0;
        }
        return result.getLong(0);
      } finally {
        NotificationRecentStore.closeResult(result);
      }
    } catch (_) {
      return 0;
    }
  }

  static async markRead(context: common.Context, localId: number): Promise<void> {
    if (localId <= 0) {
      return;
    }
    try {
      const store = await NotificationRecentStore.getStore(context);
      await store.executeSql(`UPDATE ${NotificationRecentStore.TABLE} SET unread = 0 WHERE local_id = ?`, [localId]);
    } catch (error) {
      throw NotificationRecentStore.errorFrom(error);
    }
  }

  static async clear(context: common.Context): Promise<void> {
    try {
      const store = await NotificationRecentStore.getStore(context);
      await store.executeSql(`DELETE FROM ${NotificationRecentStore.TABLE}`);
    } catch (error) {
      throw NotificationRecentStore.errorFrom(error);
    }
  }

  private static async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    const store = await CardDataStore.getStore(context);
    await NotificationRecentStore.ensureSchema(store);
    return store;
  }

  private static async ensureSchema(store: relationalStore.RdbStore): Promise<void> {
    if (NotificationRecentStore.schemaReady) {
      return;
    }
    if (!NotificationRecentStore.schemaPromise) {
      NotificationRecentStore.schemaPromise = NotificationRecentStore.createSchema(store);
    }
    await NotificationRecentStore.schemaPromise;
  }

  private static async createSchema(store: relationalStore.RdbStore): Promise<void> {
    try {
      await store.executeSql(
        `CREATE TABLE IF NOT EXISTS ${NotificationRecentStore.TABLE} (` +
          'local_id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
          'notification_id INTEGER NOT NULL, ' +
          'dedupe_key TEXT, ' +
          'server_instance_id TEXT, ' +
          'title TEXT NOT NULL, ' +
          'text TEXT NOT NULL, ' +
          'additional_text TEXT, ' +
          'source TEXT, ' +
          'data_json TEXT, ' +
          'received_at INTEGER NOT NULL, ' +
          'unread INTEGER NOT NULL DEFAULT 1)'
      );
      await store.executeSql(
        `CREATE INDEX IF NOT EXISTS idx_notification_recent_received_at ON ${NotificationRecentStore.TABLE}(received_at DESC)`
      );
      await store.executeSql(
        `CREATE INDEX IF NOT EXISTS idx_notification_recent_unread ON ${NotificationRecentStore.TABLE}(unread, received_at DESC)`
      );
      await NotificationRecentStore.ensureDedupeColumn(store);
      await store.executeSql(
        `CREATE INDEX IF NOT EXISTS idx_notification_recent_server_dedupe_key ON ` +
          `${NotificationRecentStore.TABLE}(server_instance_id, dedupe_key)`
      );
      NotificationRecentStore.schemaReady = true;
    } catch (error) {
      throw NotificationRecentStore.errorFrom(error);
    }
  }

  private static async trim(store: relationalStore.RdbStore): Promise<void> {
    try {
      await store.executeSql(
        `DELETE FROM ${NotificationRecentStore.TABLE} WHERE local_id NOT IN (` +
          `SELECT local_id FROM ${NotificationRecentStore.TABLE} ORDER BY received_at DESC, local_id DESC LIMIT ?)`,
        [NotificationRecentStore.MAX_RECORDS]
      );
    } catch (error) {
      throw NotificationRecentStore.errorFrom(error);
    }
  }

  private static async updateExisting(
    store: relationalStore.RdbStore,
    input: NotificationRecentInput,
    dedupeKey: string
  ): Promise<boolean> {
    const serverInstanceId = input.serverInstanceId.trim();
    let result: relationalStore.ResultSet | undefined = undefined;
    try {
      result = store.querySqlSync(
        `SELECT local_id FROM ${NotificationRecentStore.TABLE} ` +
          'WHERE server_instance_id = ? AND dedupe_key = ? ORDER BY received_at DESC LIMIT 1',
        [serverInstanceId, dedupeKey]
      );
      if (!result.goToFirstRow()) {
        return false;
      }
      const localId = result.getLong(0);
      await store.executeSql(
        `UPDATE ${NotificationRecentStore.TABLE} SET ` +
          'notification_id = ?, server_instance_id = ?, title = ?, text = ?, additional_text = ?, ' +
          'source = ?, data_json = ?, received_at = ?, unread = 1 WHERE local_id = ?',
        [
          input.notificationId,
          serverInstanceId,
          input.title,
          input.text,
          input.additionalText,
          input.source,
          input.dataJson,
          input.receivedAt,
          localId
        ]
      );
      return true;
    } catch (error) {
      throw NotificationRecentStore.errorFrom(error);
    } finally {
      if (result) {
        NotificationRecentStore.closeResult(result);
      }
    }
  }

  private static async ensureDedupeColumn(store: relationalStore.RdbStore): Promise<void> {
    try {
      await store.executeSql(`ALTER TABLE ${NotificationRecentStore.TABLE} ADD COLUMN dedupe_key TEXT`);
    } catch (_) {
    }
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
}
