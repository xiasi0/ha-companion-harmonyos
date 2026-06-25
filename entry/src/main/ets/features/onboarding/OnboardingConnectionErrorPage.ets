import { OnboardingTopBar } from '../../shared/components/OnboardingTopBar';
import { PrimaryButton } from '../../shared/components/PrimaryButton';
import { HaColors } from '../../shared/constants/HaStyle';
import { AppIconView } from '../../shared/icons/AppIconView';
import { systemIcon } from '../../shared/icons/AppIconModels';
import { OnboardingUiConfig } from '../../shared/constants/OnboardingUiConfig';
import { Localization } from '../../shared/i18n/Localization';

@Component
export struct OnboardingConnectionErrorPage {
  @Prop contentMaxWidth: number = OnboardingUiConfig.contentMaxWidth;
  @Prop url: string = '';
  @Prop errorCode: number = 0;
  @Prop errorDetail: string = '';
  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onRetry: () => void = () => {};

  private displayDetail(): string {
    return this.errorDetail.trim().length > 0 ? this.errorDetail : Localization.t('connection_error_unknown_detail');
  }

  @Builder
  private urlInfo(): void {
    if (this.url.trim().length > 0) {
      Column({ space: OnboardingUiConfig.optionColumnSpace }) {
        Text(Localization.t('connection_error_url_info'))
          .fontSize(OnboardingUiConfig.buttonTextSize)
          .fontColor(HaColors.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
        Text(this.url)
          .fontSize(OnboardingUiConfig.bodySize)
          .fontWeight(FontWeight.Medium)
          .fontColor(HaColors.PRIMARY)
          .lineHeight(OnboardingUiConfig.bodyLineHeight)
          .textAlign(TextAlign.Center)
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth })
      .padding(OnboardingUiConfig.connectionErrorCardPadding)
      .backgroundColor(HaColors.SURFACE_MUTED)
      .borderRadius(OnboardingUiConfig.connectionErrorCardRadius)
    }
  }

  @Builder
  private detailsCard(): void {
    Column({ space: OnboardingUiConfig.connectionErrorCardSpace }) {
      Row({ space: OnboardingUiConfig.noticeRowSpace }) {
        AppIconView({
          icon: systemIcon('chevron_up'),
          iconSize: OnboardingUiConfig.noticeIconSize,
          slotSize: OnboardingUiConfig.noticeIconSize,
          color: HaColors.TEXT_SECONDARY
        })
        Text(Localization.t('connection_error_more_details'))
          .fontSize(OnboardingUiConfig.bodySize)
          .fontColor(HaColors.TEXT_SECONDARY)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')

      Text(Localization.t('connection_error_more_details_description'))
        .fontSize(OnboardingUiConfig.bodySize)
        .fontColor(HaColors.TEXT_SECONDARY)
        .width('100%')
      Text(Localization.format2('connection_error_more_details_description_content', 'code', `${this.errorCode}`, 'detail', this.displayDetail()))
        .fontSize(OnboardingUiConfig.auxiliaryTextSize)
        .fontColor(HaColors.TEXT_SECONDARY)
        .lineHeight(OnboardingUiConfig.auxiliaryLineHeight)
        .width('100%')

      PrimaryButton({
        text: Localization.t('retry'),
        maxWidth: this.contentMaxWidth,
        action: this.onRetry
      })
    }
    .width('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth })
    .padding(OnboardingUiConfig.connectionErrorDetailsPadding)
    .border({ width: 1, color: HaColors.OUTLINE })
    .borderRadius(OnboardingUiConfig.connectionErrorDetailsBorderRadius)
  }

  @Builder
  private helpText(): void {
    Text(Localization.t('connection_error_help'))
      .fontSize(OnboardingUiConfig.bodySize)
      .fontColor(HaColors.TEXT_SECONDARY)
      .textAlign(TextAlign.Center)
      .width('100%')
  }

  @Builder
  private casitaNoConnectionIcon(): void {
    Image($r('app.media.ha_onboarding_connection_error'))
      .width(OnboardingUiConfig.connectionErrorIconSize)
      .height(OnboardingUiConfig.connectionErrorIconSize)
      .objectFit(ImageFit.Contain)
      .margin({ top: OnboardingUiConfig.heroTopMargin })
  }

  build() {
    Scroll() {
      Column({ space: OnboardingUiConfig.pageColumnSpace }) {
        OnboardingTopBar({ showBack: true, onBack: this.onBack, onHelp: this.onHelp })
        this.casitaNoConnectionIcon()
        Text(Localization.t('connection_error_title'))
          .fontSize(OnboardingUiConfig.titleSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(HaColors.TEXT_PRIMARY)
          .lineHeight(OnboardingUiConfig.titleLineHeight)
          .textAlign(TextAlign.Center)
          .constraintSize({ maxWidth: this.contentMaxWidth })
          .width('100%')
        Text(Localization.t('connection_error_message'))
          .fontSize(OnboardingUiConfig.bodySize)
          .fontColor(HaColors.TEXT_SECONDARY)
          .lineHeight(OnboardingUiConfig.bodyLineHeight)
          .textAlign(TextAlign.Center)
          .constraintSize({ maxWidth: this.contentMaxWidth })
          .width('100%')
        this.urlInfo()
        this.detailsCard()
        this.helpText()
        PrimaryButton({
          text: Localization.t('back'),
          maxWidth: this.contentMaxWidth,
          action: this.onBack
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
