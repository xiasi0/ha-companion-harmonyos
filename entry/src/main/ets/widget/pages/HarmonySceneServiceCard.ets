import { Localization } from '../../shared/i18n/Localization';
import { CardEntityDetailLaunchService } from '../../features/cards/CardEntityDetailLaunchService';
import { CardRefreshTicker } from '../components/CardRefreshTicker';
import { ServiceCardUiConfig } from '../components/ServiceCardUiConfig';

let harmonySceneServiceCardStorage = new LocalStorage();

@Entry(harmonySceneServiceCardStorage)
@Component
struct HarmonySceneServiceCard {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('bound') bound: boolean = false;
  @LocalStorageProp('targetId') targetId: string = '';
  @LocalStorageProp('serverInstanceId') serverInstanceId: string = '';
  @LocalStorageProp('openEntityDetailEnabled') openEntityDetailEnabled: boolean = false;
  @LocalStorageProp('title') title: string = Localization.t('card_scene_control_title');
  @LocalStorageProp('subtitle') subtitle: string = Localization.t('card_bind_scene');
  @LocalStorageProp('state') state: string = 'unknown';
  @LocalStorageProp('updateFrequency') updateFrequency: string = 'default';

  build() {
    Stack() {
      this.cardBackground()

      if (this.bound) {
        this.boundContent()
      } else {
        this.unboundContent()
      }

      CardRefreshTicker({ updateFrequency: this.updateFrequency })
        .position({ x: 6, y: 6 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private unboundContent(): void {
    Row({ space: ServiceCardUiConfig.compactHorizontalGap }) {
      this.plusButton()

      Column({ space: ServiceCardUiConfig.defaultTextGap }) {
        this.titleText(Localization.t('card_scene_control_title'))
        this.subtitleText(Localization.t('card_bind_scene'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding(ServiceCardUiConfig.pagePadding)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.openEditPage())
  }

  @Builder
  private boundContent(): void {
    Row({ space: ServiceCardUiConfig.compactHorizontalGap }) {
      Column({ space: ServiceCardUiConfig.defaultTextGap }) {
        this.titleText(this.displayTitle())
        if (this.displaySubtitle().length > 0) {
          this.subtitleText(this.displaySubtitle())
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => this.openEntityDetail())

      this.activateButton()
    }
    .width('100%')
    .height('100%')
    .padding(ServiceCardUiConfig.pagePadding)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private titleText(value: string): void {
    Text(value)
      .fontSize(ServiceCardUiConfig.defaultTitleTextSize)
      .fontWeight(FontWeight.Medium)
      .fontColor(ServiceCardUiConfig.textPrimary)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
  }

  @Builder
  private subtitleText(value: string): void {
    Text(value)
      .fontSize(ServiceCardUiConfig.defaultSubtitleTextSize)
      .fontWeight(FontWeight.Medium)
      .fontColor(ServiceCardUiConfig.textSecondary)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
  }

  @Builder
  private plusButton(): void {
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
  }

  @Builder
  private activateButton(): void {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(ServiceCardUiConfig.defaultSymbolSize)
        .fontWeight(FontWeight.Medium)
        .fontColor([ServiceCardUiConfig.brand])
    }
    .width(ServiceCardUiConfig.iconButtonSize)
    .height(ServiceCardUiConfig.iconButtonSize)
    .borderRadius(ServiceCardUiConfig.iconButtonRadius)
    .backgroundColor(ServiceCardUiConfig.buttonBackground)
    .onClick(() => {
      postCardAction(this, {
        action: 'message',
        params: {
          event: 'activate_scene'
        }
      });
    })
  }

  @Builder
  private cardBackground(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (!this.bound) {
        Image($r('app.media.ha_brand'))
          .width(ServiceCardUiConfig.compactBrandWatermarkSize)
          .height(ServiceCardUiConfig.compactBrandWatermarkSize)
          .opacity(0.08)
          .margin({ right: ServiceCardUiConfig.watermarkMargin, bottom: ServiceCardUiConfig.watermarkMargin })
      }
    }
    .width('100%')
    .height('100%')
  }

  private openEditPage(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryCardEditAbility',
      params: {
        formId: this.formId,
        'ohos.extra.param.key.edit_form_id': this.formId,
        cardType: 'scene'
      }
    });
  }

  private displayTitle(): string {
    return this.title.trim().length > 0 ? this.title : Localization.t('card_scene_control_title');
  }

  private displaySubtitle(): string {
    return this.subtitle.trim();
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
}
