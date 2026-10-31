import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';

export class DashboardNoticeService {
  private static readonly PREFERENCES_NAME: string = 'ha_dashboard_notice';
  private static readonly ACKNOWLEDGED: string = 'acknowledged';

  static async isAcknowledged(context: common.Context): Promise<boolean> {
    try {
      const pref = await preferences.getPreferences(context, DashboardNoticeService.PREFERENCES_NAME);
      return (await pref.get(DashboardNoticeService.ACKNOWLEDGED, false)) === true;
    } catch (_) {
      return false;
    }
  }

  static async acknowledge(context: common.Context): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, DashboardNoticeService.PREFERENCES_NAME);
      await pref.put(DashboardNoticeService.ACKNOWLEDGED, true);
      await pref.flush();
    } catch (_) {
    }
  }
}
