import common from '@ohos.app.ability.common';
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HomeAssistantNotificationAdapter } from '../notifications/HomeAssistantNotificationAdapter';
import { NotificationService } from '../notifications/NotificationService';

const DOMAIN = 0x0000;
const TAG = 'HAPushKitStore';

interface PersistedPushKitMessage {
  id: number;
  messageId: string;
  message: string;
  createTime: number;
}

export class PushKitPersistentMessageStore {
  private static readonly STORE_NAME: string = 'pushmessage.db';
  private static readonly TABLE: string = 't_push_message';
  private static store: relationalStore.RdbStore | undefined = undefined;
  private static storePromise: Promise<relationalStore.RdbStore> | undefined = undefined;
  private static migrationPromise: Promise<void> | undefined = undefined;
  private static schemaReady: boolean = false;

  static async migrateToNotificationHistory(context: common.Context): Promise<void> {
    if (PushKitPersistentMessageStore.migrationPromise) {
      await PushKitPersistentMessageStore.migrationPromise;
      return;
    }
    PushKitPersistentMessageStore.migrationPromise = PushKitPersistentMessageStore.migratePending(context);
    try {
      await PushKitPersistentMessageStore.migrationPromise;
    } finally {
      PushKitPersistentMessageStore.migrationPromise = undefined;
    }
  }

  private static async migratePending(context: common.Context): Promise<void> {
    let messages: PersistedPushKitMessage[] = [];
    try {
      const store = await PushKitPersistentMessageStore.getStore(context);
      messages = PushKitPersistentMessageStore.listMessages(store);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'read persisted Push Kit messages failed: %{public}s',
        PushKitPersistentMessageStore.errorText(error));
      return;
    }
    for (let i = 0; i < messages.length; i++) {
      await PushKitPersistentMessageStore.migrateOne(context, messages[i]);
    }
  }

  private static async migrateOne(context: common.Context, message: PersistedPushKitMessage): Promise<void> {
    const localPayload = HomeAssistantNotificationAdapter.fromPayload(message.message, 'pushkit');
    try {
      if (localPayload) {
        if (!localPayload.dedupeKey && message.messageId.trim().length > 0) {
          localPayload.dedupeKey = `pushkit:${message.messageId.trim()}`;
        }
        localPayload.id = localPayload.id ?? PushKitPersistentMessageStore.notificationId(message);
        localPayload.source = localPayload.source ?? 'pushkit';
        await NotificationService.recordHomeAssistantNotification(context, localPayload);
      }
      await PushKitPersistentMessageStore.deleteMessage(context, message.id);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'migrate persisted Push Kit message failed: %{public}s',
        PushKitPersistentMessageStore.errorText(error));
    }
  }

  private static async deleteMessage(context: common.Context, id: number): Promise<void> {
    try {
      const store = await PushKitPersistentMessageStore.getStore(context);
      await store.executeSql(`DELETE FROM ${PushKitPersistentMessageStore.TABLE} WHERE id = ?`, [id]);
    } catch (error) {
      throw PushKitPersistentMessageStore.errorFrom(error);
    }
  }

  private static listMessages(store: relationalStore.RdbStore): PersistedPushKitMessage[] {
    const messages: PersistedPushKitMessage[] = [];
    let result: relationalStore.ResultSet | undefined = undefined;
    try {
      result = store.querySqlSync(
        `SELECT id, message_id, message, create_time FROM ${PushKitPersistentMessageStore.TABLE} ORDER BY id ASC`
      );
      if (!result.goToFirstRow()) {
        return messages;
      }
      do {
        messages.push({
          id: result.getLong(0),
          messageId: result.getString(1),
          message: result.getString(2),
          createTime: result.getLong(3)
        });
      } while (result.goToNextRow());
      return messages;
    } catch (error) {
      throw PushKitPersistentMessageStore.errorFrom(error);
    } finally {
      if (result) {
        PushKitPersistentMessageStore.closeResult(result);
      }
    }
  }

  private static async getStore(context: common.Context): Promise<relationalStore.RdbStore> {
    if (PushKitPersistentMessageStore.store) {
      return PushKitPersistentMessageStore.store;
    }
    if (!PushKitPersistentMessageStore.storePromise) {
      PushKitPersistentMessageStore.storePromise = PushKitPersistentMessageStore.openStore(context);
    }
    try {
      PushKitPersistentMessageStore.store = await PushKitPersistentMessageStore.storePromise;
      return PushKitPersistentMessageStore.store;
    } catch (error) {
      PushKitPersistentMessageStore.store = undefined;
      PushKitPersistentMessageStore.storePromise = undefined;
      PushKitPersistentMessageStore.schemaReady = false;
      throw PushKitPersistentMessageStore.errorFrom(error);
    }
  }

  private static async openStore(context: common.Context): Promise<relationalStore.RdbStore> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: PushKitPersistentMessageStore.STORE_NAME,
        securityLevel: relationalStore.SecurityLevel.S2
      });
      await PushKitPersistentMessageStore.ensureSchema(store);
      return store;
    } catch (error) {
      throw PushKitPersistentMessageStore.errorFrom(error);
    }
  }

  private static async ensureSchema(store: relationalStore.RdbStore): Promise<void> {
    if (PushKitPersistentMessageStore.schemaReady) {
      return;
    }
    try {
      await store.executeSql(
        `CREATE TABLE IF NOT EXISTS ${PushKitPersistentMessageStore.TABLE} (` +
          'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
          'message_id TEXT, ' +
          'push_type TEXT, ' +
          'message_action INTEGER, ' +
          'message TEXT, ' +
          'field1 TEXT, ' +
          'field2 TEXT, ' +
          'field3 TEXT, ' +
          'field4 TEXT, ' +
          'field5 TEXT, ' +
          'create_time INTEGER)'
      );
      await store.executeSql(
        `CREATE INDEX IF NOT EXISTS idx_pushkit_message_create_time ON ${PushKitPersistentMessageStore.TABLE}(create_time)`
      );
      PushKitPersistentMessageStore.schemaReady = true;
    } catch (error) {
      throw PushKitPersistentMessageStore.errorFrom(error);
    }
  }

  private static notificationId(message: PersistedPushKitMessage): number {
    if (message.messageId.trim().length > 0) {
      return PushKitPersistentMessageStore.hashId(message.messageId);
    }
    if (message.createTime > 0) {
      return message.createTime % 1000000000;
    }
    return Date.now() % 1000000000;
  }

  private static hashId(value: string): number {
    let hash = 0;
    for (let i = 0; i < value.length; i++) {
      hash = ((hash << 5) - hash + value.charCodeAt(i)) | 0;
    }
    return Math.abs(hash % 1000000000);
  }

  private static closeResult(result: relationalStore.ResultSet): void {
    try {
      result.close();
    } catch (_) {
    }
  }

  private static errorText(error: Error | string | number | boolean | Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    return JSON.stringify(error);
  }

  private static errorFrom(error: Error): Error {
    return error;
  }
}
