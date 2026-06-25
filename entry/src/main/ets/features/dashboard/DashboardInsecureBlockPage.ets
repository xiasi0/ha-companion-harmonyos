import { Localization } from '../../shared/i18n/Localization';
import { HaColors } from '../../shared/constants/HaStyle';
import { OnboardingUiConfig } from '../../shared/constants/OnboardingUiConfig';
import { HaTheme } from '../../shared/theme/HaTheme';
import { OnboardingTopBar } from '../../shared/components/OnboardingTopBar';
import { PrimaryButton } from '../../shared/components/PrimaryButton';

@Component
export struct DashboardInsecureBlockPage {
  @Prop contentMaxWidth: number = OnboardingUiConfig.contentMaxWidth;
  @Prop missingHomeSetup: boolean = false;
  @Prop reason: string = '';
  @Prop dark: boolean = false;
  onRetry: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onChangeSecurityLevel: () => void = () => {};
  onConfigureHomeNetwork: () => void = () => {};

  @Builder
  private fixBanner(text: string, actionText: string, action: () => void): void {
    Column({ space: OnboardingUiConfig.noticePaddingVertical }) {
      Text(text)
        .fontSize(OnboardingUiConfig.auxiliaryTextSize)
        .fontColor(HaTheme.textPrimary(this.dark))
        .lineHeight(OnboardingUiConfig.auxiliaryLineHeight)
        .width('100%')
      Row() {
        Blank()
        Button(actionText)
          .fontSize(OnboardingUiConfig.buttonTextSize)
          .fontColor(Color.White)
          .backgroundColor(HaColors.PRIMARY)
          .borderRadius(OnboardingUiConfig.buttonHeight / 2)
          .height(OnboardingUiConfig.buttonHeight)
          .padding({
            left: OnboardingUiConfig.noticePaddingHorizontal,
            right: OnboardingUiConfig.noticePaddingHorizontal
          })
          .onClick(action)
      }
      .width('100%')
    }
    .width('100%')
    .padding(OnboardingUiConfig.pagePadding)
    .borderRadius(OnboardingUiConfig.noticeRadius)
    .backgroundColor(HaTheme.surfaceMuted(this.dark))
  }

  build() {
    Column() {
      OnboardingTopBar({
        showBack: true,
        leadingIconName: 'refresh',
        onBack: (): void => this.onRetry(),
        onHelp: (): void => {}
      })
      .padding({
        left: OnboardingUiConfig.pagePadding,
        right: OnboardingUiConfig.pagePadding
      })
      .margin({ top: OnboardingUiConfig.pageTopPadding })

      Column({ space: OnboardingUiConfig.pageColumnSpace }) {
        Column({ space: OnboardingUiConfig.welcomeTextSpace }) {
          Image($r('app.media.ha_onboarding_secure'))
            .width(OnboardingUiConfig.heroIconSize)
            .height(OnboardingUiConfig.heroIconSize)
            .objectFit(ImageFit.Contain)
          Text(Localization.t('block_insecure_title'))
            .fontSize(OnboardingUiConfig.titleSize)
            .fontWeight(FontWeight.Bold)
            .fontColor(HaTheme.textPrimary(this.dark))
            .textAlign(TextAlign.Center)
            .lineHeight(OnboardingUiConfig.titleLineHeight)
          Text(Localization.t('block_insecure_content'))
            .fontSize(OnboardingUiConfig.bodySize)
            .fontColor(HaTheme.textSecondary(this.dark))
            .textAlign(TextAlign.Center)
            .lineHeight(OnboardingUiConfig.bodyLineHeight)
        }
        .width('100%')

        Column({ space: OnboardingUiConfig.optionColumnSpace }) {
          if (this.missingHomeSetup) {
            this.fixBanner(
              Localization.t('block_insecure_missing_home_setup'),
              Localization.t('block_insecure_action_configure_home'),
              (): void => this.onConfigureHomeNetwork()
            )
          }
        }
        .width('100%')

        Blank()

        PrimaryButton({
          text: Localization.t('block_insecure_open_settings'),
          maxWidth: this.contentMaxWidth,
          action: (): void => this.onOpenSettings()
        })

        Button(Localization.t('block_insecure_change_security_level'))
          .height(OnboardingUiConfig.buttonHeight)
          .fontSize(OnboardingUiConfig.buttonTextSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(HaColors.PRIMARY)
          .backgroundColor(Color.Transparent)
          .onClick((): void => this.onChangeSecurityLevel())
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth })
      .layoutWeight(1)
      .padding({
        left: OnboardingUiConfig.pagePadding,
        right: OnboardingUiConfig.pagePadding,
        top: OnboardingUiConfig.discoveryTitleTopMargin,
        bottom: OnboardingUiConfig.pageBottomPadding
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(HaTheme.background(this.dark))
  }
}
