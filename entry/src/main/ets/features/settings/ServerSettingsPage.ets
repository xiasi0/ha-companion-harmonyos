import { SettingsItem, SettingsItemType, SettingsSection } from '../../models/SettingsItem';
import { SettingsCategory } from './components/SettingsCategory';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsRow } from './components/SettingsRow';
import { SettingsSwitchRow } from './components/SettingsSwitchRow';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import { HaTheme } from '../../shared/theme/HaTheme';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct ServerSettingsPage {
  @Prop
  title: string = 'Home Assistant';
  @Prop
  sections: SettingsSection[] = [];
  @Prop
  contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @Prop
  selectedKey: string = '';
  @Prop
  scrollOffset: number = 0;
  @Prop
  switchRevision: number = 0;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  onBack: () => void = () => {};
  onOpen: (item: SettingsItem) => void = () => {};
  onAction: (actionId: string) => void = () => {};
  onScrollOffsetChange: (offset: number) => void = () => {};
  onSwipeBack: () => void = () => {};
  private settingsScroller: Scroller = new Scroller();
  private lastReportedScrollOffset: number = 0;

  aboutToAppear(): void {
    this.lastReportedScrollOffset = this.scrollOffset;
    this.restoreScrollOffset();
  }

  private restoreScrollOffset(): void {
    if (this.scrollOffset <= 0) {
      return;
    }
    setTimeout(() => {
      this.settingsScroller.scrollTo({ xOffset: 0, yOffset: this.scrollOffset });
    }, 0);
  }

  private currentScrollOffset(): number {
    const offset = this.settingsScroller.currentOffset();
    return Number(offset.yOffset);
  }

  private persistScrollOffset(): void {
    this.reportScrollOffset(this.currentScrollOffset());
  }

  private reportScrollOffset(offset: number): void {
    if (Math.abs(offset - this.lastReportedScrollOffset) < 4) {
      return;
    }
    this.lastReportedScrollOffset = offset;
    this.onScrollOffsetChange(offset);
  }

  private itemKey(item: SettingsItem): string {
    if (item.actionId.length > 0) {
      return item.actionId;
    }
    return item.title;
  }

  @Builder
  private renderSettingsItem(item: SettingsItem): void {
    if (item.type === SettingsItemType.SWITCH) {
      SettingsSwitchRow({
        item,
        isOn: item.isOn,
        active: this.itemKey(item) === this.selectedKey,
        onOpen: (target: SettingsItem): void => {
          this.persistScrollOffset();
          this.onOpen(target);
        }
      })
    } else {
      SettingsRow({
        item,
        active: this.itemKey(item) === this.selectedKey,
        onOpen: (target: SettingsItem): void => {
          this.persistScrollOffset();
          this.onOpen(target);
        },
        onAction: (actionId: string): void => {
          this.persistScrollOffset();
          this.onAction(actionId);
        }
      })
    }
  }

  @Builder
  private renderSettingsGroup(section: SettingsSection): void {
    Column() {
      ForEach(section.items, (item: SettingsItem, itemIndex?: number) => {
        this.renderSettingsItem(item);
        if ((itemIndex ?? 0) < section.items.length - 1) {
          SettingsBoundary()
        }
      }, (item: SettingsItem) => `${item.type}-${item.title}-${item.summary}-${item.status}-${item.actionId}-${item.isOn}-${this.switchRevision}`)
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  @Builder
  private renderSettingsList(): void {
    List({ scroller: this.settingsScroller, space: SettingsUiConfig.listSpace }) {
      ForEach(this.sections, (section: SettingsSection) => {
        if (section.items.length > 0) {
          if (section.title.trim().length > 0) {
            ListItem() {
              SettingsCategory({ title: section.title })
            }
            .width('100%')
          }

          ListItem() {
            this.renderSettingsGroup(section)
          }
          .width('100%')
        }
      }, (section: SettingsSection) => `${section.title}-${this.switchRevision}`)
    }
    .padding(SettingsUiConfig.listPadding())
    .layoutWeight(1)
    .width('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(SettingsUiConfig.listContentEndOffset)
    .clip(false)
    .cachedCount(3, true)
    .scrollBar(SettingsUiConfig.scrollBarState())
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
  }

  build() {
    HdsNavigation() {
      Column() {
        Column() {
          this.renderSettingsList()
        }
        .width('100%')
        .constraintSize({ maxWidth: this.contentMaxWidth })
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .titleBar(SettingsUiConfig.titleBar(this.title, this.onBack, this.appResolvedDark))
    .hideBackButton(false)
    .bindToScrollable([this.settingsScroller])
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetX > 60 || event.offsetX < -60) {
            this.persistScrollOffset();
            this.onSwipeBack();
          }
        })
    )
  }
}
