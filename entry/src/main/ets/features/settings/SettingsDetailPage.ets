import { PrimaryButton } from '../../shared/components/PrimaryButton';
import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';
import { SettingsStatusChip } from './components/SettingsStatusChip';
import { SettingsUiConfig } from './components/SettingsUiConfig';

@Component
export struct SettingsDetailPage {
  @Prop
  title: string = Localization.t('settings_companion_title');
  @Prop
  summary: string = '';
  @Prop
  status: string = '';
  @Prop
  body: string = '';
  @Prop
  action: string = '';
  @Prop
  contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onAction: () => void = () => {};
  onSwipeBack: () => void = () => {};

  private statusPositive(): boolean {
    return this.status === Localization.t('common_available');
  }

  @Builder
  private renderPageContent(): void {
    Scroll(this.scroller) {
      Column({ space: 18 }) {
        if (this.summary.length > 0) {
          Text(this.summary)
            .fontSize(14)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
            .lineHeight(22)
            .width('100%')
        }

        if (this.status.length > 0) {
          SettingsStatusChip({ text: this.status, tone: this.statusPositive() ? 'positive' : 'neutral' })
        }

        Text(this.body)
          .fontSize(16)
          .fontColor(HaTheme.textPrimary(this.appResolvedDark))
          .lineHeight(24)
          .width('100%')

        if (this.action.length > 0) {
          PrimaryButton({
            text: this.action,
            maxWidth: this.contentMaxWidth,
            action: this.onAction
          })
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      .backgroundColor(HaTheme.surface(this.appResolvedDark))
      .borderRadius(SettingsUiConfig.groupRadius)
      .shadow(SettingsUiConfig.groupShadow())
    }
    .layoutWeight(1)
    .width('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth })
    .padding(SettingsUiConfig.listPadding())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(SettingsUiConfig.scrollBarState())
    .clip(false)
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
  }

  build() {
    HdsNavigation() {
      this.renderPageContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .titleBar(SettingsUiConfig.titleBar(this.title, this.onBack, this.appResolvedDark))
    .bindToScrollable([this.scroller])
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetX > 60 || event.offsetX < -60) {
            this.onSwipeBack();
          }
        })
    )
  }
}
