import { AppIconView } from '../../../shared/icons/AppIconView';
import { systemIcon } from '../../../shared/icons/AppIconModels';
import { HaTheme } from '../../../shared/theme/HaTheme';
import { SettingsUiConfig } from './SettingsUiConfig';

@Component
export struct SettingsContentRow {
  @Prop title: string = '';
  @Prop summary: string = '';
  @Prop showArrow: boolean = false;
  @Prop interactive: boolean = false;
  @Prop minHeight: number = SettingsUiConfig.rowMinHeight;
  @Prop titleSize: number = 16;
  @Prop summarySize: number = 14;
  @Prop titleLineHeight: number = 22;
  @Prop summaryLineHeight: number = 20;
  @Prop titleMaxLines: number = 1;
  @Prop summaryMaxLines: number = 2;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @State private isTouched: boolean = false;
  onOpen: () => void = () => {};

  private rowBackground(): string {
    if (this.interactive && this.isTouched) {
      return SettingsUiConfig.pressedBackground(this.appResolvedDark);
    }
    return SettingsUiConfig.transparentBackground;
  }

  build() {
    Row() {
      Column({ space: SettingsUiConfig.listSpace }) {
        Text(this.title)
          .fontSize(this.titleSize)
          .fontColor(HaTheme.textPrimary(this.appResolvedDark))
          .lineHeight(this.titleLineHeight)
          .maxLines(this.titleMaxLines)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.summary.length > 0) {
          Text(this.summary)
            .fontSize(this.summarySize)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
            .lineHeight(this.summaryLineHeight)
            .maxLines(this.summaryMaxLines)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.showArrow) {
        AppIconView({
          icon: systemIcon('chevron_right'),
          color: HaTheme.textMuted(this.appResolvedDark)
        })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: this.minHeight })
    .padding(SettingsUiConfig.rowPadding())
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.rowBackground())
    .onTouch((event: TouchEvent) => {
      if (!this.interactive) {
        return;
      }
      if (event.type === TouchType.Down) {
        this.isTouched = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isTouched = false;
      }
    })
    .onClick(() => {
      if (this.interactive) {
        this.onOpen();
      }
    })
  }
}
