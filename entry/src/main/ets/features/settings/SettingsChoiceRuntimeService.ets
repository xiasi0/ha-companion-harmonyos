import { AppRoute } from '../../app/AppRoute';
import { Localization } from '../../shared/i18n/Localization';
import { SettingChoiceGroup } from './CompanionSettingsData';
import { CompanionChoicePresenter } from './CompanionChoicePresenter';

export interface SettingsChoiceRuntimeState {
  companionChoiceDialogKey: string;
  showCompanionChoiceDialog: boolean;
  screenOrientation: string;
  pageZoomLevel: string;
  appLanguage: string;
  appTheme: string;
  secureConnectionChoice: string;
  websocketMode: string;
  serviceCardUpdateFrequency: string;
  assistWakeWord: string;
  appConfigTick: number;
  step: number;
}

export interface SettingsChoiceRuntimeCallbacks {
  applyWindowPreferences: () => void;
  applyDashboardPreferences: () => void;
  applyThemePreferences: () => void;
  refreshDashboardTheme: () => void;
  refreshCards: () => void;
  refreshHomeNetworkStatus: () => void;
  refreshSettingsState: () => void;
}

export class SettingsChoiceRuntimeService {
  static openDialog(state: SettingsChoiceRuntimeState, key: string): void {
    state.companionChoiceDialogKey = key;
    state.showCompanionChoiceDialog = true;
  }

  static closeDialog(state: SettingsChoiceRuntimeState): void {
    state.showCompanionChoiceDialog = false;
    state.companionChoiceDialogKey = '';
  }

  static dialogTitle(state: SettingsChoiceRuntimeState): string {
    return CompanionChoicePresenter.title(state.companionChoiceDialogKey);
  }

  static groups(state: SettingsChoiceRuntimeState): SettingChoiceGroup[] {
    return CompanionChoicePresenter.groups(state.companionChoiceDialogKey);
  }

  static selectedValue(state: SettingsChoiceRuntimeState): string {
    return CompanionChoicePresenter.selectedValue(state.companionChoiceDialogKey, {
      screenOrientation: state.screenOrientation,
      pageZoomLevel: state.pageZoomLevel,
      appLanguage: state.appLanguage,
      appTheme: state.appTheme,
      secureConnectionChoice: state.secureConnectionChoice
    });
  }

  static selectCompanionChoice(
    state: SettingsChoiceRuntimeState,
    callbacks: SettingsChoiceRuntimeCallbacks,
    value: string
  ): void {
    if (SettingsChoiceRuntimeService.applyDisplayChoice(state, callbacks, state.companionChoiceDialogKey, value)) {
      SettingsChoiceRuntimeService.closeDialog(state);
    }
  }

  static selectSettingsDetailChoice(
    state: SettingsChoiceRuntimeState,
    callbacks: SettingsChoiceRuntimeCallbacks,
    key: string,
    value: string
  ): void {
    if (SettingsChoiceRuntimeService.applyDisplayChoice(state, callbacks, key, value)) {
      state.step = key === 'assist_voice' ? AppRoute.SETTINGS_DETAIL : AppRoute.COMPANION_SETTINGS;
    }
  }

  static applyDisplayChoice(
    state: SettingsChoiceRuntimeState,
    callbacks: SettingsChoiceRuntimeCallbacks,
    key: string,
    value: string
  ): boolean {
    if (key === 'display_orientation') {
      state.screenOrientation = value;
      callbacks.applyWindowPreferences();
      callbacks.refreshSettingsState();
      return true;
    }
    if (key === 'display_zoom') {
      state.pageZoomLevel = value;
      callbacks.applyDashboardPreferences();
      callbacks.refreshSettingsState();
      return true;
    }
    if (key === 'display_language') {
      state.appLanguage = value;
      Localization.setAppLanguage(value);
      state.appConfigTick += 1;
      callbacks.refreshSettingsState();
      return true;
    }
    if (key === 'display_theme') {
      state.appTheme = value;
      callbacks.applyThemePreferences();
      callbacks.applyWindowPreferences();
      callbacks.refreshDashboardTheme();
      callbacks.refreshSettingsState();
      return true;
    }
    if (key === 'server_connection_security') {
      state.secureConnectionChoice = SettingsChoiceRuntimeService.normalizeSecureConnectionChoice(value);
      callbacks.refreshHomeNetworkStatus();
      callbacks.refreshSettingsState();
      return true;
    }
    if (key === 'service_card_update_frequency') {
      state.serviceCardUpdateFrequency = SettingsChoiceRuntimeService.normalizeServiceCardUpdateFrequency(value, state.websocketMode);
      callbacks.refreshCards();
      callbacks.refreshSettingsState();
      return true;
    }
    if (key === 'assist_voice') {
      state.assistWakeWord = SettingsChoiceRuntimeService.normalizeAssistWakeWord(value);
      callbacks.refreshSettingsState();
      return true;
    }
    return false;
  }

  private static normalizeSecureConnectionChoice(value: string): string {
    if (value === 'less') {
      return 'less';
    }
    return 'most';
  }

  private static normalizeServiceCardUpdateFrequency(value: string, websocketMode: string): string {
    if (websocketMode === 'always') {
      return 'default';
    }
    if (value === 'fast' || value === 'normal') {
      return value;
    }
    return 'default';
  }

  private static normalizeAssistWakeWord(value: string): string {
    if (value === 'wake_word_2' || value === 'wake_word_3') {
      return value;
    }
    return 'wake_word_1';
  }
}
