import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import { GestureSettingGroup, GestureSettingItem } from './CompanionSettingsData';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsCategory } from './components/SettingsCategory';
import { SettingsContentRow } from './components/SettingsContentRow';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct GestureSettingsPage {
  @Prop groups: GestureSettingGroup[] = [];
  @Prop description: string = '';
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onOpenGesture: (key: string) => void = () => {};
  onSwipeBack: () => void = () => {};

  @Builder
  private renderGestureItem(item: GestureSettingItem): void {
    SettingsContentRow({
      title: item.title,
      summary: item.summary,
      showArrow: true,
      interactive: true,
      onOpen: (): void => {
        this.onOpenGesture(item.key);
      }
    })
  }

  @Builder
  private renderGestureGroup(group: GestureSettingGroup): void {
    Column() {
      ForEach(group.items, (item: GestureSettingItem, index?: number) => {
        this.renderGestureItem(item)
        if ((index ?? 0) < group.items.length - 1) {
          SettingsBoundary()
        }
      }, (item: GestureSettingItem) => item.key)
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  @Builder
  private renderPageContent(): void {
    List({ scroller: this.scroller, space: SettingsUiConfig.listSpace }) {
      if (this.description.length > 0) {
        ListItem() {
          Column() {
            Text(this.description)
              .fontSize(16)
              .fontColor(HaTheme.textPrimary(this.appResolvedDark))
              .lineHeight(24)
              .width('100%')
              .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          }
          .width('100%')
          .borderRadius(SettingsUiConfig.groupRadius)
          .backgroundColor(HaTheme.surface(this.appResolvedDark))
          .shadow(SettingsUiConfig.groupShadow())
        }
        .width('100%')
      }

      ForEach(this.groups, (group: GestureSettingGroup) => {
        ListItem() {
          SettingsCategory({ title: group.title })
        }
        .width('100%')

        ListItem() {
          this.renderGestureGroup(group)
        }
        .width('100%')
      }, (group: GestureSettingGroup) => group.title)
    }
    .padding(SettingsUiConfig.listPadding())
    .layoutWeight(1)
    .width('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth })
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(SettingsUiConfig.listContentEndOffset)
    .clip(false)
    .cachedCount(3, true)
    .scrollBar(SettingsUiConfig.scrollBarState())
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
    .titleBar(SettingsUiConfig.titleBar(Localization.t('settings_gestures'), this.onBack, this.appResolvedDark))
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
