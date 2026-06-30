import { OnboardingTopBar } from '../../shared/components/OnboardingTopBar';
import { HaColors } from '../../shared/constants/HaStyle';
import { OnboardingUiConfig } from '../../shared/constants/OnboardingUiConfig';
import { Localization } from '../../shared/i18n/Localization';
import { OnboardingConnectionErrorPanel } from '../connection/OnboardingConnectionErrorPanel';
import { ConnectionError } from '../connection/ConnectionErrorModels';

@Component
export struct OnboardingConnectionErrorPage {
  @Prop contentMaxWidth: number = OnboardingUiConfig.contentMaxWidth;
  @Prop error: ConnectionError | undefined = undefined;
  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onRetry: () => void = () => {};

  build() {
    Scroll() {
      Column({ space: OnboardingUiConfig.pageColumnSpace }) {
        OnboardingTopBar({ showBack: true, onBack: this.onBack, onHelp: this.onHelp })
        OnboardingConnectionErrorPanel({
          contentMaxWidth: this.contentMaxWidth,
          error: this.error,
          primaryActionText: Localization.t('retry'),
          secondaryActionText: Localization.t('back'),
          onPrimaryAction: this.onRetry,
          onSecondaryAction: this.onBack
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
