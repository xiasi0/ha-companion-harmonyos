import { Want } from '@kit.AbilityKit';

export class ShortcutLaunchService {
  static readonly OPEN_SETTINGS_ACTION: string = 'open_settings';
  static readonly ACTION_PARAM: string = 'shortcutAction';
  static readonly PENDING_KEY: string = 'shortcutSettingsPending';

  static handleWant(want: Want): boolean {
    const params = want.parameters;
    if (!params) {
      return false;
    }
    const action = ShortcutLaunchService.stringParam(params, ShortcutLaunchService.ACTION_PARAM);
    if (action !== ShortcutLaunchService.OPEN_SETTINGS_ACTION) {
      return false;
    }
    AppStorage.setOrCreate<boolean>(ShortcutLaunchService.PENDING_KEY, true);
    return true;
  }

  private static stringParam(params: Record<string, Object>, key: string): string {
    const value = params[key];
    return typeof value === 'string' ? value.trim() : '';
  }
}
