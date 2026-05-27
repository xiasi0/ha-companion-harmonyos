import { Localization } from '../../shared/i18n/Localization';
import { CardEntityDetailLaunchService } from '../../features/cards/CardEntityDetailLaunchService';
import { CardRefreshTicker } from '../components/CardRefreshTicker';
import { ServiceCardUiConfig } from '../components/ServiceCardUiConfig';

let harmonyMediaServiceCardStorage = new LocalStorage();

@Entry(harmonyMediaServiceCardStorage)
@Component
struct HarmonyMediaServiceCard {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('bound') bound: boolean = false;
  @LocalStorageProp('targetId') targetId: string = '';
  @LocalStorageProp('serverInstanceId') serverInstanceId: string = '';
  @LocalStorageProp('openEntityDetailEnabled') openEntityDetailEnabled: boolean = false;
  @LocalStorageProp('title') title: string = Localization.t('card_media_control_title');
  @LocalStorageProp('subtitle') subtitle: string = Localization.t('card_bind_media_player');
  @LocalStorageProp('state') state: string = 'unknown';
  @LocalStorageProp('mediaTitle') mediaTitle: string = Localization.t('card_choose_player');
  @LocalStorageProp('mediaArtist') mediaArtist: string = '';
  @LocalStorageProp('appName') appName: string = '';
  @LocalStorageProp('coverUrl') coverUrl: string = '';
  @LocalStorageProp('coverImageName') coverImageName: string = '';
  @LocalStorageProp('surfaceColor') surfaceColor: string = '#FFFFFF';
  @LocalStorageProp('primaryTextColor') primaryTextColor: string = ServiceCardUiConfig.textPrimary;
  @LocalStorageProp('secondaryTextColor') secondaryTextColor: string = ServiceCardUiConfig.textSecondary;
  @LocalStorageProp('disabledTextColor') disabledTextColor: string = '#97A2AA';
  @LocalStorageProp('trackColor') trackColor: string = '#D7DEE4';
  @LocalStorageProp('updateFrequency') updateFrequency: string = 'default';

  build() {
    Stack() {
      if (this.bound) {
        this.boundCard()
      } else {
        this.unboundCard()
      }

      CardRefreshTicker({ updateFrequency: this.updateFrequency })
        .position({ x: 6, y: 6 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private unboundCard(): void {
    Stack() {
      this.unboundBackground()

      Column({ space: ServiceCardUiConfig.defaultVerticalGap }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(ServiceCardUiConfig.defaultSymbolSize)
            .fontWeight(FontWeight.Medium)
            .fontColor([ServiceCardUiConfig.brand])
        }
        .width(ServiceCardUiConfig.iconButtonSize)
        .height(ServiceCardUiConfig.iconButtonSize)
        .borderRadius(ServiceCardUiConfig.iconButtonRadius)
        .backgroundColor(ServiceCardUiConfig.buttonBackground)

        Text(Localization.t('card_media_control_title'))
          .fontSize(ServiceCardUiConfig.defaultTitleTextSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(ServiceCardUiConfig.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(Localization.t('card_bind_media_player'))
          .fontSize(ServiceCardUiConfig.defaultSubtitleTextSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(ServiceCardUiConfig.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height('100%')
      .padding(ServiceCardUiConfig.pagePadding)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => this.openEditPage())
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private boundCard(): void {
    Stack({ alignContent: Alignment.Start }) {
      Rect()
        .width('100%')
        .height('100%')
        .fill(this.cardSurfaceColor())

      this.coverArea()
      this.contentArea()
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }

  @Builder
  private unboundBackground(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Image($r('app.media.ha_brand'))
        .width(ServiceCardUiConfig.unboundBrandWatermarkSize)
        .height(ServiceCardUiConfig.unboundBrandWatermarkSize)
        .opacity(0.08)
        .margin({ right: ServiceCardUiConfig.watermarkMargin, bottom: ServiceCardUiConfig.watermarkMargin })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private coverArea(): void {
    Stack({ alignContent: Alignment.End }) {
      Stack() {
        ForEach([this.coverVisualKey()], (item: string) => {
          if (this.hasCover()) {
            Image(this.coverSource())
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .transition(TransitionEffect.OPACITY.animation({
                duration: ServiceCardUiConfig.fadeDurationMs,
                curve: Curve.Smooth
              }))
          } else {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(64)
              .fontColor([this.disabledColor()])
              .opacity(0.20)
              .transition(TransitionEffect.OPACITY.animation({
                duration: ServiceCardUiConfig.fadeDurationMs,
                curve: Curve.Smooth
              }))
          }
        }, (item: string) => item)
      }
      .width('56%')
      .height('100%')
      .backgroundColor(this.trackColorValue())
      .overlay(this.coverFadeMask())
      .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
    }
    .width('100%')
    .height('100%')
    .onClick(() => this.openEntityDetail())
  }

  @Builder
  private coverFadeMask(): void {
    Stack()
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 90,
        colors: [
          ['#00FFFFFF', 0.00],
          ['#33FFFFFF', 0.18],
          ['#DDFFFFFF', 0.58],
          ['#FFFFFFFF', 1.00]
        ]
      })
      .blendMode(BlendMode.DST_IN, BlendApplyType.OFFSCREEN)
  }

  @Builder
  private contentArea(): void {
    Column() {
      this.detailContentArea()

      Row() {
        this.controlButton('previous', $r('sys.symbol.backward_end_fill'))
        this.controlGap()
        this.playPauseButton()
        this.controlGap()
        this.controlButton('next', $r('sys.symbol.forward_end_fill'))
        Blank()
          .layoutWeight(1)
          .height(ServiceCardUiConfig.controlButtonSize)
          .onClick(() => this.openEntityDetail())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Start)
    }
    .width('58%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private detailContentArea(): void {
    Column() {
      Column({ space: 3 }) {
        ForEach([this.mediaTitleText()], (item: string) => {
          Text(item)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryColor())
            .opacity(0.88)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .transition(TransitionEffect.OPACITY.animation({
              duration: ServiceCardUiConfig.fadeDurationMs,
              curve: Curve.Smooth
            }))
        }, (item: string) => `title-${item}`)

        ForEach([this.mediaArtistText()], (item: string) => {
          Text(item)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.secondaryColor())
            .opacity(0.72)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .transition(TransitionEffect.OPACITY.animation({
              duration: ServiceCardUiConfig.fadeDurationMs,
              curve: Curve.Smooth
            }))
        }, (item: string) => `artist-${item}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => this.openEntityDetail())
  }

  @Builder
  private controlGap(): void {
    Blank()
      .width(12)
      .height(ServiceCardUiConfig.controlButtonSize)
      .onClick(() => this.openEntityDetail())
  }

  @Builder
  private controlButton(action: string, icon: Resource): void {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(icon)
        .fontSize(action === 'play_pause' ? 26 : 23)
        .fontColor([this.primaryColor()])
        .opacity(action === 'play_pause' ? 0.92 : 0.72)
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
    }
    .width(ServiceCardUiConfig.controlButtonSize)
    .height(ServiceCardUiConfig.controlButtonSize)
    .borderRadius(ServiceCardUiConfig.controlButtonRadius)
    .backgroundColor(this.controlBackgroundColor())
    .onClick(() => {
      postCardAction(this, {
        action: 'message',
        params: {
          event: `media_${action}`
        }
      });
    })
  }

  @Builder
  private playPauseButton(): void {
    Stack({ alignContent: Alignment.Center }) {
      ForEach([this.playPauseIconKey()], (item: string) => {
        SymbolGlyph(item === 'pause' ? $r('sys.symbol.pause') : $r('sys.symbol.play_fill'))
          .fontSize(26)
          .fontColor([this.primaryColor()])
          .opacity(0.92)
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), true)
      }, (item: string) => item)
    }
    .width(ServiceCardUiConfig.controlButtonSize)
    .height(ServiceCardUiConfig.controlButtonSize)
    .borderRadius(ServiceCardUiConfig.controlButtonRadius)
    .backgroundColor(this.controlBackgroundColor())
    .onClick(() => {
      postCardAction(this, {
        action: 'message',
        params: {
          event: 'media_play_pause'
        }
      });
    })
  }

  private openEditPage(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryCardEditAbility',
      params: {
        formId: this.formId,
        'ohos.extra.param.key.edit_form_id': this.formId,
        cardType: 'media'
      }
      });
  }

  private openEntityDetail(): void {
    if (!this.bound || !this.openEntityDetailEnabled || this.targetId.trim().length === 0) {
      return;
    }
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        action: CardEntityDetailLaunchService.ACTION,
        entityId: this.targetId,
        serverInstanceId: this.serverInstanceId,
        formId: this.formId
      }
    });
  }

  private coverSource(): string | Resource {
    if (this.coverImageName.length > 0) {
      return `memory://${this.coverImageName}`;
    }
    return $r('app.media.ha_brand');
  }

  private hasCover(): boolean {
    return this.coverImageName.length > 0;
  }

  private coverVisualKey(): string {
    return this.hasCover() ? `cover-${this.coverImageName}` : 'cover-empty';
  }

  private playPauseIconKey(): string {
    return this.isPlaying() ? 'pause' : 'play';
  }

  private isPlaying(): boolean {
    return this.state.trim().toLowerCase() === 'playing';
  }

  private mediaTitleText(): string {
    if (this.mediaTitle.trim().length > 0) {
      return this.mediaTitle;
    }
    return this.title.trim().length > 0 ? this.title : Localization.t('card_media_control_title');
  }

  private mediaArtistText(): string {
    if (this.mediaArtist.trim().length > 0) {
      return this.mediaArtist;
    }
    if (this.appName.trim().length > 0) {
      return this.appName;
    }
    return this.title.trim().length > 0 ? this.title : Localization.t('state_unknown');
  }

  private subtitleText(): string {
    return this.subtitle.trim().length > 0 ? this.subtitle : Localization.t('state_unknown');
  }

  private cardSurfaceColor(): string {
    return this.surfaceColor.trim().length > 0 ? this.surfaceColor : '#FFFFFF';
  }

  private primaryColor(): string {
    return this.primaryTextColor.trim().length > 0 ? this.primaryTextColor : ServiceCardUiConfig.textPrimary;
  }

  private secondaryColor(): string {
    return this.secondaryTextColor.trim().length > 0 ? this.secondaryTextColor : ServiceCardUiConfig.textSecondary;
  }

  private disabledColor(): string {
    return this.disabledTextColor.trim().length > 0 ? this.disabledTextColor : '#97A2AA';
  }

  private trackColorValue(): string {
    return this.trackColor.trim().length > 0 ? this.trackColor : '#D7DEE4';
  }

  private controlBackgroundColor(): string {
    return this.trackColorValue();
  }
}
