import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

interface PrivacyPolicyItem {
  title: string;
  url: string;
}

@Component
export struct PrivacyPolicyPage {
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onSwipeBack: () => void = () => {};

  private items(): PrivacyPolicyItem[] {
    return [
      {
        title: Localization.t('privacy_home_assistant_statement'),
        url: 'https://www.home-assistant.io/privacy/'
      },
      {
        title: Localization.t('privacy_huawei_statement'),
        url: 'https://consumer.huawei.com/cn/privacy/privacy-statement-huawei/'
      }
    ];
  }

  @Builder
  private renderItem(item: PrivacyPolicyItem): void {
    Column({ space: 8 }) {
      Text(item.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(HaTheme.textPrimary(this.appResolvedDark))
        .width('100%')

      Text(item.url)
        .fontSize(14)
        .fontColor(HaTheme.textSecondary(this.appResolvedDark))
        .lineHeight(20)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .backgroundColor(SettingsUiConfig.transparentBackground)
  }

  @Builder
  private renderPageContent(): void {
    List({ scroller: this.scroller, space: SettingsUiConfig.listSpace }) {
      ListItem() {
        Column() {
          ForEach(this.items(), (item: PrivacyPolicyItem, index?: number) => {
            this.renderItem(item)
            if ((index ?? 0) < this.items().length - 1) {
              SettingsBoundary()
            }
          }, (item: PrivacyPolicyItem) => item.title)
        }
        .width('100%')
        .borderRadius(SettingsUiConfig.groupRadius)
        .backgroundColor(HaTheme.surface(this.appResolvedDark))
        .shadow(SettingsUiConfig.groupShadow())
        .padding(SettingsUiConfig.groupPadding)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .width('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth })
    .padding(SettingsUiConfig.listPadding())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(SettingsUiConfig.listContentEndOffset)
    .scrollBar(SettingsUiConfig.scrollBarState())
    .cachedCount(3, true)
    .clip(false)
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .alignListItem(ListItemAlign.Center)
  }

  build() {
    HdsNavigation() {
      this.renderPageContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .titleBar(SettingsUiConfig.titleBar(Localization.t('settings_privacy_policy'), this.onBack, this.appResolvedDark))
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
