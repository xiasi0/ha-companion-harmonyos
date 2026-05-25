import { Localization } from '../i18n/Localization';

export class AppPromptService {
  private static readonly DEFAULT_DURATION_MS: number = 3000;

  static showInfo(uiContext: UIContext, message: string): void {
    const value = message.trim();
    if (value.length === 0) {
      return;
    }
    try {
      uiContext.getPromptAction().showToast({
        message: value,
        duration: AppPromptService.DEFAULT_DURATION_MS
      });
    } catch (_) {
    }
  }

  static showLocalizedInfo(uiContext: UIContext, key: string): void {
    AppPromptService.showInfo(uiContext, Localization.t(key));
  }

  static showFeatureUnavailable(uiContext: UIContext): void {
    AppPromptService.showLocalizedInfo(uiContext, 'prompt_feature_unavailable');
  }

  static showLearnMoreUnavailable(uiContext: UIContext): void {
    AppPromptService.showLocalizedInfo(uiContext, 'prompt_learn_more_unavailable');
  }
}
