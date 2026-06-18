import { Localization } from '../../shared/i18n/Localization';

export interface SettingChoiceOption {
  value: string;
  title: string;
  summary: string;
}

export interface SettingChoiceGroup {
  title: string;
  options: SettingChoiceOption[];
}

export interface GestureSettingItem {
  key: string;
  title: string;
  summary: string;
}

export interface GestureSettingGroup {
  title: string;
  items: GestureSettingItem[];
}

export class CompanionSettingsData {
  static orientationOptions(): SettingChoiceGroup[] {
    const options: SettingChoiceOption[] = [
      { value: 'system', title: Localization.t('orientation_follow_system'), summary: '' },
      { value: 'landscape', title: Localization.t('orientation_landscape'), summary: '' },
      { value: 'portrait', title: Localization.t('orientation_portrait'), summary: '' }
    ];
    const groups: SettingChoiceGroup[] = [{ title: '', options }];
    return groups;
  }

  static pageZoomOptions(): SettingChoiceGroup[] {
    const values: string[] = ['50', '75', '85', '100', '115', '125', '150', '175', '200'];
    const options: SettingChoiceOption[] = values.map((value: string): SettingChoiceOption => {
      return {
        value,
        title: value === '100' ? Localization.t('page_zoom_default') : `${value}%`,
        summary: ''
      };
    });
    const groups: SettingChoiceGroup[] = [{ title: '', options }];
    return groups;
  }

  static languageOptions(): SettingChoiceGroup[] {
    const summary = Localization.t('language_warning');
    const options: SettingChoiceOption[] = [
      { value: 'default', title: Localization.t('language_follow_system'), summary },
      { value: 'zh-Hans', title: Localization.t('language_zh_hans'), summary },
      { value: 'en', title: 'English', summary }
    ];
    const groups: SettingChoiceGroup[] = [{ title: '', options }];
    return groups;
  }

  static themeOptions(): SettingChoiceGroup[] {
    const options: SettingChoiceOption[] = [
      { value: 'system', title: Localization.t('theme_follow_system'), summary: '' },
      { value: 'light', title: Localization.t('theme_light'), summary: '' },
      { value: 'dark', title: Localization.t('theme_dark'), summary: '' }
    ];
    const groups: SettingChoiceGroup[] = [{ title: '', options }];
    return groups;
  }

  static secureConnectionOptions(): SettingChoiceGroup[] {
    const options: SettingChoiceOption[] = [
      { value: 'most', title: Localization.t('secure_option_most'), summary: '' },
      { value: 'less', title: Localization.t('secure_option_less'), summary: '' }
    ];
    const groups: SettingChoiceGroup[] = [{ title: '', options }];
    return groups;
  }

  static serviceCardUpdateFrequencyOptions(): SettingChoiceGroup[] {
    const options: SettingChoiceOption[] = [
      {
        value: 'default',
        title: Localization.t('service_card_update_frequency_default'),
        summary: Localization.t('service_card_update_frequency_default_summary')
      },
      {
        value: 'fast',
        title: Localization.t('service_card_update_frequency_fast'),
        summary: Localization.t('service_card_update_frequency_fast_summary')
      },
      {
        value: 'normal',
        title: Localization.t('service_card_update_frequency_normal'),
        summary: Localization.t('service_card_update_frequency_normal_summary')
      }
    ];
    const groups: SettingChoiceGroup[] = [{ title: '', options }];
    return groups;
  }

  static assistWakeWordOptions(): SettingChoiceGroup[] {
    const options: SettingChoiceOption[] = [
      { value: 'wake_word_1', title: Localization.t('assist_wake_word_1'), summary: '' },
      { value: 'wake_word_2', title: Localization.t('assist_wake_word_2'), summary: '' },
      { value: 'wake_word_3', title: Localization.t('assist_wake_word_3'), summary: '' }
    ];
    const groups: SettingChoiceGroup[] = [{ title: Localization.t('assist_wake_word'), options }];
    return groups;
  }

  static gestureActionGroups(): SettingChoiceGroup[] {
    const noneOptions: SettingChoiceOption[] = [
      { value: 'none', title: Localization.t('gesture_none'), summary: '' }
    ];
    const frontendOptions: SettingChoiceOption[] = [
      { value: 'quickbar_default', title: Localization.t('gesture_search'), summary: '' },
      { value: 'quickbar_entities', title: Localization.t('gesture_search_entities'), summary: '' },
      { value: 'quickbar_devices', title: Localization.t('gesture_search_devices'), summary: '' },
      { value: 'quickbar_commands', title: Localization.t('gesture_search_commands'), summary: '' },
      { value: 'show_sidebar', title: Localization.t('gesture_show_sidebar'), summary: '' },
      { value: 'open_assist', title: Localization.t('gesture_open_assist'), summary: '' }
    ];
    const navigationOptions: SettingChoiceOption[] = [
      { value: 'navigate_forward', title: Localization.t('gesture_next_page'), summary: '' },
      { value: 'navigate_dashboard', title: Localization.t('gesture_default_dashboard'), summary: '' },
      { value: 'navigate_reload', title: Localization.t('gesture_reload_page'), summary: '' }
    ];
    const appOptions: SettingChoiceOption[] = [
      { value: 'open_app_settings', title: Localization.t('gesture_open_app_settings'), summary: '' },
      { value: 'open_app_developer', title: Localization.t('gesture_open_troubleshooting'), summary: '' }
    ];
    const groups: SettingChoiceGroup[] = [
      { title: '', options: noneOptions },
      { title: 'Home Assistant', options: frontendOptions },
      { title: Localization.t('gesture_navigation'), options: navigationOptions },
      { title: Localization.t('gesture_app'), options: appOptions }
    ];
    return groups;
  }

  static gestureGroups(resolveAction: (key: string) => string): GestureSettingGroup[] {
    const leftItems: GestureSettingItem[] = [
      { key: 'swipe_left_two', title: Localization.t('gesture_two_fingers'), summary: resolveAction('swipe_left_two') },
      { key: 'swipe_left_three', title: Localization.t('gesture_three_fingers'), summary: resolveAction('swipe_left_three') }
    ];
    const rightItems: GestureSettingItem[] = [
      { key: 'swipe_right_two', title: Localization.t('gesture_two_fingers'), summary: resolveAction('swipe_right_two') },
      { key: 'swipe_right_three', title: Localization.t('gesture_three_fingers'), summary: resolveAction('swipe_right_three') }
    ];
    const upItems: GestureSettingItem[] = [
      { key: 'swipe_up_two', title: Localization.t('gesture_two_fingers'), summary: resolveAction('swipe_up_two') },
      { key: 'swipe_up_three', title: Localization.t('gesture_three_fingers'), summary: resolveAction('swipe_up_three') }
    ];
    const downItems: GestureSettingItem[] = [
      { key: 'swipe_down_two', title: Localization.t('gesture_two_fingers'), summary: resolveAction('swipe_down_two') },
      { key: 'swipe_down_three', title: Localization.t('gesture_three_fingers'), summary: resolveAction('swipe_down_three') }
    ];
    const groups: GestureSettingGroup[] = [
      { title: Localization.t('gesture_swipe_left'), items: leftItems },
      { title: Localization.t('gesture_swipe_right'), items: rightItems },
      { title: Localization.t('gesture_swipe_up'), items: upItems },
      { title: Localization.t('gesture_swipe_down'), items: downItems }
    ];
    return groups;
  }

  static gestureTitle(key: string): string {
    if (key === 'swipe_left_two') {
      return Localization.t('gesture_swipe_left_two');
    }
    if (key === 'swipe_left_three') {
      return Localization.t('gesture_swipe_left_three');
    }
    if (key === 'swipe_right_two') {
      return Localization.t('gesture_swipe_right_two');
    }
    if (key === 'swipe_right_three') {
      return Localization.t('gesture_swipe_right_three');
    }
    if (key === 'swipe_up_two') {
      return Localization.t('gesture_swipe_up_two');
    }
    if (key === 'swipe_up_three') {
      return Localization.t('gesture_swipe_up_three');
    }
    if (key === 'swipe_down_two') {
      return Localization.t('gesture_swipe_down_two');
    }
    if (key === 'swipe_down_three') {
      return Localization.t('gesture_swipe_down_three');
    }
    return Localization.t('settings_gestures');
  }

  static gestureDescription(): string {
    return Localization.t('gesture_description');
  }

  static gestureActionTitle(value: string): string {
    const groups = CompanionSettingsData.gestureActionGroups();
    for (let i = 0; i < groups.length; i += 1) {
      const options = groups[i].options;
      for (let j = 0; j < options.length; j += 1) {
        if (options[j].value === value) {
          return options[j].title;
        }
      }
    }
    return Localization.t('gesture_none');
  }

  static orientationSummary(value: string): string {
    if (value === 'portrait') {
      return Localization.t('orientation_portrait');
    }
    if (value === 'landscape') {
      return Localization.t('orientation_landscape');
    }
    return Localization.t('orientation_follow_system');
  }

  static pageZoomSummary(value: string): string {
    return value === '100' ? Localization.t('page_zoom_default') : `${value}%`;
  }

  static languageSummary(value: string): string {
    if (value === 'zh-Hans') {
      return Localization.t('language_zh_hans');
    }
    if (value === 'en') {
      return 'English';
    }
    return Localization.t('language_follow_system');
  }

  static themeSummary(value: string): string {
    if (value === 'dark') {
      return Localization.t('theme_dark');
    }
    if (value === 'system') {
      return Localization.t('theme_follow_system');
    }
    return Localization.t('theme_light');
  }

  static serviceCardUpdateFrequencySummary(value: string): string {
    if (value === 'fast') {
      return Localization.t('service_card_update_frequency_fast');
    }
    if (value === 'normal') {
      return Localization.t('service_card_update_frequency_normal');
    }
    return Localization.t('service_card_update_frequency_default');
  }

  static assistWakeWordSummary(value: string): string {
    if (value === 'wake_word_2') {
      return Localization.t('assist_wake_word_2');
    }
    if (value === 'wake_word_3') {
      return Localization.t('assist_wake_word_3');
    }
    return Localization.t('assist_wake_word_1');
  }

  static assistSummary(wakeDetectionEnabled: boolean, wakeWord: string): string {
    if (!wakeDetectionEnabled) {
      return Localization.t('assist_wake_word_disabled');
    }
    return CompanionSettingsData.assistWakeWordSummary(wakeWord);
  }

  static assistProbabilityCutoffSummary(value: string): string {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : Localization.t('common_not_set');
  }
}
