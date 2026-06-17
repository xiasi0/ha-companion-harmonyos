import { HaColors } from '../constants/HaStyle';

export class HaTheme {
  static readonly DARK_BACKGROUND: string = '#111111';
  static readonly DARK_SURFACE: string = '#1C1C1C';
  static readonly DARK_SURFACE_MUTED: string = '#1B1B1B';
  static readonly DARK_SURFACE_STRONG: string = '#202124';
  static readonly DARK_TEXT_PRIMARY: string = '#F5F7F8';
  static readonly DARK_TEXT_SECONDARY: string = '#B0BEC5';
  static readonly DARK_TEXT_MUTED: string = '#8B98A0';
  static readonly DARK_DIVIDER: string = '#2B2B2B';
  static readonly DARK_OUTLINE: string = '#3A3A3A';
  static readonly DARK_CHIP: string = '#1F2930';
  static readonly DARK_CHIP_OK: string = '#11343C';
  static readonly DARK_CHIP_WARN: string = '#3B2525';

  static background(isDark: boolean): string {
    return isDark ? HaTheme.DARK_BACKGROUND : '#FFFFFF';
  }

  static groupedBackground(isDark: boolean): string {
    return isDark ? HaTheme.DARK_BACKGROUND : '#F2F3F5';
  }

  static surface(isDark: boolean): string {
    return isDark ? HaTheme.DARK_SURFACE : '#FFFFFF';
  }

  static surfaceMuted(isDark: boolean): string {
    return isDark ? HaTheme.DARK_SURFACE_MUTED : '#F5F7F8';
  }

  static surfaceStrong(isDark: boolean): string {
    return isDark ? HaTheme.DARK_SURFACE_STRONG : '#EDF2F7';
  }

  static textPrimary(isDark: boolean): string {
    return isDark ? HaTheme.DARK_TEXT_PRIMARY : HaColors.SETTINGS_TEXT_PRIMARY;
  }

  static textSecondary(isDark: boolean): string {
    return isDark ? HaTheme.DARK_TEXT_SECONDARY : HaColors.SETTINGS_TEXT_SECONDARY;
  }

  static textMuted(isDark: boolean): string {
    return isDark ? HaTheme.DARK_TEXT_MUTED : HaColors.TEXT_MUTED;
  }

  static divider(isDark: boolean): string {
    return isDark ? HaTheme.DARK_DIVIDER : HaColors.OUTLINE_NEUTRAL;
  }

  static outline(isDark: boolean): string {
    return isDark ? HaTheme.DARK_OUTLINE : HaColors.OUTLINE_STRONG;
  }

  static topBarIcon(isDark: boolean): string {
    return isDark ? '#D2D7DA' : HaColors.TOP_BAR_ICON;
  }

  static statusText(isDark: boolean, positive: boolean = false): string {
    if (positive) {
      return isDark ? '#66D3E0' : '#0B7285';
    }
    return HaTheme.textSecondary(isDark);
  }

  static statusBackground(isDark: boolean, positive: boolean = false): string {
    if (positive) {
      return isDark ? HaTheme.DARK_CHIP_OK : '#EAF8FC';
    }
    return isDark ? HaTheme.DARK_CHIP : '#EDF2F7';
  }

  static warningText(isDark: boolean): string {
    return isDark ? '#F2B8B5' : '#7A1F1F';
  }

  static warningBackground(isDark: boolean): string {
    return isDark ? HaTheme.DARK_CHIP_WARN : '#FDECEC';
  }
}
