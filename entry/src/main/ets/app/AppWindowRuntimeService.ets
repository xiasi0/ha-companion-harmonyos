import common from '@ohos.app.ability.common';
import { WindowService } from '../services/WindowService';

export interface AppWindowPreferenceInput {
  context: common.Context;
  screenOrientation: string;
  keepScreenOnEnabled: boolean;
}

export interface AppWindowRuntimeState {
  screenOrientation: string;
  keepScreenOnEnabled: boolean;
  appTheme: string;
  preferredThemeDark: boolean;
  appResolvedDark: boolean;
}

export class AppWindowRuntimeService {
  private static lastAppliedTheme: string = '';
  private static applyingTheme: boolean = false;

  static resolvePreferredThemeDark(context: common.Context, appTheme: string): boolean {
    if (appTheme === 'dark') {
      return true;
    }
    if (appTheme === 'light') {
      return false;
    }
    try {
      const config = context.resourceManager.getConfigurationSync();
      return config.colorMode === 0;
    } catch (_) {
      return false;
    }
  }

  static applyPreferences(input: AppWindowPreferenceInput): void {
    WindowService.applyPreferences({
      context: input.context,
      screenOrientation: input.screenOrientation,
      keepScreenOnEnabled: input.keepScreenOnEnabled
    });
  }

  static preferenceInput(
    context: common.Context,
    state: AppWindowRuntimeState
  ): AppWindowPreferenceInput {
    return {
      context,
      screenOrientation: state.screenOrientation,
      keepScreenOnEnabled: state.keepScreenOnEnabled
    };
  }

  static refreshResolvedTheme(context: common.Context, state: AppWindowRuntimeState): void {
    try {
      state.preferredThemeDark = AppWindowRuntimeService.resolvePreferredThemeDark(context, state.appTheme);
    } catch (_) {
      state.preferredThemeDark = false;
    }
    state.appResolvedDark = state.preferredThemeDark;
  }

  static applyThemePreferences(context: common.Context, state: AppWindowRuntimeState): void {
    if (!AppWindowRuntimeService.applyingTheme && AppWindowRuntimeService.lastAppliedTheme !== state.appTheme) {
      try {
        AppWindowRuntimeService.applyingTheme = true;
        AppWindowRuntimeService.lastAppliedTheme = state.appTheme;
        AppWindowRuntimeService.setApplicationColorMode(context, state.appTheme);
      } catch (_) {
        // Keep the UI usable if color mode cannot be changed.
      } finally {
        AppWindowRuntimeService.applyingTheme = false;
      }
    }
    AppWindowRuntimeService.refreshResolvedTheme(context, state);
  }

  static applyPreferencesForState(
    context: common.Context,
    state: AppWindowRuntimeState
  ): void {
    try {
      AppWindowRuntimeService.applyPreferences(AppWindowRuntimeService.preferenceInput(context, state));
    } catch (_) {
      // Keep the UI usable if the window capability is unavailable.
    }
  }

  static setApplicationColorMode(context: common.Context, appTheme: string): void {
    WindowService.setApplicationColorMode(context, appTheme);
  }
}
