import { HaColors } from '../../shared/constants/HaStyle';
import { Localization } from '../../shared/i18n/Localization';
import { HaTheme } from '../../shared/theme/HaTheme';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsCategory } from './components/SettingsCategory';
import { SettingsInlineSwitchRow } from './components/SettingsInlineSwitchRow';
import { SettingsTextInput } from './components/SettingsTextInput';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct ServerHomeNetworkPage {
  @Prop wifiSsids: string[] = [];
  @Prop ssidInput: string = '';
  @Prop prioritizeInternal: boolean = false;
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onSsidInputChange: (value: string) => void = () => {};
  onAddSsid: () => void = () => {};
  onRemoveSsid: (value: string) => void = () => {};
  onPrioritizeChange: (value: boolean) => void = () => {};
  onSwipeBack: () => void = () => {};

  private canAddSsid(): boolean {
    return this.ssidInput.trim().length > 0;
  }

  @Builder
  private renderDescription(): void {
    Text(Localization.t('home_network_description_short'))
      .fontSize(14)
      .fontColor(HaTheme.textSecondary(this.appResolvedDark))
      .lineHeight(20)
      .width('100%')
      .padding({ left: 12, right: 12, top: 4, bottom: 6 })
  }

  @Builder
  private renderAddWifiRow(): void {
    Row({ space: 12 }) {
      SettingsTextInput({
        text: this.ssidInput,
        placeholder: Localization.t('home_network_wifi_placeholder'),
        inputType: InputType.Normal,
        onChange: this.onSsidInputChange
      })
      .layoutWeight(1)

      Button() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(22)
          .fontColor([this.canAddSsid() ? HaColors.ON_PRIMARY : HaTheme.textMuted(this.appResolvedDark)])
      }
        .width(48)
        .height(48)
        .backgroundColor(this.canAddSsid() ? HaColors.SETTINGS_ACCENT : HaTheme.surfaceStrong(this.appResolvedDark))
        .borderRadius(24)
        .stateEffect(this.canAddSsid())
        .onClick(() => {
          if (this.canAddSsid()) {
            this.onAddSsid();
          }
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private renderSsidItem(value: string): void {
    Row({ space: 12 }) {
      Text(value)
        .fontSize(16)
        .fontColor(HaTheme.textPrimary(this.appResolvedDark))
        .lineHeight(22)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Button() {
        SymbolGlyph($r('sys.symbol.minus'))
          .fontSize(22)
          .fontColor([HaColors.ERROR])
      }
        .width(48)
        .height(48)
        .backgroundColor(SettingsUiConfig.transparentBackground)
        .borderRadius(24)
        .stateEffect(true)
        .onClick(() => {
          this.onRemoveSsid(value);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 16, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(SettingsUiConfig.transparentBackground)
  }

  @Builder
  private renderWifiGroup(): void {
    Column() {
      this.renderAddWifiRow()

      if (this.wifiSsids.length > 0) {
        SettingsBoundary()
        ForEach(this.wifiSsids, (ssid: string, index?: number) => {
          this.renderSsidItem(ssid)
          if ((index ?? 0) < this.wifiSsids.length - 1) {
            SettingsBoundary()
          }
        }, (ssid: string) => ssid)
      }
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  @Builder
  private renderWarning(): void {
    Text(Localization.t('home_network_warning_short'))
      .fontSize(13)
      .fontColor(HaTheme.textSecondary(this.appResolvedDark))
      .lineHeight(19)
      .width('100%')
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
  }

  @Builder
  private renderConnectionPolicyGroup(): void {
    Column() {
      SettingsInlineSwitchRow({
        title: Localization.t('home_network_prioritize_internal'),
        summary: Localization.t('home_network_prioritize_internal_summary'),
        checked: this.prioritizeInternal,
        onChange: this.onPrioritizeChange
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
        this.renderDescription()
      }
      .width('100%')

      ListItem() {
        SettingsCategory({ title: 'Wi-Fi' })
      }
      .width('100%')

      ListItem() {
        this.renderWifiGroup()
      }
      .width('100%')

      if (this.wifiSsids.length > 0) {
        ListItem() {
          this.renderWarning()
        }
        .width('100%')
      }

      ListItem() {
        SettingsCategory({ title: Localization.t('home_network_connection_policy') })
      }
      .width('100%')

      ListItem() {
        this.renderConnectionPolicyGroup()
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
    .titleBar(SettingsUiConfig.titleBar(Localization.t('server_home_network'), this.onBack, this.appResolvedDark))
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
