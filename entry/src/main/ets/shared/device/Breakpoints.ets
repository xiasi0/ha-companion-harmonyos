export class Breakpoints {
  static readonly PHONE_MAX_WIDTH: number = 599;
  static readonly MEDIUM_MIN_WIDTH: number = 600;
  static readonly EXPANDED_MIN_WIDTH: number = 840;
  static readonly TABLET_MIN_WIDTH: number = Breakpoints.MEDIUM_MIN_WIDTH;
  static readonly LARGE_TABLET_MIN_WIDTH: number = Breakpoints.EXPANDED_MIN_WIDTH;
  static readonly WEARABLE_MAX_WIDTH: number = 480;
  static readonly PHONE_CONTENT_MAX_WIDTH: number = 380;
  static readonly TABLET_CONTENT_MAX_WIDTH: number = 560;
  static readonly LARGE_CONTENT_MAX_WIDTH: number = 720;

  static isCompact(widthVp: number): boolean {
    return widthVp < Breakpoints.MEDIUM_MIN_WIDTH;
  }

  static isMedium(widthVp: number): boolean {
    return widthVp >= Breakpoints.MEDIUM_MIN_WIDTH && widthVp < Breakpoints.EXPANDED_MIN_WIDTH;
  }

  static isExpanded(widthVp: number): boolean {
    return widthVp >= Breakpoints.EXPANDED_MIN_WIDTH;
  }

  static onboardingContentMaxWidth(widthVp: number = Breakpoints.PHONE_MAX_WIDTH): number {
    if (Breakpoints.isExpanded(widthVp)) {
      return Breakpoints.LARGE_CONTENT_MAX_WIDTH;
    }
    if (Breakpoints.isMedium(widthVp)) {
      return Breakpoints.TABLET_CONTENT_MAX_WIDTH;
    }
    return Breakpoints.PHONE_CONTENT_MAX_WIDTH;
  }

  static settingsContentMaxWidth(widthVp: number = Breakpoints.PHONE_MAX_WIDTH): number {
    return widthVp;
  }
}
