import { HaColors } from '../../shared/constants/HaStyle';
import { Localization } from '../../shared/i18n/Localization';

@Component
export struct DashboardConnectionErrorDialog {
  onWait: () => void = () => {};
  onRefreshExternal: () => void = () => {};
  onOpenSettings: () => void = () => {};

  private message(): string {
    return Localization.t('dashboard_connection_error_message');
  }

  @Builder
  private actionButton(text: string, action: () => void): void {
    Button(text)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(HaColors.PRIMARY)
      .backgroundColor(Color.Transparent)
      .padding({ left: 4, right: 4, top: 8, bottom: 8 })
      .constraintSize({ minHeight: 36 })
      .width('100%')
      .onClick(action)
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(HaColors.SCRIM)

      Column({ space: 14 }) {
        Text(Localization.t('dashboard_connection_error_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(HaColors.TEXT_PRIMARY)
          .width('100%')
        Text(this.message())
          .fontSize(14)
          .fontColor(HaColors.TEXT_PRIMARY)
          .lineHeight(20)
          .width('100%')

        Row({ space: 0 }) {
          Column() {
            this.actionButton(Localization.t('dashboard_connection_wait'), this.onWait)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Column() {
            this.actionButton(Localization.t('dashboard_connection_refresh_external'), this.onRefreshExternal)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Column() {
            this.actionButton(Localization.t('block_insecure_open_settings'), this.onOpenSettings)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('86%')
      .constraintSize({ maxWidth: 500 })
      .padding({ left: 22, right: 22, top: 22, bottom: 14 })
      .backgroundColor(HaColors.SURFACE)
      .borderRadius(4)
      .shadow({
        radius: 18,
        color: '#33000000',
        offsetX: 0,
        offsetY: 8
      })
    }
    .width('100%')
    .height('100%')
  }
}
