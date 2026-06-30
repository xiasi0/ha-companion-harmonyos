import { PrimaryButton } from '../../shared/components/PrimaryButton';
import { OnboardingUiConfig } from '../../shared/constants/OnboardingUiConfig';
import { HaColors } from '../../shared/constants/HaStyle';
import { AppIconView } from '../../shared/icons/AppIconView';
import { systemIcon } from '../../shared/icons/AppIconModels';
import { Localization } from '../../shared/i18n/Localization';
import { ConnectionError } from './ConnectionErrorModels';

@Component
export struct OnboardingConnectionErrorPanel {
  @Prop contentMaxWidth: number = OnboardingUiConfig.contentMaxWidth;
  @Prop error: ConnectionError | undefined = undefined;
  @Prop primaryActionText: string = Localization.t('retry');
  @Prop secondaryActionText: string = Localization.t('back');
  @Prop showSecondaryAction: boolean = true;
  onPrimaryAction: () => void = () => {};
  onSecondaryAction: () => void = () => {};

  private displayUrl(): string {
    if (!this.error) {
      return '';
    }
    return this.error.url.trim().length > 0 ? this.error.url : this.error.requestUrl;
  }

  private displayDetail(): string {
    if (!this.error || this.error.detail.trim().length === 0) {
      return Localization.t('connection_error_unknown_detail');
    }
    return this.error.detail;
  }

  private displayCode(): string {
    return this.error ? `${this.error.code}` : '0';
  }

  @Builder
  private urlInfo(): void {
    if (this.displayUrl().trim().length > 0) {
      Column({ space: OnboardingUiConfig.optionColumnSpace }) {
        Text(Localization.t('connection_error_url_info'))
          .fontSize(OnboardingUiConfig.buttonTextSize)
          .fontColor(HaColors.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
        Text(this.displayUrl())
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
      Text(Localization.format2('connection_error_more_details_description_content', 'code', this.displayCode(), 'detail', this.displayDetail()))
        .fontSize(OnboardingUiConfig.auxiliaryTextSize)
        .fontColor(HaColors.TEXT_SECONDARY)
        .lineHeight(OnboardingUiConfig.auxiliaryLineHeight)
        .width('100%')

      PrimaryButton({
        text: this.primaryActionText,
        maxWidth: this.contentMaxWidth,
        action: this.onPrimaryAction
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
    Column({ space: OnboardingUiConfig.pageColumnSpace }) {
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
      if (this.showSecondaryAction) {
        PrimaryButton({
          text: this.secondaryActionText,
          maxWidth: this.contentMaxWidth,
          action: this.onSecondaryAction
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
