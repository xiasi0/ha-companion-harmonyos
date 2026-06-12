import { SettingsItem, SettingsItemType, SettingsSection } from '../../models/SettingsItem';
import { SettingsCategory } from './components/SettingsCategory';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsLiveRow } from './components/SettingsLiveRow';
import { SettingsLiveSwitchRow } from './components/SettingsLiveSwitchRow';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import { HaTheme } from '../../shared/theme/HaTheme';
import {
  SettingsLiveGroupState,
  SettingsLiveRowState,
  SettingsLiveStateStore
} from '../../services/SettingsLiveStateStore';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct ServerSettingsPage {
  @Prop
  title: string = 'Home Assistant';
  @Prop @Watch('syncLiveRows')
  sections: SettingsSection[] = [];
  @Prop
  contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @Prop
  selectedKey: string = '';
  @Prop
  scrollOffset: number = 0;
  embeddedInNavigation: boolean = false;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @State private liveGroups: SettingsLiveGroupState[] = [];
  onBack: () => void = () => {};
  onOpen: (item: SettingsItem) => void = () => {};
  onAction: (actionId: string) => void = () => {};
  onScrollOffsetChange: (offset: number) => void = () => {};
  onSwipeBack: () => void = () => {};
  private settingsScroller: Scroller = new Scroller();
  private lastReportedScrollOffset: number = 0;

  aboutToAppear(): void {
    this.syncLiveRows();
    this.lastReportedScrollOffset = this.scrollOffset;
    this.restoreScrollOffset();
  }

  private syncLiveRows(): void {
    SettingsLiveStateStore.applySections(this.sections);
    const nextGroups: SettingsLiveGroupState[] = [];
    for (let i = 0; i < this.sections.length; i++) {
      const section = this.sections[i];
      const groupState = new SettingsLiveGroupState();
      groupState.key = `${i}:${section.title}`;
      groupState.title = section.title;
      for (let j = 0; j < section.items.length; j++) {
        groupState.rows.push(SettingsLiveStateStore.stateFor(section.items[j]));
      }
      nextGroups.push(groupState);
    }
    this.liveGroups = nextGroups;
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

  private rowKey(row: SettingsLiveRowState): string {
    if (row.actionId.length > 0) {
      return row.actionId;
    }
    return row.title;
  }

  private rowRenderKey(row: SettingsLiveRowState): string {
    return `${row.type}-${this.rowKey(row)}`;
  }

  @Builder
  private renderSettingsItem(row: SettingsLiveRowState): void {
    if (row.type === SettingsItemType.SWITCH) {
      SettingsLiveSwitchRow({
        state: row,
        active: this.rowKey(row) === this.selectedKey,
        onOpen: (target: SettingsItem): void => {
          this.persistScrollOffset();
          this.onOpen(target);
        }
      })
    } else {
      SettingsLiveRow({
        state: row,
        active: this.rowKey(row) === this.selectedKey,
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
  private renderSettingsGroup(section: SettingsLiveGroupState): void {
    Column() {
      ForEach(section.rows, (row: SettingsLiveRowState, itemIndex?: number) => {
        this.renderSettingsItem(row);
        if ((itemIndex ?? 0) < section.rows.length - 1) {
          SettingsBoundary()
        }
      }, (row: SettingsLiveRowState) => this.rowRenderKey(row))
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  @Builder
  private renderSettingsList(): void {
    Stack({ alignContent: Alignment.End }) {
      List({ scroller: this.settingsScroller, space: SettingsUiConfig.listSpace }) {
        ForEach(this.liveGroups, (section: SettingsLiveGroupState) => {
          if (section.rows.length > 0) {
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
        }, (section: SettingsLiveGroupState) => section.key)
      }
      .padding(SettingsUiConfig.listPadding())
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .contentEndOffset(SettingsUiConfig.listContentEndOffset)
      .clip(false)
      .cachedCount(3, true)
      .scrollBar(BarState.Off)
      .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))

      ScrollBar({
        scroller: this.settingsScroller,
        direction: ScrollBarDirection.Vertical,
        state: BarState.Auto
      })
        .width(9)
        .height('100%')
        .backgroundColor(Color.Transparent)
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
  }

  @Builder
  private renderEmbeddedContent(): void {
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

  @Builder
  private renderNavigationContent(): void {
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

  build() {
    if (this.embeddedInNavigation) {
      this.renderEmbeddedContent()
    } else {
      this.renderNavigationContent()
    }
  }
}
