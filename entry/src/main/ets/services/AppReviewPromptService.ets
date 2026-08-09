import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';

export class AppReviewPromptService {
  private static readonly PREFERENCES_NAME: string = 'ha_app_review_prompt';
  private static readonly LAST_ACTIVE_DATE: string = 'last_active_date';
  private static readonly ACTIVE_DAY_STREAK: string = 'active_day_streak';
  private static readonly ATTEMPTED: string = 'attempted';
  private static readonly REQUIRED_ACTIVE_DAY_STREAK: number = 3;

  static async isEligibleAfterDashboardConnection(context: common.Context): Promise<boolean> {
    try {
      const pref = await preferences.getPreferences(context, AppReviewPromptService.PREFERENCES_NAME);
      if (AppReviewPromptService.booleanField(await pref.get(AppReviewPromptService.ATTEMPTED, false))) {
        return false;
      }

      const now = new Date();
      const today = AppReviewPromptService.dateKey(now);
      const lastActiveDate = AppReviewPromptService.stringField(
        await pref.get(AppReviewPromptService.LAST_ACTIVE_DATE, '')
      );
      let streak = AppReviewPromptService.numberField(
        await pref.get(AppReviewPromptService.ACTIVE_DAY_STREAK, 0)
      );
      if (lastActiveDate === today) {
        return streak >= AppReviewPromptService.REQUIRED_ACTIVE_DAY_STREAK;
      }

      streak = lastActiveDate === AppReviewPromptService.previousDateKey(now) ? streak + 1 : 1;
      await pref.put(AppReviewPromptService.LAST_ACTIVE_DATE, today);
      await pref.put(AppReviewPromptService.ACTIVE_DAY_STREAK, streak);
      await pref.flush();
      return streak >= AppReviewPromptService.REQUIRED_ACTIVE_DAY_STREAK;
    } catch (_) {
      return false;
    }
  }

  static async markPromptHandled(context: common.Context): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, AppReviewPromptService.PREFERENCES_NAME);
      await pref.put(AppReviewPromptService.ATTEMPTED, true);
      await pref.flush();
    } catch (_) {
    }
  }

  private static dateKey(date: Date): string {
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
  }

  private static previousDateKey(date: Date): string {
    const previous = new Date(date.getTime());
    previous.setDate(previous.getDate() - 1);
    return AppReviewPromptService.dateKey(previous);
  }

  private static booleanField(value: preferences.ValueType): boolean {
    return value === true;
  }

  private static numberField(value: preferences.ValueType): number {
    return typeof value === 'number' ? value : 0;
  }

  private static stringField(value: preferences.ValueType): string {
    return typeof value === 'string' ? value : '';
  }
}
