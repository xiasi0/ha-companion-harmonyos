import { HaColors } from '../constants/HaStyle';
import { OnboardingUiConfig } from '../constants/OnboardingUiConfig';
import { HaTheme } from '../theme/HaTheme';

@Component
export struct OnboardingTopBar {
  @Prop
  showBack: boolean = true;
  @Prop
  leadingIcon: Resource = $r('sys.symbol.arrow_left');
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  onBack: () => void = () => {};
  onHelp: () => void = () => {};

  private iconColor(): string {
    return HaTheme.textPrimary(this.appResolvedDark);
  }

  build() {
    Row({ space: OnboardingUiConfig.topBarSpace }) {
      if (this.showBack) {
        Stack() {
          SymbolGlyph(this.leadingIcon)
            .width(OnboardingUiConfig.topBarIconSize)
            .height(OnboardingUiConfig.topBarIconSize)
            .fontSize(OnboardingUiConfig.topBarIconSize)
            .fontColor([this.iconColor()])
        }
        .width(OnboardingUiConfig.topBarButtonSize)
        .height(OnboardingUiConfig.topBarButtonSize)
        .backgroundColor(HaTheme.surface(this.appResolvedDark))
        .borderRadius(OnboardingUiConfig.topBarButtonSize / 2)
        .shadow({ radius: 8, color: HaColors.SETTINGS_CARD_SHADOW, offsetX: 0, offsetY: 2 })
        .onClick(() => {
          this.onBack();
        })
      } else {
        Blank()
          .width(OnboardingUiConfig.topBarButtonSize)
          .height(OnboardingUiConfig.topBarButtonSize)
      }

      Blank()
        .layoutWeight(1)

      Stack() {
        SymbolGlyph($r('sys.symbol.questionmark_circle'))
          .width(OnboardingUiConfig.topBarIconSize)
          .height(OnboardingUiConfig.topBarIconSize)
          .fontSize(OnboardingUiConfig.topBarIconSize)
          .fontColor([this.iconColor()])
      }
      .width(OnboardingUiConfig.topBarButtonSize)
      .height(OnboardingUiConfig.topBarButtonSize)
      .backgroundColor(HaTheme.surface(this.appResolvedDark))
      .borderRadius(OnboardingUiConfig.topBarButtonSize / 2)
      .shadow({ radius: 8, color: HaColors.SETTINGS_CARD_SHADOW, offsetX: 0, offsetY: 2 })
      .onClick(() => {
        this.onHelp();
      })
    }
    .width('100%')
    .height(OnboardingUiConfig.topBarHeight)
    .alignItems(VerticalAlign.Center)
  }
}
