import { HaColors } from '../../shared/constants/HaStyle';
import { AppIconView } from '../../shared/icons/AppIconView';
import { Localization } from '../../shared/i18n/Localization';
import { HaTheme } from '../../shared/theme/HaTheme';
import { SensorSettingsLiveRowState } from '../../services/SensorSettingsLiveStateStore';
import { SettingsUiConfig } from '../settings/components/SettingsUiConfig';

@Component
export struct SensorSettingsSwitchRow {
  @ObjectLink state: SensorSettingsLiveRowState;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @State private isTouched: boolean = false;
  @State private lastToggleAt: number = 0;
  onToggle: (id: string, enabled: boolean) => void = () => {};

  private acceptToggle(): boolean {
    const now = Date.now();
    if (now - this.lastToggleAt < 500) {
      return false;
    }
    this.lastToggleAt = now;
    return true;
  }

  private displaySummary(): string {
    if (!this.state.checked) {
      return Localization.t('sensor_disabled');
    }
    if (this.state.checked && this.state.summary.length > 0) {
      return this.state.summary;
    }
    return '';
  }

  private rowBackground(): string {
    if (this.isTouched) {
      return SettingsUiConfig.pressedBackground(this.appResolvedDark);
    }
    return SettingsUiConfig.transparentBackground;
  }

  build() {
    Row() {
      AppIconView({
        icon: this.state.icon,
        iconSize: 28,
        color: this.state.checked ? HaColors.SETTINGS_ACCENT : HaTheme.textSecondary(this.appResolvedDark)
      })

      Column({ space: 2 }) {
        Text(this.state.title)
          .fontSize(16)
          .fontColor(HaTheme.textPrimary(this.appResolvedDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.displaySummary().length > 0) {
          Text(this.displaySummary())
            .fontSize(14)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
            .lineHeight(20)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.state.checked })
        .width(36)
        .height(20)
        .selectedColor(HaColors.SETTINGS_SWITCH_THUMB_ON)
        .onChange((enabled: boolean) => {
          if (!this.acceptToggle()) {
            return;
          }
          this.onToggle(this.state.id, enabled);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: SettingsUiConfig.rowMinHeight })
    .borderRadius(SettingsUiConfig.rowRadius)
    .padding(SettingsUiConfig.rowPadding())
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.rowBackground())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isTouched = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isTouched = false;
      }
    })
  }
}
