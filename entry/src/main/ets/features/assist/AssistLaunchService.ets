import common from '@ohos.app.ability.common';
import { Want } from '@kit.AbilityKit';

export class AssistLaunchService {
  static readonly ACTION: string = 'ha.open_assist';
  static readonly START_LISTENING_PARAM: string = 'start_listening';
  static readonly PENDING_START_LISTENING_KEY: string = 'assistPendingStartListening';
  static readonly PENDING_TICK_KEY: string = 'assistPendingLaunchTick';

  static requestFromWant(want: Want): boolean | undefined {
    const params = want.parameters;
    const action = typeof want.action === 'string' ? want.action : '';
    const paramAction = params ? AssistLaunchService.stringParam(params, 'action') : '';
    if (action !== AssistLaunchService.ACTION && paramAction !== AssistLaunchService.ACTION) {
      return undefined;
    }
    return params ? AssistLaunchService.booleanParam(params, AssistLaunchService.START_LISTENING_PARAM, true) : true;
  }

  static publishPending(startListening: boolean = true): void {
    AppStorage.setOrCreate<boolean>(AssistLaunchService.PENDING_START_LISTENING_KEY, startListening);
    const currentTick = AppStorage.get<number>(AssistLaunchService.PENDING_TICK_KEY) ?? 0;
    AppStorage.setOrCreate<number>(AssistLaunchService.PENDING_TICK_KEY, currentTick + 1);
  }

  static clearPending(): void {
    AppStorage.setOrCreate<boolean>(AssistLaunchService.PENDING_START_LISTENING_KEY, true);
    AppStorage.setOrCreate<number>(AssistLaunchService.PENDING_TICK_KEY, 0);
  }

  static async start(context: common.UIAbilityContext, startListening: boolean = true): Promise<void> {
    AssistLaunchService.publishPending(startListening);
    const want: Want = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: context.abilityInfo.name,
      action: AssistLaunchService.ACTION,
      parameters: {
        action: AssistLaunchService.ACTION,
        start_listening: startListening
      }
    };
    try {
      await context.startAbility(want);
    } catch (err) {
      return Promise.reject(err);
    }
  }

  private static stringParam(params: Record<string, Object>, key: string): string {
    const value = params[key];
    return typeof value === 'string' ? value.trim() : '';
  }

  private static booleanParam(params: Record<string, Object>, key: string, fallback: boolean): boolean {
    const value = params[key];
    return typeof value === 'boolean' ? value : fallback;
  }
}
