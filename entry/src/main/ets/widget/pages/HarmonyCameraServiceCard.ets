import { Localization } from '../../shared/i18n/Localization';
import { CardEntityDetailLaunchService } from '../../features/cards/CardEntityDetailLaunchService';
import { CardRefreshTicker } from '../components/CardRefreshTicker';
import { ServiceCardUiConfig } from '../components/ServiceCardUiConfig';
import { AppIconView } from '../../shared/icons/AppIconView';
import { systemIcon } from '../../shared/icons/AppIconModels';

let harmonyCameraServiceCardStorage = new LocalStorage();

@Entry(harmonyCameraServiceCardStorage)
@Component
struct HarmonyCameraServiceCard {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('bound') bound: boolean = false;
  @LocalStorageProp('targetId') targetId: string = '';
  @LocalStorageProp('serverInstanceId') serverInstanceId: string = '';
  @LocalStorageProp('openEntityDetailEnabled') openEntityDetailEnabled: boolean = false;
  @LocalStorageProp('title') title: string = Localization.t('card_camera_control_title');
  @LocalStorageProp('subtitle') subtitle: string = Localization.t('card_bind_camera');
  @LocalStorageProp('coverImageName') coverImageName: string = '';
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
    Stack({ alignContent: Alignment.BottomEnd }) {
      Image($r('app.media.ha_brand'))
        .width(ServiceCardUiConfig.unboundBrandWatermarkSize)
        .height(ServiceCardUiConfig.unboundBrandWatermarkSize)
        .opacity(0.08)
        .margin({ right: ServiceCardUiConfig.watermarkMargin, bottom: ServiceCardUiConfig.watermarkMargin })

      Column({ space: ServiceCardUiConfig.defaultVerticalGap }) {
        Stack({ alignContent: Alignment.Center }) {
          AppIconView({
            icon: systemIcon('plus'),
            iconSize: ServiceCardUiConfig.defaultSymbolSize,
            slotSize: ServiceCardUiConfig.iconButtonSize,
            color: ServiceCardUiConfig.brand
          })
        }
        .width(ServiceCardUiConfig.iconButtonSize)
        .height(ServiceCardUiConfig.iconButtonSize)
        .borderRadius(ServiceCardUiConfig.iconButtonRadius)
        .backgroundColor(ServiceCardUiConfig.buttonBackground)

        Text(Localization.t('card_camera_control_title'))
          .fontSize(ServiceCardUiConfig.defaultTitleTextSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(ServiceCardUiConfig.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(Localization.t('card_bind_camera'))
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
    Stack({ alignContent: Alignment.TopEnd }) {
      Rect()
        .width('100%')
        .height('100%')
        .fill('#F7FAFC')

      Stack({ alignContent: Alignment.Center }) {
        if (this.hasCover()) {
          Image(this.coverSource())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else {
          Image($r('app.media.ha_brand'))
            .width(ServiceCardUiConfig.unboundBrandWatermarkSize)
            .height(ServiceCardUiConfig.unboundBrandWatermarkSize)
            .opacity(0.15)
        }
      }
      .width('100%')
      .height('100%')
      .onClick(() => this.openEntityDetail())

      Row({ space: ServiceCardUiConfig.defaultTextGap }) {
        Column({ space: 2 }) {
          Text(this.displayTitle())
            .fontSize(ServiceCardUiConfig.defaultTitleTextSize)
            .fontWeight(FontWeight.Medium)
            .fontColor(ServiceCardUiConfig.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.displaySubtitle())
            .fontSize(ServiceCardUiConfig.defaultSubtitleTextSize)
            .fontWeight(FontWeight.Medium)
            .fontColor(ServiceCardUiConfig.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => this.openEntityDetail())

        this.refreshButton()
      }
      .width('100%')
      .padding(ServiceCardUiConfig.pagePadding)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }

  @Builder
  private refreshButton(): void {
    Stack({ alignContent: Alignment.Center }) {
      AppIconView({
        icon: systemIcon('refresh'),
        iconSize: 20,
        slotSize: ServiceCardUiConfig.controlButtonSize,
        color: ServiceCardUiConfig.brand
      })
    }
    .width(ServiceCardUiConfig.controlButtonSize)
    .height(ServiceCardUiConfig.controlButtonSize)
    .borderRadius(ServiceCardUiConfig.controlButtonRadius)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      postCardAction(this, {
        action: 'message',
        params: {
          event: 'refresh_camera'
        }
      });
    })
  }

  private coverSource(): string | Resource {
    return this.hasCover() ? `memory://${this.coverImageName}` : $r('app.media.ha_brand');
  }

  private hasCover(): boolean {
    return this.coverImageName.length > 0;
  }

  private displayTitle(): string {
    return this.title.trim().length > 0 ? this.title : Localization.t('card_camera_control_title');
  }

  private displaySubtitle(): string {
    return this.subtitle.trim().length > 0 ? this.subtitle : Localization.t('state_unknown');
  }

  private openEditPage(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryCardEditAbility',
      params: {
        formId: this.formId,
        'ohos.extra.param.key.edit_form_id': this.formId,
        cardType: 'camera'
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
}
