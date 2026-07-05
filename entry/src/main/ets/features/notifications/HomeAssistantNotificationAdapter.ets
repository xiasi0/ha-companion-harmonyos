import { LocalNotificationPayload } from './NotificationService';

type JsonValue = Object | string | number | boolean | null;
type JsonRecord = Record<string, JsonValue>;

export class HomeAssistantNotificationAdapter {
  static fromPayload(
    value: Object | string,
    source: string,
    serverInstanceId: string = ''
  ): LocalNotificationPayload | null {
    const record = HomeAssistantNotificationAdapter.recordFrom(value);
    if (!record) {
      return null;
    }
    const event = HomeAssistantNotificationAdapter.notificationRecord(record);
    const text = HomeAssistantNotificationAdapter.message(event);
    if (text.length === 0) {
      return null;
    }
    const title = HomeAssistantNotificationAdapter.title(event);
    const dataRecord = HomeAssistantNotificationAdapter.recordField(event, 'data');
    const dedupeKey = HomeAssistantNotificationAdapter.notificationKey(event);
    const resolvedServerId = HomeAssistantNotificationAdapter.serverInstanceId(event, serverInstanceId);
    const scopedKey = HomeAssistantNotificationAdapter.scopedKey(resolvedServerId, dedupeKey);
    return {
      id: scopedKey.length > 0 ? HomeAssistantNotificationAdapter.hashId(scopedKey) : undefined,
      dedupeKey,
      serverInstanceId: resolvedServerId,
      title: title.length > 0 ? title : 'Home Assistant',
      text,
      additionalText: 'Home Assistant',
      source,
      data: HomeAssistantNotificationAdapter.stringRecord(dataRecord ?? event)
    };
  }

  private static notificationRecord(record: JsonRecord): JsonRecord {
    const data = HomeAssistantNotificationAdapter.recordField(record, 'data');
    if (data && HomeAssistantNotificationAdapter.hasNotificationFields(data)) {
      return data;
    }
    const extraData = HomeAssistantNotificationAdapter.recordField(record, 'extraData');
    if (extraData && HomeAssistantNotificationAdapter.hasNotificationFields(extraData)) {
      return extraData;
    }
    const notification = HomeAssistantNotificationAdapter.recordField(record, 'notification');
    if (notification && HomeAssistantNotificationAdapter.hasNotificationFields(notification)) {
      return notification;
    }
    const aps = HomeAssistantNotificationAdapter.recordField(record, 'aps');
    if (aps && HomeAssistantNotificationAdapter.hasNotificationFields(aps)) {
      return aps;
    }
    return record;
  }

  private static hasNotificationFields(record: JsonRecord): boolean {
    return typeof record['message'] === 'string' ||
      typeof record['title'] === 'string' ||
      typeof record['body'] === 'string' ||
      typeof record['hass_confirm_id'] === 'string' ||
      HomeAssistantNotificationAdapter.recordField(record, 'aps') !== null ||
      HomeAssistantNotificationAdapter.recordField(record, 'notification') !== null;
  }

  private static title(record: JsonRecord): string {
    const title = HomeAssistantNotificationAdapter.stringField(record, 'title');
    if (title.length > 0) {
      return title;
    }
    const alert = HomeAssistantNotificationAdapter.alert(record);
    return alert ? HomeAssistantNotificationAdapter.stringField(alert, 'title') : '';
  }

  private static message(record: JsonRecord): string {
    const message = HomeAssistantNotificationAdapter.stringField(record, 'message');
    if (message.length > 0) {
      return message;
    }
    const body = HomeAssistantNotificationAdapter.stringField(record, 'body');
    if (body.length > 0) {
      return body;
    }
    const alert = HomeAssistantNotificationAdapter.alert(record);
    if (alert) {
      return HomeAssistantNotificationAdapter.stringField(alert, 'body');
    }
    const aps = HomeAssistantNotificationAdapter.recordField(record, 'aps');
    if (!aps) {
      return '';
    }
    const rawAlert = aps['alert'];
    return typeof rawAlert === 'string' ? rawAlert.trim() : '';
  }

  private static alert(record: JsonRecord): JsonRecord | null {
    const aps = HomeAssistantNotificationAdapter.recordField(record, 'aps');
    return aps ? HomeAssistantNotificationAdapter.recordField(aps, 'alert') : null;
  }

  private static notificationKey(record: JsonRecord): string {
    return HomeAssistantNotificationAdapter.firstString(record, [
      'message_id',
      'messageId',
      'hass_confirm_id',
      'tag'
    ]);
  }

  private static serverInstanceId(record: JsonRecord, fallback: string): string {
    const explicit = HomeAssistantNotificationAdapter.firstString(record, [
      'server_instance_id',
      'serverInstanceId',
      'pushkit_server_instance_id',
      'webhook_id',
      'webhookId'
    ]);
    return explicit.length > 0 ? explicit : fallback.trim();
  }

  private static scopedKey(serverInstanceId: string, dedupeKey: string): string {
    if (dedupeKey.length === 0) {
      return '';
    }
    const serverKey = serverInstanceId.trim();
    return serverKey.length > 0 ? `${serverKey}:${dedupeKey}` : dedupeKey;
  }

  private static firstString(record: JsonRecord, keys: string[]): string {
    for (let i = 0; i < keys.length; i++) {
      const value = HomeAssistantNotificationAdapter.stringField(record, keys[i]);
      if (value.length > 0) {
        return value;
      }
    }
    return '';
  }

  private static recordFrom(value: Object | string): JsonRecord | null {
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed.length === 0) {
        return null;
      }
      try {
        return JSON.parse(trimmed) as JsonRecord;
      } catch (_) {
        const result: JsonRecord = {};
        result['message'] = trimmed;
        return result;
      }
    }
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as JsonRecord;
    }
    return null;
  }

  private static recordField(source: JsonRecord, key: string): JsonRecord | null {
    const value = source[key];
    if (typeof value === 'string') {
      return HomeAssistantNotificationAdapter.recordFrom(value);
    }
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
      return value as JsonRecord;
    }
    return null;
  }

  private static stringField(source: JsonRecord, key: string): string {
    const value = source[key];
    return typeof value === 'string' ? value.trim() : '';
  }

  private static stringRecord(source: JsonRecord): Record<string, string> {
    const result: Record<string, string> = {};
    const keys = Object.keys(source);
    for (let i = 0; i < keys.length; i++) {
      const value = source[keys[i]];
      if (typeof value === 'string') {
        result[keys[i]] = value;
      } else if (typeof value === 'number' || typeof value === 'boolean') {
        result[keys[i]] = `${value}`;
      }
    }
    return result;
  }

  private static hashId(value: string): number {
    let hash = 0;
    for (let i = 0; i < value.length; i++) {
      hash = ((hash << 5) - hash + value.charCodeAt(i)) | 0;
    }
    return Math.abs(hash % 1000000000);
  }
}
