import { SettingsCapability, SettingsItem, SettingsItemType } from '../../../models/SettingsItem';
import { HaColors } from '../../../shared/constants/HaStyle';
import { AppIconView } from '../../../shared/icons/AppIconView';
import { systemIcon } from '../../../shared/icons/AppIconModels';
import { Localization } from '../../../shared/i18n/Localization';
import { HaTheme } from '../../../shared/theme/HaTheme';
import { SettingsUiConfig } from './SettingsUiConfig';

@Component
export struct SettingsRow {
  @Prop
  item: SettingsItem = {
    type: SettingsItemType.DETAIL,
    icon: systemIcon(''),
    title: '',
    summary: '',
    status: '',
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
  @State private isTouched: boolean = false;
  onOpen: (item: SettingsItem) => void = () => {};
  onAction: (actionId: string) => void = () => {};

  private rowBackground(): string {
    if (this.active || this.isTouched) {
      return SettingsUiConfig.pressedBackground(this.appResolvedDark);
    }
    return SettingsUiConfig.transparentBackground;
  }

  private visibleStatus(): string {
    return this.item.status === Localization.t('common_available') ? '' : this.item.status;
  }

  private visibleBadge(): string {
    return this.item.badge ?? '';
  }

  private isInteractive(): boolean {
    return this.item.type !== SettingsItemType.INFO && this.item.actionId.length > 0;
  }

  build() {
    Row() {
      AppIconView({ icon: this.item.icon, color: HaColors.SETTINGS_ACCENT })

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
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)

      if (this.visibleStatus().length > 0) {
        Text(this.visibleStatus())
          .fontSize(14)
          .fontColor(HaTheme.textSecondary(this.appResolvedDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 8 })
      }

      if (this.visibleBadge().length > 0) {
        Text(this.visibleBadge())
          .fontSize(12)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .constraintSize({ minWidth: 20, minHeight: 20 })
          .padding({ left: 6, right: 6 })
          .backgroundColor(SettingsUiConfig.notificationEventColor)
          .borderRadius(10)
          .margin({ left: 8 })
      }

      if (this.isInteractive()) {
        AppIconView({
          icon: systemIcon('chevron_right'),
          color: HaTheme.textMuted(this.appResolvedDark)
        })
      } else {
        Blank()
          .width(56)
          .height(56)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: SettingsUiConfig.rowMinHeight })
    .borderRadius(SettingsUiConfig.rowRadius)
    .padding(SettingsUiConfig.rowPadding())
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.rowBackground())
    .onTouch((event: TouchEvent) => {
      if (!this.isInteractive()) {
        return;
      }
      if (event.type === TouchType.Down) {
        this.isTouched = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isTouched = false;
      }
    })
    .onClick(() => {
      if (!this.isInteractive()) {
        return;
      }
      if (this.item.type === SettingsItemType.ACTION) {
        this.onAction(this.item.actionId);
      } else {
        this.onOpen(this.item);
      }
    })
  }
}
