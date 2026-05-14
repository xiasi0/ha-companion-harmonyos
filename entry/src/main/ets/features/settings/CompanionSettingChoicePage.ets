import { HaTheme } from '../../shared/theme/HaTheme';
import { SettingChoiceGroup, SettingChoiceOption } from './CompanionSettingsData';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsCategory } from './components/SettingsCategory';
import { SettingsRadioRow } from './components/SettingsRadioRow';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct CompanionSettingChoicePage {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop groups: SettingChoiceGroup[] = [];
  @Prop selectedValue: string = '';
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onSelect: (value: string) => void = () => {};
  onSwipeBack: () => void = () => {};

  @Builder
  private renderOption(option: SettingChoiceOption): void {
    SettingsRadioRow({
      title: option.title,
      summary: option.summary,
      selected: this.selectedValue === option.value,
      minHeight: 56,
      onSelect: (): void => {
        this.onSelect(option.value);
      }
    })
  }

  @Builder
  private renderOptionGroup(group: SettingChoiceGroup): void {
    Column() {
      ForEach(group.options, (option: SettingChoiceOption, index?: number) => {
        this.renderOption(option)
        if ((index ?? 0) < group.options.length - 1) {
          SettingsBoundary()
        }
      }, (option: SettingChoiceOption) => option.value)
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
      ForEach(this.groups, (group: SettingChoiceGroup) => {
        if (group.title.length > 0) {
          ListItem() {
            SettingsCategory({ title: group.title })
          }
          .width('100%')
        }
        ListItem() {
          this.renderOptionGroup(group)
        }
        .width('100%')
      }, (group: SettingChoiceGroup) => group.title)
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
