import { Localization } from '../../shared/i18n/Localization';
import { HaTheme } from '../../shared/theme/HaTheme';
import { SettingsBoundary } from '../settings/components/SettingsBoundary';
import { SettingsRadioRow } from '../settings/components/SettingsRadioRow';
import { SettingsUiConfig } from '../settings/components/SettingsUiConfig';
import { SensorUpdateFrequency } from './SensorModels';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct SensorUpdateFrequencyPage {
  @Prop
  selected: string = SensorUpdateFrequency.NORMAL;
  @Prop
  contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onSelect: (value: string) => void = () => {};
  onSwipeBack: () => void = () => {};

  private titleFor(value: string): string {
    if (value === SensorUpdateFrequency.FAST_WHILE_CHARGING) {
      return Localization.t('sensor_frequency_fast_charging');
    }
    if (value === SensorUpdateFrequency.FAST_ALWAYS) {
      return Localization.t('sensor_frequency_fast_always');
    }
    return Localization.t('sensor_frequency_normal');
  }

  private bodyFor(value: string): string {
    if (value === SensorUpdateFrequency.FAST_WHILE_CHARGING) {
      return Localization.t('sensor_frequency_fast_charging_desc');
    }
    if (value === SensorUpdateFrequency.FAST_ALWAYS) {
      return Localization.t('sensor_frequency_fast_always_desc');
    }
    return Localization.t('sensor_frequency_normal_desc');
  }

  @Builder
  private renderOption(value: string): void {
    SettingsRadioRow({
      title: this.titleFor(value),
      summary: this.bodyFor(value),
      selected: this.selected === value,
      minHeight: 112,
      summaryMaxLines: 4,
      onSelect: (): void => {
        this.onSelect(value);
      }
    })
  }

  @Builder
  private renderInfo(): void {
    Row({ space: 12 }) {
      Text('i')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(SettingsUiConfig.accentColor)
        .textAlign(TextAlign.Center)
        .width(24)
        .height(24)
        .border({ width: 1, color: SettingsUiConfig.accentColor })
        .borderRadius(12)

      Text(Localization.t('sensor_frequency_notice'))
        .fontSize(14)
        .fontColor(HaTheme.textPrimary(this.appResolvedDark))
        .lineHeight(20)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(SettingsUiConfig.noticeBackgroundColor)
    .borderRadius(16)
  }

  @Builder
  private renderPageContent(): void {
    Scroll(this.scroller) {
      Column({ space: SettingsUiConfig.listSpace }) {
        Column() {
          Text(Localization.t('sensor_frequency_body'))
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
        .padding(SettingsUiConfig.groupPadding)

        Column() {
          this.renderOption(SensorUpdateFrequency.NORMAL)
          SettingsBoundary()
          this.renderOption(SensorUpdateFrequency.FAST_WHILE_CHARGING)
          SettingsBoundary()
          this.renderOption(SensorUpdateFrequency.FAST_ALWAYS)
        }
        .width('100%')
        .borderRadius(SettingsUiConfig.groupRadius)
        .backgroundColor(HaTheme.surface(this.appResolvedDark))
        .shadow(SettingsUiConfig.groupShadow())
        .padding(SettingsUiConfig.groupPadding)

        Column()
          .height(4)

        this.renderInfo()
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth })
      .padding(SettingsUiConfig.scrollContentPadding())
    }
    .layoutWeight(1)
    .width('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
    .titleBar(SettingsUiConfig.titleBar(Localization.t('settings_sensor_update_frequency'), this.onBack, this.appResolvedDark, this.onHelp))
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
