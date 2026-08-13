import { AppIconView } from '../../shared/icons/AppIconView';
import { systemIcon } from '../../shared/icons/AppIconModels';
import { HaColors } from '../../shared/constants/HaStyle';
import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';

@Component
export struct TagReaderPage {
  @Prop completed: boolean = false;
  @Prop error: string = '';
  @Prop @Watch('onReaderUpdated') readerTick: number = 0;
  @State private sheetOffsetY: number = 360;
  @State private scrimOpacity: number = 0;
  @State private displayedCompleted: boolean = false;
  @State private displayedError: string = '';
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scheduledCloseTick: number = -1;
  private openTimer: number = -1;
  private resultTimer: number = -1;
  private closeTimer: number = -1;
  private entranceFinished: boolean = false;

  aboutToAppear(): void {
    this.entranceFinished = false;
    this.displayedCompleted = false;
    this.displayedError = '';
    this.openTimer = setTimeout((): void => {
      this.openTimer = -1;
      animateTo({ duration: 240, curve: Curve.EaseOut }, (): void => {
        this.sheetOffsetY = 0;
        this.scrimOpacity = 1;
      });
    }, 16);
    this.resultTimer = setTimeout((): void => {
      this.resultTimer = -1;
      this.entranceFinished = true;
      this.showCurrentResult();
    }, 256);
  }

  aboutToDisappear(): void {
    if (this.openTimer >= 0) {
      clearTimeout(this.openTimer);
      this.openTimer = -1;
    }
    if (this.resultTimer >= 0) {
      clearTimeout(this.resultTimer);
      this.resultTimer = -1;
    }
    this.clearCloseTimer();
  }

  private clearCloseTimer(): void {
    if (this.closeTimer >= 0) {
      clearTimeout(this.closeTimer);
      this.closeTimer = -1;
    }
  }

  private onReaderUpdated(): void {
    if (this.entranceFinished) {
      this.showCurrentResult();
    }
  }

  private showCurrentResult(): void {
    this.displayedCompleted = this.completed;
    this.displayedError = this.error;
    this.scheduleCloseIfFinished();
  }

  private scheduleCloseIfFinished(): void {
    if (!this.displayedCompleted) {
      this.clearCloseTimer();
      return;
    }
    if (this.scheduledCloseTick === this.readerTick) {
      return;
    }
    this.clearCloseTimer();
    const completedTick = this.readerTick;
    this.scheduledCloseTick = completedTick;
    this.closeTimer = setTimeout((): void => {
      this.closeTimer = -1;
      if (this.readerTick === completedTick && this.displayedCompleted) {
        this.close();
      }
    }, 1600);
  }

  onClose: () => void = () => {};

  private close(): void { this.onClose(); }

  private title(): string {
    return this.displayedCompleted
      ? (this.displayedError.length > 0 ? Localization.t('nfc_tag_failed') : Localization.t('nfc_tag_triggered'))
      : Localization.t('nfc_tag_processing');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(`rgba(0, 0, 0, ${0.38 * this.scrimOpacity})`)

      Column({ space: 12 }) {
        Row() {
          AppIconView({
            icon: systemIcon('nfc'),
            iconSize: 28,
            slotSize: 48,
            color: HaColors.SETTINGS_ACCENT
          })

          Text(this.title())
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(HaTheme.textPrimary(this.appResolvedDark))
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')

        if (!this.displayedCompleted) {
          Text(Localization.t('nfc_processing'))
            .fontSize(16)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
            .textAlign(TextAlign.Center)
            .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 24, bottom: 36 })
      .backgroundColor(HaTheme.surface(this.appResolvedDark))
      .borderRadius({ topLeft: 26, topRight: 26 })
      .shadow({ radius: 18, color: HaColors.SCRIM, offsetX: 0, offsetY: -4 })
      .translate({ x: 0, y: this.sheetOffsetY })
    }
    .width('100%')
    .height('100%')
  }
}
