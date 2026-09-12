import { OnboardingTopBar } from '../../shared/components/OnboardingTopBar';
import { PrimaryButton } from '../../shared/components/PrimaryButton';
import { HaColors } from '../../shared/constants/HaStyle';
import { OnboardingUiConfig } from '../../shared/constants/OnboardingUiConfig';
import { Localization } from '../../shared/i18n/Localization';

@Component
export struct LocationSharingPage {
  @Prop contentMaxWidth: number = OnboardingUiConfig.contentMaxWidth;
  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onShareLocation: () => void = () => {};
  onSkipLocation: () => void = () => {};

  build() {
    Scroll() {
      Column({ space: OnboardingUiConfig.pageColumnSpace }) {
        OnboardingTopBar({ showBack: true, onBack: this.onBack, onHelp: this.onHelp })
        Image($r('app.media.ha_onboarding_location'))
          .width(OnboardingUiConfig.heroIconSize)
          .height(OnboardingUiConfig.heroIconSize)
          .objectFit(ImageFit.Contain)
          .margin({ top: OnboardingUiConfig.heroTopMargin })
        Text(Localization.t('location_sharing_title'))
          .fontSize(OnboardingUiConfig.titleSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(HaColors.TEXT_PRIMARY)
          .lineHeight(OnboardingUiConfig.titleLineHeight)
          .textAlign(TextAlign.Center)
          .constraintSize({ maxWidth: this.contentMaxWidth })
          .width('100%')
        Text(Localization.t('location_sharing_body'))
          .fontSize(OnboardingUiConfig.bodySize)
          .fontColor(HaColors.TEXT_SECONDARY)
          .lineHeight(OnboardingUiConfig.bodyLineHeight)
          .textAlign(TextAlign.Center)
          .constraintSize({ maxWidth: this.contentMaxWidth })
          .width('100%')
        Blank().layoutWeight(1)
        PrimaryButton({
          text: Localization.t('location_share'),
          maxWidth: this.contentMaxWidth,
          action: this.onShareLocation
        })
        PrimaryButton({
          text: Localization.t('location_skip'),
          filled: false,
          maxWidth: this.contentMaxWidth,
          action: this.onSkipLocation
        })
      }
      .width('100%')
      .padding({
        left: OnboardingUiConfig.pagePadding,
        right: OnboardingUiConfig.pagePadding,
        top: OnboardingUiConfig.pageTopPadding,
        bottom: OnboardingUiConfig.pageBottomPadding
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .backgroundColor(HaColors.SURFACE)
  }
}
