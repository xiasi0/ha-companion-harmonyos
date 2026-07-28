import { Localization } from '../../shared/i18n/Localization';
import { CardEntityDetailLaunchService } from '../../features/cards/CardEntityDetailLaunchService';
import { CardRefreshTicker } from '../components/CardRefreshTicker';
import { ServiceCardUiConfig } from '../components/ServiceCardUiConfig';
import { AppIconView } from '../../shared/icons/AppIconView';
import { systemIcon } from '../../shared/icons/AppIconModels';

let harmonyClimateServiceCardStorage = new LocalStorage();

@Entry(harmonyClimateServiceCardStorage)
@Component
struct HarmonyClimateServiceCard {
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('bound') bound: boolean = false;
  @LocalStorageProp('targetId') targetId: string = '';
  @LocalStorageProp('serverInstanceId') serverInstanceId: string = '';
  @LocalStorageProp('openEntityDetailEnabled') openEntityDetailEnabled: boolean = false;
  @LocalStorageProp('title') title: string = Localization.t('card_climate_control_title');
  @LocalStorageProp('subtitle') subtitle: string = Localization.t('card_bind_climate');
  @LocalStorageProp('state') state: string = 'unknown';
  @LocalStorageProp('targetTemperature') targetTemperature: string = '';
  @LocalStorageProp('temperatureUnit') temperatureUnit: string = '°C';
  @LocalStorageProp('supportsAuto') supportsAuto: boolean = false;
  @LocalStorageProp('supportsCool') supportsCool: boolean = false;
  @LocalStorageProp('supportsHeat') supportsHeat: boolean = false;
  @LocalStorageProp('updateFrequency') updateFrequency: string = 'default';

  build() {
    Stack() {
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
  private boundContent(): void {
    Column() {
      this.header()

      Blank()
        .layoutWeight(1)
        .onClick(() => this.openEntityDetail())

      this.temperatureControl()
      this.modeControl()
    }
    .width('100%')
    .height('100%')
    .padding(ServiceCardUiConfig.pagePadding)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private header(): void {
    Row() {
      Column({ space: ServiceCardUiConfig.defaultTextGap }) {
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

      Stack({ alignContent: Alignment.Center }) {
        AppIconView({
          icon: systemIcon('power'),
          iconSize: 20,
          slotSize: ServiceCardUiConfig.controlButtonSize,
          color: this.isOff() ? ServiceCardUiConfig.textSecondary : ServiceCardUiConfig.brand
        })
      }
      .width(ServiceCardUiConfig.controlButtonSize)
      .height(ServiceCardUiConfig.controlButtonSize)
      .borderRadius(ServiceCardUiConfig.controlButtonRadius)
      .backgroundColor(ServiceCardUiConfig.buttonBackground)
      .onClick(() => this.sendEvent('toggle_climate_power'))
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private temperatureControl(): void {
    Row() {
      this.temperatureAction('minus', 'climate_temperature_down')

      Row({ space: 4 }) {
        Text(Localization.t('card_climate_target_temperature'))
          .fontSize(ServiceCardUiConfig.defaultSubtitleTextSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(ServiceCardUiConfig.textSecondary)

        Row({ space: 4 }) {
          Text(this.targetTemperatureText())
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(ServiceCardUiConfig.textPrimary)

          Text(this.temperatureUnitText())
            .fontSize(ServiceCardUiConfig.defaultTitleTextSize)
            .fontWeight(FontWeight.Medium)
            .fontColor(ServiceCardUiConfig.textSecondary)
        }
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)

      this.temperatureAction('plus', 'climate_temperature_up')
    }
    .width('66.67%')
    .height(32)
    .padding({ left: 4, right: 4 })
    .borderRadius(16)
    .backgroundColor(ServiceCardUiConfig.buttonBackground)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private temperatureAction(iconName: string, event: string): void {
    Stack({ alignContent: Alignment.Center }) {
      AppIconView({
        icon: systemIcon(iconName),
        iconSize: 20,
        slotSize: 32,
        color: ServiceCardUiConfig.textPrimary
      })
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .onClick(() => this.sendEvent(event))
  }

  @Builder
  private modeControl(): void {
    Row() {
      this.modeItem(Localization.t('card_climate_mode_auto'), 'auto', this.supportsAuto)
      this.modeItem(Localization.t('card_climate_mode_cool'), 'cool', this.supportsCool)
      this.modeItem(Localization.t('card_climate_mode_heat'), 'heat', this.supportsHeat)
    }
    .width('66.67%')
    .height(32)
    .margin({ top: 4 })
    .padding(2)
    .borderRadius(16)
    .backgroundColor(ServiceCardUiConfig.buttonBackground)
  }

  @Builder
  private modeItem(label: string, mode: string, supported: boolean): void {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.modeTextColor(mode, supported))
      .layoutWeight(1)
      .height('100%')
      .textAlign(TextAlign.Center)
      .borderRadius(14)
      .backgroundColor(this.state === mode ? '#FFFFFF' : Color.Transparent)
      .opacity(supported ? 1 : 0.35)
      .onClick(() => {
        if (supported) {
          this.sendEvent(`climate_mode_${mode}`);
        }
      })
  }

  @Builder
  private unboundContent(): void {
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

        Text(Localization.t('card_climate_control_title'))
          .fontSize(ServiceCardUiConfig.defaultTitleTextSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(ServiceCardUiConfig.textPrimary)

        Text(Localization.t('card_bind_climate'))
          .fontSize(ServiceCardUiConfig.defaultSubtitleTextSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(ServiceCardUiConfig.textSecondary)
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

  private displayTitle(): string {
    return this.title.trim().length > 0 ? this.title : Localization.t('card_climate_control_title');
  }

  private displaySubtitle(): string {
    return this.subtitle.trim().length > 0 ? this.subtitle : Localization.t('state_unknown');
  }

  private targetTemperatureText(): string {
    return this.targetTemperature.trim().length > 0 ? this.targetTemperature : '--';
  }

  private temperatureUnitText(): string {
    return this.temperatureUnit.trim().length > 0 ? this.temperatureUnit : '°C';
  }

  private modeTextColor(mode: string, supported: boolean): string {
    if (!supported) {
      return ServiceCardUiConfig.textSecondary;
    }
    return this.state === mode ? ServiceCardUiConfig.textPrimary : ServiceCardUiConfig.textSecondary;
  }

  private isOff(): boolean {
    return this.state === 'off';
  }

  private sendEvent(event: string): void {
    postCardAction(this, {
      action: 'message',
      params: { event }
    });
  }

  private openEditPage(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryCardEditAbility',
      params: {
        formId: this.formId,
        'ohos.extra.param.key.edit_form_id': this.formId,
        cardType: 'climate'
      }
    });
  }

  private openEntityDetail(): void {
    if (!this.openEntityDetailEnabled || this.targetId.trim().length === 0) {
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
