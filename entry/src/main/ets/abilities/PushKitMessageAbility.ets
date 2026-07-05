import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pushCommon, pushService } from '@kit.PushKit';
import { HomeAssistantNotificationAdapter } from '../features/notifications/HomeAssistantNotificationAdapter';
import { NotificationService } from '../features/notifications/NotificationService';
import { PushKitPersistentMessageStore } from '../features/pushkit/PushKitPersistentMessageStore';

const DOMAIN = 0x0000;
const TAG = 'HAPushKitMessage';
type PushKitMessageType = 'DEFAULT' | 'BACKGROUND';

export default class PushKitMessageAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    PushKitPersistentMessageStore.ensureReady(this.context).catch((error: Error): void => {
      hilog.warn(DOMAIN, TAG, 'prepare Push Kit persistence failed: %{public}s', error.message);
    });
    PushKitPersistentMessageStore.migrateToNotificationHistory(this.context).catch((error: Error): void => {
      hilog.warn(DOMAIN, TAG, 'migrate Push Kit persistence failed: %{public}s', error.message);
    });
    this.registerMessageType('DEFAULT');
    this.registerMessageType('BACKGROUND');
  }

  private registerMessageType(type: PushKitMessageType): void {
    try {
      pushService.receiveMessage(type, this, (payload: pushCommon.PushPayload): void => {
        this.handlePayload(type, payload);
      });
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'register Push Kit message failed: %{public}s %{public}d %{public}s',
        type, err.code, err.message);
    }
  }

  private handlePayload(type: PushKitMessageType, payload: pushCommon.PushPayload): void {
    const localPayload = HomeAssistantNotificationAdapter.fromPayload(payload.data ?? {}, 'pushkit');
    if (!localPayload) {
      return;
    }
    if (type === 'BACKGROUND') {
      NotificationService.recordHomeAssistantNotification(this.context, localPayload)
        .catch((error: Error): void => {
          hilog.warn(DOMAIN, TAG, 'record Push Kit notification failed: %{public}s', error.message);
        });
      return;
    }
    NotificationService.publishHomeAssistantNotification(this.context, localPayload)
      .catch((error: Error): void => {
        hilog.warn(DOMAIN, TAG, 'publish Push Kit notification failed: %{public}s', error.message);
      });
  }
}
