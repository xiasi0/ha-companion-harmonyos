import { SettingsItem, SettingsItemType } from '../../../models/SettingsItem';
import { Localization } from '../../../shared/i18n/Localization';
import { HaTheme } from '../../../shared/theme/HaTheme';
import { SettingsLiveRowState, SettingsLiveStateStore } from '../../../services/SettingsLiveStateStore';
import { SettingsIcon } from './SettingsIcon';
import { SettingsUiConfig } from './SettingsUiConfig';

@Component
export struct SettingsLiveRow {
  @ObjectLink state: SettingsLiveRowState;
  @Prop active: boolean = false;
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
    return this.state.status === Localization.t('common_available') ? '' : this.state.status;
  }

  private visibleBadge(): string {
    return this.state.badge ?? '';
  }

  private isInteractive(): boolean {
    return this.state.type !== SettingsItemType.INFO && this.state.actionId.length > 0;
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
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(24)
          .fontColor([HaTheme.textMuted(this.appResolvedDark)])
          .width(56)
          .height(56)
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
      if (this.state.type === SettingsItemType.ACTION) {
        this.onAction(this.state.actionId);
      } else {
        this.onOpen(SettingsLiveStateStore.toItem(this.state));
      }
    })
  }
}
