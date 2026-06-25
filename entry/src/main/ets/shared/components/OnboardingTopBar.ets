import { HaColors } from '../constants/HaStyle';
import { AppIconView } from '../icons/AppIconView';
import { systemIcon } from '../icons/AppIconModels';
import { OnboardingUiConfig } from '../constants/OnboardingUiConfig';
import { HaTheme } from '../theme/HaTheme';

@Component
export struct OnboardingTopBar {
  @Prop
  showBack: boolean = true;
  @Prop
  leadingIconName: string = 'arrow_left';
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
          AppIconView({
            icon: systemIcon(this.leadingIconName),
            iconSize: OnboardingUiConfig.topBarIconSize,
            slotSize: OnboardingUiConfig.topBarIconSize,
            color: this.iconColor()
          })
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
        AppIconView({
          icon: systemIcon('question'),
          iconSize: OnboardingUiConfig.topBarIconSize,
          slotSize: OnboardingUiConfig.topBarIconSize,
          color: this.iconColor()
        })
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
