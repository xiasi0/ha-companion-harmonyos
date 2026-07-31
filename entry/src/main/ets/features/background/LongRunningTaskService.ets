import common from '@ohos.app.ability.common';
import { wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'HALongRunningTask';

type LongRunningRecoveryHandler = (context: common.UIAbilityContext) => void;

export class LongRunningTaskService {
  private static readonly AUDIO_RECORDING_MODE: string = 'audioRecording';
  private static readonly DATA_TRANSFER_MODE: string = 'dataTransfer';
  private static readonly LOCATION_MODE: string = 'location';
  private static running = false;
  private static starting: Promise<void> | undefined = undefined;
  private static context: common.UIAbilityContext | undefined = undefined;
  private static continuousTaskId = -1;
  private static notificationId = -1;
  private static listenersRegistered = false;
  private static recovering = false;
  private static recoveryHandler: LongRunningRecoveryHandler | undefined = undefined;
  private static requestedModes: string[] = [];

  static setRecoveryHandler(handler: LongRunningRecoveryHandler): void {
    LongRunningTaskService.recoveryHandler = handler;
  }

  static async start(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.ensureDataTransferActive(context);
  }

  static async ensureLocationActive(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.ensureMode(context, LongRunningTaskService.LOCATION_MODE);
  }

  static async ensureAudioRecordingActive(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.ensureMode(context, LongRunningTaskService.AUDIO_RECORDING_MODE);
  }

  static async stopAudioRecording(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.stopMode(context, LongRunningTaskService.AUDIO_RECORDING_MODE);
  }

  static async stopLocation(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.stopMode(context, LongRunningTaskService.LOCATION_MODE);
  }

  static async ensureDataTransferActive(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.ensureMode(context, LongRunningTaskService.DATA_TRANSFER_MODE);
  }

  static async stopDataTransfer(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.stopMode(context, LongRunningTaskService.DATA_TRANSFER_MODE);
  }

  private static async ensureMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    LongRunningTaskService.context = context;
    LongRunningTaskService.registerSystemListeners();
    LongRunningTaskService.addRequestedMode(mode);
    if (LongRunningTaskService.starting) {
      return LongRunningTaskService.starting;
    }
    if (await LongRunningTaskService.isActive(context)) {
      LongRunningTaskService.running = true;
      return;
    }
    LongRunningTaskService.starting = LongRunningTaskService.startInternal(context);
    try {
      await LongRunningTaskService.starting;
    } finally {
      LongRunningTaskService.starting = undefined;
    }
  }

  static async ensureRunning(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.ensureActive(context);
  }

  static async ensureActive(context: common.UIAbilityContext): Promise<void> {
    await LongRunningTaskService.ensureDataTransferActive(context);
  }

  static async recover(context: common.UIAbilityContext): Promise<void> {
    LongRunningTaskService.context = context;
    await LongRunningTaskService.stopNative(context);
    LongRunningTaskService.clearState();
    await LongRunningTaskService.startInternal(context);
  }

  static async stop(context: common.UIAbilityContext): Promise<void> {
    LongRunningTaskService.requestedModes = [];
    await LongRunningTaskService.stopNative(context);
    LongRunningTaskService.clearState();
  }

  private static async stopMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    LongRunningTaskService.context = context;
    LongRunningTaskService.removeRequestedMode(mode);
    if (LongRunningTaskService.requestedModes.length === 0) {
      await LongRunningTaskService.stop(context);
      return;
    }
    await LongRunningTaskService.stopNative(context);
    LongRunningTaskService.clearState();
    await LongRunningTaskService.startInternal(context);
  }

  static async isActive(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const tasks = await backgroundTaskManager.getAllContinuousTasks(context, true);
      for (let i = 0; i < tasks.length; i++) {
        const task = tasks[i];
        if (task.abilityName !== context.abilityInfo.name) {
          continue;
        }
        if (!LongRunningTaskService.hasRequestedModes(task.backgroundModes)) {
          continue;
        }
        LongRunningTaskService.continuousTaskId = task.continuousTaskId;
        LongRunningTaskService.notificationId = task.notificationId;
        LongRunningTaskService.running = !task.suspendState;
        return !task.suspendState;
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'get continuous task info failed: %{public}s', LongRunningTaskService.errorText(err));
      return LongRunningTaskService.running;
    }
    LongRunningTaskService.clearState();
    return false;
  }

  private static async startInternal(context: common.UIAbilityContext): Promise<void> {
    if (LongRunningTaskService.requestedModes.length === 0) {
      LongRunningTaskService.running = false;
      return;
    }
    await LongRunningTaskService.stopNative(context);
    const notification = await LongRunningTaskService.startBackgroundRunning(context);
    LongRunningTaskService.continuousTaskId = notification.continuousTaskId ?? -1;
    LongRunningTaskService.notificationId = notification.notificationId;
    LongRunningTaskService.running = true;
    hilog.info(DOMAIN, TAG, 'continuous task started. taskId=%{public}d notificationId=%{public}d',
      LongRunningTaskService.continuousTaskId, LongRunningTaskService.notificationId);
  }

  private static registerSystemListeners(): void {
    if (LongRunningTaskService.listenersRegistered) {
      return;
    }
    try {
      backgroundTaskManager.on('continuousTaskCancel', (info): void => {
        LongRunningTaskService.handleCancel(info);
      });
      backgroundTaskManager.on('continuousTaskSuspend', (info): void => {
        LongRunningTaskService.handleSuspend(info);
      });
      backgroundTaskManager.on('continuousTaskActive', (info): void => {
        LongRunningTaskService.handleActive(info);
      });
      LongRunningTaskService.listenersRegistered = true;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'register continuous task listeners failed: %{public}s',
        LongRunningTaskService.errorText(err));
    }
  }

  private static async startBackgroundRunning(
    context: common.UIAbilityContext
  ): Promise<backgroundTaskManager.ContinuousTaskNotification> {
    try {
      const agent = await wantAgent.getWantAgent({
        wants: [{
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 735002,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
      return await backgroundTaskManager.startBackgroundRunning(
        context,
        LongRunningTaskService.requestedModes,
        agent
      );
    } catch (error) {
      throw LongRunningTaskService.errorFrom(error);
    }
  }

  private static handleCancel(info: backgroundTaskManager.ContinuousTaskCancelInfo): void {
    if (!LongRunningTaskService.matchesTask(info.id)) {
      return;
    }
    hilog.warn(DOMAIN, TAG, 'continuous task cancelled. id=%{public}d reason=%{public}d', info.id, info.reason);
    LongRunningTaskService.clearState();
    if (LongRunningTaskService.isUserCancelReason(info.reason) && LongRunningTaskService.requestedModes.length === 0) {
      return;
    }
    LongRunningTaskService.recoverSoon();
  }

  private static handleSuspend(info: backgroundTaskManager.ContinuousTaskSuspendInfo): void {
    if (!LongRunningTaskService.matchesTask(info.continuousTaskId)) {
      return;
    }
    hilog.warn(DOMAIN, TAG, 'continuous task suspended. id=%{public}d reason=%{public}d',
      info.continuousTaskId, info.suspendReason);
    LongRunningTaskService.running = false;
    LongRunningTaskService.recoverSoon();
  }

  private static handleActive(info: backgroundTaskManager.ContinuousTaskActiveInfo): void {
    if (!LongRunningTaskService.matchesTask(info.id)) {
      return;
    }
    LongRunningTaskService.continuousTaskId = info.id;
    LongRunningTaskService.running = true;
    hilog.info(DOMAIN, TAG, 'continuous task active. id=%{public}d', info.id);
    const context = LongRunningTaskService.context;
    if (context && LongRunningTaskService.recoveryHandler) {
      LongRunningTaskService.recoveryHandler(context);
    }
  }

  private static recoverSoon(): void {
    const context = LongRunningTaskService.context;
    if (!context || LongRunningTaskService.recovering) {
      return;
    }
    LongRunningTaskService.recovering = true;
    setTimeout((): void => {
      LongRunningTaskService.recovering = false;
      LongRunningTaskService.startInternal(context)
        .then((): void => {
          if (LongRunningTaskService.recoveryHandler) {
            LongRunningTaskService.recoveryHandler(context);
          }
        })
        .catch((err: Error): void => {
          hilog.warn(DOMAIN, TAG, 'continuous task recover failed: %{public}s', err.message);
        });
    }, 1000);
  }

  private static async stopNative(context: common.UIAbilityContext): Promise<void> {
    if (LongRunningTaskService.continuousTaskId > 0) {
      await backgroundTaskManager.stopBackgroundRunning(context, LongRunningTaskService.continuousTaskId)
        .catch((): Promise<void> => backgroundTaskManager.stopBackgroundRunning(context).catch((): void => {}));
      return;
    }
    await backgroundTaskManager.stopBackgroundRunning(context).catch((): void => {});
  }

  private static hasRequestedModes(modes: string[]): boolean {
    for (let i = 0; i < LongRunningTaskService.requestedModes.length; i++) {
      let found = false;
      for (let j = 0; j < modes.length; j++) {
        if (modes[j] === LongRunningTaskService.requestedModes[i]) {
          found = true;
          break;
        }
      }
      if (!found) {
        return false;
      }
    }
    return true;
  }

  private static addRequestedMode(mode: string): void {
    if (LongRunningTaskService.requestedModes.indexOf(mode) >= 0) {
      return;
    }
    LongRunningTaskService.requestedModes.push(mode);
  }

  private static removeRequestedMode(mode: string): void {
    LongRunningTaskService.requestedModes = LongRunningTaskService.requestedModes.filter((item: string): boolean => item !== mode);
  }

  private static matchesTask(id: number): boolean {
    return LongRunningTaskService.continuousTaskId <= 0 || LongRunningTaskService.continuousTaskId === id;
  }

  private static isUserCancelReason(reason: backgroundTaskManager.ContinuousTaskCancelReason): boolean {
    return reason === backgroundTaskManager.ContinuousTaskCancelReason.USER_CANCEL ||
      reason === backgroundTaskManager.ContinuousTaskCancelReason.USER_CANCEL_REMOVE_NOTIFICATION;
  }

  private static clearState(): void {
    LongRunningTaskService.running = false;
    LongRunningTaskService.continuousTaskId = -1;
    LongRunningTaskService.notificationId = -1;
  }

  private static errorText(err: Error | string | number | boolean | Object): string {
    if (err instanceof Error && err.message) {
      return err.message;
    }
    try {
      return JSON.stringify(err);
    } catch (_) {
      return `${err}`;
    }
  }

  private static errorFrom(error: Error): Error {
    return error;
  }
}
