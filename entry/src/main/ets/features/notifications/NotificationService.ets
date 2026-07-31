// HarmonyOS notification facade for permission checks, local notifications, and history recording.
// Keep platform notification details contained here for settings and webhook flows.
import common from '@ohos.app.ability.common';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Localization } from '../../shared/i18n/Localization';
import { NotificationRecentRecord, NotificationRecentStore } from './NotificationRecentStore';

const DOMAIN = 0x0000;
const TAG = 'HANotificationService';

export interface NotificationCapability {
  title: string;
  summary: string;
  status: string;
  actionId: string;
}

export interface LocalNotificationPayload {
  id?: number;
  dedupeKey?: string;
  serverInstanceId?: string;
  title: string;
  text: string;
  additionalText?: string;
  source?: string;
  data?: Record<string, string>;
}

export class NotificationService {
  static readonly TEST_NOTIFICATION_ID: number = 1001;
  private static readonly ALERT_SLOT: notificationManager.SlotType = notificationManager.SlotType.SERVICE_INFORMATION;

  static async isEnabled(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (_) {
      return false;
    }
  }

  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(context);
    } catch (error) {
      throw NotificationService.errorFrom(error);
    }
    return await NotificationService.isEnabled();
  }

  static async openSystemSettings(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.openNotificationSettings(context);
    } catch (error) {
      throw NotificationService.errorFrom(error);
    }
    return await NotificationService.isEnabled();
  }

  static async publishLocal(context: common.Context, payload: LocalNotificationPayload): Promise<void> {
    const enabled = await NotificationService.isEnabled();
    if (!enabled) {
      throw new Error(Localization.t('notifications_permission_required'));
    }
    const notificationId = payload.id ?? Date.now() % 1000000000;
    await NotificationService.ensureAlertSlot();
    try {
      await notificationManager.publish({
        id: notificationId,
        notificationSlotType: NotificationService.ALERT_SLOT,
        isAlertOnce: false,
        badgeNumber: 1,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: payload.title,
            text: payload.text,
            additionalText: payload.additionalText ?? payload.source ?? ''
          }
        }
      });
    } catch (error) {
      throw NotificationService.errorFrom(error);
    }
    await NotificationService.saveRecent(context, notificationId, payload);
  }

  static async publishHomeAssistantNotification(context: common.Context, payload: LocalNotificationPayload): Promise<void> {
    await NotificationService.publishLocal(context, {
      id: payload.id,
      dedupeKey: payload.dedupeKey,
      serverInstanceId: payload.serverInstanceId,
      title: payload.title,
      text: payload.text,
      additionalText: payload.additionalText ?? Localization.t('app_name'),
      source: payload.source,
      data: payload.data
    });
  }

  static async recordHomeAssistantNotification(context: common.Context, payload: LocalNotificationPayload): Promise<void> {
    const notificationId = payload.id ?? Date.now() % 1000000000;
    await NotificationService.saveRecent(context, notificationId, {
      id: notificationId,
      dedupeKey: payload.dedupeKey,
      serverInstanceId: payload.serverInstanceId,
      title: payload.title,
      text: payload.text,
      additionalText: payload.additionalText ?? Localization.t('app_name'),
      source: payload.source,
      data: payload.data
    });
  }

  static async publishTestNotification(context: common.UIAbilityContext): Promise<void> {
    const allowed = await NotificationService.requestPermission(context);
    if (!allowed) {
      throw new Error(Localization.t('notifications_permission_denied'));
    }
    await NotificationService.publishHomeAssistantNotification(context, {
      id: Date.now() % 1000000000,
      title: Localization.t('notifications_test_title'),
      text: Localization.t('notifications_test_text'),
      additionalText: Localization.t('app_name')
    });
  }

  static async cancelAll(context: common.Context): Promise<void> {
    try {
      await notificationManager.cancelAll();
      await notificationManager.setBadgeNumber(0);
    } catch (error) {
      throw NotificationService.errorFrom(error);
    }
    await NotificationRecentStore.clear(context);
    NotificationService.updateRuntimeState(0);
  }

  static async listRecent(context: common.Context): Promise<NotificationRecentRecord[]> {
    return NotificationRecentStore.listRecent(context);
  }

  static async markRead(context: common.Context, localId: number): Promise<void> {
    await NotificationRecentStore.markRead(context, localId);
    const unreadCount = await NotificationRecentStore.unreadCount(context);
    NotificationService.updateRuntimeState(unreadCount);
    try {
      await notificationManager.setBadgeNumber(unreadCount);
    } catch (error) {
      throw NotificationService.errorFrom(error);
    }
  }

  private static async ensureAlertSlot(): Promise<void> {
    try {
      await notificationManager.addSlot(NotificationService.ALERT_SLOT);
    } catch (error) {
      throw NotificationService.errorFrom(error);
    }
  }

  private static capability(title: string, summary: string, status: string, actionId: string): NotificationCapability {
    return { title, summary, status, actionId };
  }

  static settings(permissionEnabled: boolean): NotificationCapability[] {
    return [
      NotificationService.capability(
        Localization.t('notifications_history'),
        Localization.t('notifications_history_summary'),
        '',
        'open_notification_history'
      ),
      NotificationService.capability(
        Localization.t('notifications_system_settings'),
        Localization.t('notifications_system_settings_summary'),
        permissionEnabled ? Localization.t('common_enabled') : Localization.t('common_disabled'),
        'open_notification_settings'
      )
    ];
  }

  private static async saveRecent(
    context: common.Context,
    notificationId: number,
    payload: LocalNotificationPayload
  ): Promise<void> {
    try {
      await NotificationRecentStore.add(context, {
        notificationId,
        dedupeKey: payload.dedupeKey ?? '',
        serverInstanceId: payload.serverInstanceId ?? '',
        title: payload.title,
        text: payload.text,
        additionalText: payload.additionalText ?? payload.source ?? '',
        source: payload.source ?? '',
        dataJson: JSON.stringify(payload.data ?? {}),
        receivedAt: Date.now()
      });
      const unreadCount = await NotificationRecentStore.unreadCount(context);
      NotificationService.updateRuntimeState(unreadCount);
      try {
        await notificationManager.setBadgeNumber(unreadCount);
      } catch (error) {
        throw NotificationService.errorFrom(error);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'save recent notification failed: %{public}s', NotificationService.errorText(err));
    }
  }

  private static updateRuntimeState(unreadCount: number): void {
    AppStorage.setOrCreate<number>('notificationUnreadCount', unreadCount);
    const revision = AppStorage.get<number>('notificationHistoryRevision') ?? 0;
    AppStorage.setOrCreate<number>('notificationHistoryRevision', revision + 1);
  }

  private static errorText(err: Error | string | number | boolean | Object): string {
    if (err instanceof Error) {
      return err.message;
    }
    return JSON.stringify(err);
  }

  private static errorFrom(error: Error): Error {
    return error;
  }
}
