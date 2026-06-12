import { SettingsItem } from '../../../models/SettingsItem';
import { HaColors } from '../../../shared/constants/HaStyle';
import { HaTheme } from '../../../shared/theme/HaTheme';
import { SettingsLiveRowState, SettingsLiveStateStore } from '../../../services/SettingsLiveStateStore';
import { SettingsIcon } from './SettingsIcon';
import { SettingsUiConfig } from './SettingsUiConfig';

@Component
export struct SettingsLiveSwitchRow {
  @ObjectLink state: SettingsLiveRowState;
  @Prop active: boolean = false;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @State private isTouched: boolean = false;
  @State private lastToggleAt: number = 0;
  onOpen: (item: SettingsItem) => void = () => {};

  private acceptToggle(): boolean {
    const now = Date.now();
    if (now - this.lastToggleAt < 500) {
      return false;
    }
    this.lastToggleAt = now;
    return true;
  }

  private rowBackground(): string {
    if (this.active || this.isTouched) {
      return SettingsUiConfig.pressedBackground(this.appResolvedDark);
    }
    return SettingsUiConfig.transparentBackground;
  }

  build() {
    Row() {
      SettingsIcon({ label: this.state.icon })

      Column({ space: 2 }) {
        Text(this.state.title)
          .fontSize(16)
          .fontColor(HaTheme.textPrimary(this.appResolvedDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.state.summary.length > 0) {
          Text(this.state.summary)
            .fontSize(14)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
            .lineHeight(20)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.state.isOn })
        .width(36)
        .height(20)
        .selectedColor(HaColors.SETTINGS_SWITCH_THUMB_ON)
        .onChange(() => {
          if (!this.acceptToggle()) {
            return;
          }
          this.onOpen(SettingsLiveStateStore.toItem(this.state));
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
