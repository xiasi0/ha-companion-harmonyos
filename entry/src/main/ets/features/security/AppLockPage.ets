import { PrimaryButton } from '../../shared/components/PrimaryButton';
import { HaColors } from '../../shared/constants/HaStyle';
import { AppIconView } from '../../shared/icons/AppIconView';
import { systemIcon } from '../../shared/icons/AppIconModels';
import { Localization } from '../../shared/i18n/Localization';
import { HaTheme } from '../../shared/theme/HaTheme';

@Component
export struct AppLockPage {
  @Prop unlocking: boolean = false;
  @Prop dark: boolean = false;
  onUnlock: () => void = () => {};

  build() {
    Column({ space: 22 }) {
      AppIconView({
        icon: systemIcon('lock'),
        iconSize: 64,
        slotSize: 64,
        color: HaColors.PRIMARY
      })

      Text(Localization.t('app_lock_title'))
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor(HaTheme.textPrimary(this.dark))
        .textAlign(TextAlign.Center)

      Text(this.unlocking ? Localization.t('app_lock_waiting') : Localization.t('app_lock_body'))
        .fontSize(14)
        .fontColor(HaTheme.textSecondary(this.dark))
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .constraintSize({ maxWidth: 320 })

      if (this.unlocking) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(HaColors.PRIMARY)
      } else {
        PrimaryButton({
          text: Localization.t('app_lock_unlock'),
          maxWidth: 240,
          action: this.onUnlock
        })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24 })
    .backgroundColor(HaTheme.surface(this.dark))
  }
}
