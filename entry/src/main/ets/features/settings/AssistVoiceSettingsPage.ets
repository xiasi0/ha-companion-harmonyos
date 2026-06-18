import { SettingsItem, detailSettingsItem } from '../../models/SettingsItem';
import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import { SettingChoiceGroup, SettingChoiceOption } from './CompanionSettingsData';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsCategory } from './components/SettingsCategory';
import { SettingsInlineSwitchRow } from './components/SettingsInlineSwitchRow';
import { SettingsRadioRow } from './components/SettingsRadioRow';
import { SettingsRow } from './components/SettingsRow';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct AssistVoiceSettingsPage {
  @Prop groups: SettingChoiceGroup[] = [];
  @Prop selectedWakeWord: string = '';
  @Prop wakeDetectionEnabled: boolean = true;
  @Prop probabilityCutoffSummary: string = '';
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onSelectWakeWord: (value: string) => void = () => {};
  onWakeDetectionChange: (value: boolean) => void = () => {};
  onOpenProbabilityCutoff: () => void = () => {};
  onSwipeBack: () => void = () => {};

  private probabilityCutoffItem(): SettingsItem {
    const item = detailSettingsItem(
      'voice',
      Localization.t('assist_probability_cutoff'),
      this.probabilityCutoffSummary,
      '',
      ''
    );
    item.actionId = 'assist_probability_cutoff';
    return item;
  }

  @Builder
  private renderWakeWordOption(option: SettingChoiceOption): void {
    SettingsRadioRow({
      title: option.title,
      summary: option.summary,
      selected: this.selectedWakeWord === option.value,
      minHeight: 56,
      onSelect: (): void => {
        this.onSelectWakeWord(option.value);
      }
    })
  }

  @Builder
  private renderWakeDetectionGroup(): void {
    Column() {
      SettingsInlineSwitchRow({
        title: Localization.t('assist_wake_word_detection_enabled'),
        checked: this.wakeDetectionEnabled,
        onChange: this.onWakeDetectionChange
      })
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  @Builder
  private renderWakeWordGroup(group: SettingChoiceGroup): void {
    Column() {
      ForEach(group.options, (option: SettingChoiceOption, index?: number) => {
        this.renderWakeWordOption(option)
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
  private renderProbabilityCutoffGroup(): void {
    Column() {
      SettingsRow({
        item: this.probabilityCutoffItem(),
        onOpen: (_item: SettingsItem): void => {
          this.onOpenProbabilityCutoff();
        }
      })
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
      ListItem() {
        this.renderWakeDetectionGroup()
      }
      .width('100%')

      if (this.wakeDetectionEnabled) {
        ForEach(this.groups, (group: SettingChoiceGroup) => {
          if (group.title.length > 0) {
            ListItem() {
              SettingsCategory({ title: group.title })
            }
            .width('100%')
          }
          ListItem() {
            this.renderWakeWordGroup(group)
          }
          .width('100%')
        }, (group: SettingChoiceGroup) => group.title)
      }

      ListItem() {
        this.renderProbabilityCutoffGroup()
      }
      .width('100%')
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
    .titleBar(SettingsUiConfig.titleBar(Localization.t('settings_harmonyos_voice_assistant'), this.onBack, this.appResolvedDark))
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
