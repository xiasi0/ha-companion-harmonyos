import {
  HdsNavigationBackButtonItemOptions,
  HdsNavigationMenuContentOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitle,
  HdsNavigationTitleBarStyle,
  HdsNavigationTitleBarOptions,
  IconStyleMode,
  ScrollEffectOptions,
  ScrollEffectType,
  TitleBarContentOptions,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import { HaColors } from '../../../shared/constants/HaStyle';
import { HaTheme } from '../../../shared/theme/HaTheme';

export interface SettingsPadding {
  left: number;
  right: number;
  top?: number;
  bottom?: number;
}

export interface SettingsShadowOptions {
  radius: number;
  color: string;
  offsetX: number;
  offsetY: number;
}

export interface SettingsTitleBarMenuAction {
  icon: Resource | SymbolGlyphModifier;
  label: ResourceStr;
  action: () => void;
  isEnabled?: boolean;
}

export class SettingsUiConfig {
  static readonly contentMaxWidth: number = 720;
  static readonly listSpace: number = 4;
  static readonly titleBarBackground: string = HaColors.SURFACE;
  static readonly pageBackground: string = HaColors.SETTINGS_PAGE_BACKGROUND;
  static readonly transparentBackground: string = HaColors.TRANSPARENT;
  static readonly listContentEndOffset: number = 50;
  static readonly groupRadius: number = 24;
  static readonly groupPadding: number = 4;
  static readonly rowMinHeight: number = 72;
  static readonly rowRadius: number = 24;
  static readonly cardButtonSize: number = 48;
  static readonly cardButtonRadius: number = 24;
  static readonly iconReservedWidth: number = 56;
  static readonly dividerInsetLeft: number = 68;
  static readonly dividerInsetRight: number = 12;
  static readonly cardShadowColor: string = HaColors.SETTINGS_CARD_SHADOW;
  static readonly brandColor: string = HaColors.BRAND;
  static readonly accentColor: string = HaColors.SETTINGS_ACCENT;
  static readonly notificationEventColor: string = HaColors.SETTINGS_NOTIFICATION_EVENT;
  static readonly buttonTextOnAccent: string = HaColors.ON_PRIMARY;
  static readonly dialogMaskColor: string = HaColors.SCRIM;
  static readonly optionOutlineColor: string = HaColors.SETTINGS_OPTION_OUTLINE;
  static readonly websocketDividerColor: string = HaColors.SETTINGS_WEBSOCKET_DIVIDER;
  static readonly noticeBackgroundColor: string = HaColors.SETTINGS_NOTICE_BACKGROUND;
  static readonly formInputHeight: number = 50;
  static readonly formInputRadius: number = 4;
  static readonly formInputBorderWidth: number = 1;

  static listPadding(): SettingsPadding {
    return { left: 12, right: 12, top: 0, bottom: 0 };
  }

  static scrollContentPadding(): SettingsPadding {
    return { left: 12, right: 12, top: 0, bottom: 32 };
  }

  static groupShadow(): SettingsShadowOptions {
    return { radius: 8, color: SettingsUiConfig.cardShadowColor, offsetX: 0, offsetY: 2 };
  }

  static rowPadding(): SettingsPadding {
    return { left: 12, right: 12, top: 10, bottom: 10 };
  }

  static categoryPadding(): SettingsPadding {
    return { left: 12, right: 12, top: 4, bottom: 0 };
  }

  static dividerPadding(): SettingsPadding {
    return { left: SettingsUiConfig.dividerInsetLeft, right: SettingsUiConfig.dividerInsetRight };
  }

  static pressedBackground(isDark: boolean): string {
    return isDark ? HaColors.SETTINGS_PRESSED_BACKGROUND_DARK : HaColors.SETTINGS_PRESSED_BACKGROUND;
  }

  static cardButtonBackground(isDark: boolean): string {
    return HaTheme.surface(isDark);
  }

  static cardButtonForeground(isDark: boolean): string {
    return HaTheme.textPrimary(isDark);
  }

  static scrollBarState(): BarState {
    return BarState.Auto;
  }

  private static titleBarQuestionAction(onHelp?: () => void): SettingsTitleBarMenuAction {
    return {
      icon: $r('sys.symbol.questionmark_circle'),
      label: '?',
      action: onHelp ?? ((): void => {}),
      isEnabled: onHelp !== undefined
    };
  }

  private static titleBarBackIcon(onBack?: () => void): HdsNavigationBackButtonItemOptions {
    return {
      action: onBack
    };
  }

  private static titleBarVisualStyle(isDark: boolean): HdsNavigationTitleBarStyle {
    return {
      backgroundStyle: {
        backgroundColor: HaTheme.groupedBackground(isDark)
      },
      contentStyle: {
        titleStyle: {
          mainTitleColor: HaTheme.textPrimary(isDark),
          subTitleColor: HaTheme.textSecondary(isDark)
        },
        menuStyle: {
          backgroundColor: HaTheme.surface(isDark),
          iconColor: HaTheme.topBarIcon(isDark),
          textColor: HaTheme.topBarIcon(isDark)
        },
        backIconStyle: {
          backgroundColor: HaTheme.surface(isDark),
          iconColor: HaTheme.topBarIcon(isDark),
          textColor: HaTheme.topBarIcon(isDark)
        }
      }
    };
  }

  private static titleBarStyle(isDark: boolean): TitleBarStyleOptions {
    const scrollEffectOpts: ScrollEffectOptions = {
      enableScrollEffect: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR
    };
    const style = SettingsUiConfig.titleBarVisualStyle(isDark);
    return {
      scrollEffectOpts: scrollEffectOpts,
      originalStyle: style,
      scrollEffectStyle: style
    };
  }

  private static titleBarTitle(title: string): HdsNavigationTitle {
    return { mainTitle: title };
  }

  private static titleBarMenuValue(action: SettingsTitleBarMenuAction): HdsNavigationMenuItemOptions {
    return {
      content: {
        icon: action.icon,
        label: action.label,
        type: IconStyleMode.NORMAL,
        isEnabled: action.isEnabled,
        action: action.action
      }
    };
  }

  private static titleBarMenu(
    values: Array<HdsNavigationMenuItemOptions>,
    maxCount: number
  ): HdsNavigationMenuContentOptions {
    return {
      value: values,
      maxCount: maxCount
    };
  }

  private static titleBarOptions(
    content: TitleBarContentOptions,
    isDark: boolean
  ): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: SettingsUiConfig.titleBarStyle(isDark),
      content: content
    };
  }

  static titleBar(
    title: string,
    onBack?: () => void,
    isDark: boolean = false,
    onHelp?: () => void,
    menuAction?: SettingsTitleBarMenuAction
  ): HdsNavigationTitleBarOptions {
    if (menuAction) {
      const questionAction = SettingsUiConfig.titleBarQuestionAction(onHelp);
      const content: TitleBarContentOptions = {
        title: SettingsUiConfig.titleBarTitle(title),
        backIcon: SettingsUiConfig.titleBarBackIcon(onBack),
        menu: SettingsUiConfig.titleBarMenu([
          SettingsUiConfig.titleBarMenuValue(menuAction),
          SettingsUiConfig.titleBarMenuValue(questionAction)
        ], 2)
      };
      return SettingsUiConfig.titleBarOptions(content, isDark);
    }
    const content: TitleBarContentOptions = {
      title: SettingsUiConfig.titleBarTitle(title),
      backIcon: SettingsUiConfig.titleBarBackIcon(onBack),
      menu: SettingsUiConfig.titleBarMenu([SettingsUiConfig.titleBarMenuValue(SettingsUiConfig.titleBarQuestionAction(onHelp))], 1)
    };
    return SettingsUiConfig.titleBarOptions(content, isDark);
  }

  static rootTitleBar(title: string, onBack?: () => void, isDark: boolean = false): HdsNavigationTitleBarOptions {
    const content: TitleBarContentOptions = {
      title: SettingsUiConfig.titleBarTitle(title),
      backIcon: SettingsUiConfig.titleBarBackIcon(onBack)
    };
    return SettingsUiConfig.titleBarOptions(content, isDark);
  }

}
