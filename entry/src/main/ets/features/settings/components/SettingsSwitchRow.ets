import { SettingsCapability, SettingsItem, SettingsItemType } from '../../../models/SettingsItem';
import { HaColors } from '../../../shared/constants/HaStyle';
import { Localization } from '../../../shared/i18n/Localization';
import { HaTheme } from '../../../shared/theme/HaTheme';
import { SettingsIcon } from './SettingsIcon';
import { SettingsUiConfig } from './SettingsUiConfig';

@Component
export struct SettingsSwitchRow {
  @Prop @Watch('syncChecked')
  isOn: boolean = false;
  @Prop
  syncRevision: number = 0;
  @Prop
  item: SettingsItem = {
    type: SettingsItemType.SWITCH,
    icon: '',
    title: '',
    summary: '',
    status: Localization.t('settings_switch_pending'),
    body: '',
    action: '',
    actionId: '',
    badge: '',
    isOn: false,
    capability: SettingsCapability.NONE
  };
  @Prop
  active: boolean = false;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @State private checked: boolean = false;
  @State private isTouched: boolean = false;
  @State private lastToggleAt: number = 0;
  onOpen: (item: SettingsItem) => void = () => {};

  aboutToAppear(): void {
    this.syncChecked();
  }

  private syncChecked(): void {
    if (this.checked !== this.isOn) {
      this.checked = this.isOn;
    }
  }

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
      SettingsIcon({ label: this.item.icon })

      Column({ space: 2 }) {
        Text(this.item.title)
          .fontSize(16)
          .fontColor(HaTheme.textPrimary(this.appResolvedDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.item.summary.length > 0) {
          Text(this.item.summary)
            .fontSize(14)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
            .lineHeight(20)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .width(36)
        .height(20)
        .selectedColor(HaColors.SETTINGS_SWITCH_THUMB_ON)
        .onChange((value: boolean) => {
          if (!this.acceptToggle()) {
            return;
          }
          this.checked = value;
          this.onOpen(this.item);
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
