import { HaServerItem } from '../../models/HaServerItem';
import { HaLogo } from '../../shared/components/HaLogo';
import { OnboardingTopBar } from '../../shared/components/OnboardingTopBar';
import { PrimaryButton } from '../../shared/components/PrimaryButton';
import { HaColors } from '../../shared/constants/HaStyle';
import { AppIconView } from '../../shared/icons/AppIconView';
import { systemIcon } from '../../shared/icons/AppIconModels';
import { OnboardingUiConfig } from '../../shared/constants/OnboardingUiConfig';
import { Localization } from '../../shared/i18n/Localization';

@Component
export struct DiscoveryPage {
  @Prop
  contentMaxWidth: number = OnboardingUiConfig.contentMaxWidth;
  @Prop
  discoveredServers: HaServerItem[] = [];
  @Prop
  showDiscoveredSheet: boolean = false;
  @Prop
  discoverySpinAngle: number = 0;
  @Prop
  discoveryPulseScale: number = 1;
  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onManualInput: () => void = () => {};
  onSelectServer: (url: string) => void = () => {};
  onCloseSheet: () => void = () => {};
  onStartAnimation: () => void = () => {};
  onStopAnimation: () => void = () => {};
  onSwipeBack: () => void = () => {};

  @Builder
  private renderDiscoveryItem(item: HaServerItem): void {
    Row() {
      Stack() {
        HaLogo({ logoSize: 32 })
      }
      .width(OnboardingUiConfig.discoveryItemIconSlotSize)
      .height(OnboardingUiConfig.discoveryItemIconSlotSize)

      Column({ space: OnboardingUiConfig.discoveryItemTextSpace }) {
        Text(item.name)
          .fontSize(OnboardingUiConfig.discoveryItemTitleSize)
          .fontColor(HaColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(item.url)
          .fontSize(OnboardingUiConfig.discoveryItemUrlSize)
          .fontColor(HaColors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .padding({
        top: OnboardingUiConfig.discoveryItemPaddingTop,
        right: OnboardingUiConfig.discoveryItemPaddingRight,
        bottom: OnboardingUiConfig.discoveryItemPaddingBottom
      })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth, minHeight: OnboardingUiConfig.discoveryItemMinHeight })
    .backgroundColor(HaColors.SURFACE)
    .borderRadius(OnboardingUiConfig.discoveryItemRadius)
    .border({ width: 1, color: HaColors.OUTLINE })
    .onClick(() => {
      this.onSelectServer(item.url);
    })
  }

  @Builder
  private renderDiscoveryAnimation(): void {
    Stack() {
      Image($r('app.media.ha_dots'))
        .width(OnboardingUiConfig.discoveryAnimationSize)
        .height(OnboardingUiConfig.discoveryAnimationSize)
        .objectFit(ImageFit.Contain)
        .rotate({ angle: this.discoverySpinAngle })
        .animation({ duration: 5000, curve: Curve.Linear, iterations: -1 })

      Stack() {
        Image($r('app.media.ha_notification'))
          .width(OnboardingUiConfig.discoveryNotificationIconSize)
          .height(OnboardingUiConfig.discoveryNotificationIconSize)
          .objectFit(ImageFit.Contain)
          .scale({ x: this.discoveryPulseScale, y: this.discoveryPulseScale })
          .animation({ duration: 800, curve: Curve.Linear, iterations: -1, playMode: PlayMode.Alternate })
      }
      .width(OnboardingUiConfig.discoveryPulseSize)
      .height(OnboardingUiConfig.discoveryPulseSize)
      .scale({ x: this.discoveryPulseScale, y: this.discoveryPulseScale })
      .animation({ duration: 800, curve: Curve.Linear, iterations: -1, playMode: PlayMode.Alternate })
      .backgroundColor(HaColors.BRAND)
      .borderRadius(OnboardingUiConfig.discoveryPulseSize / 2)
    }
    .width(OnboardingUiConfig.discoveryAnimationSize)
    .height(OnboardingUiConfig.discoveryAnimationSize)
    .onAppear(() => {
      this.onStartAnimation();
    })
  }

  @Builder
  private renderContinueSearching(): void {
    LoadingProgress()
      .width(OnboardingUiConfig.discoveryLoadingSize)
      .height(OnboardingUiConfig.discoveryLoadingSize)
      .color(HaColors.PRIMARY)
  }

  @Builder
  private renderDiscoveredBottomSheet(item: HaServerItem): void {
    Column({ space: OnboardingUiConfig.discoveredSheetSpace }) {
      Blank()
        .width(OnboardingUiConfig.discoveredSheetHandleWidth)
        .height(OnboardingUiConfig.discoveredSheetHandleHeight)
        .backgroundColor(HaColors.TEXT_SECONDARY)
        .borderRadius(OnboardingUiConfig.discoveredSheetHandleRadius)

      Text(item.name)
        .fontSize(OnboardingUiConfig.discoveredSheetTitleSize)
        .fontWeight(FontWeight.Medium)
        .fontColor(HaColors.TEXT_PRIMARY)
        .lineHeight(OnboardingUiConfig.discoveredSheetTitleLineHeight)
        .textAlign(TextAlign.Center)
        .width('100%')

      AppIconView({
        icon: systemIcon('drive'),
        iconSize: OnboardingUiConfig.discoveredSheetIconSize,
        slotSize: OnboardingUiConfig.discoveredSheetIconSize,
        color: HaColors.BRAND
      })

      Text(item.url)
        .fontSize(OnboardingUiConfig.discoveredSheetUrlSize)
        .fontColor(HaColors.TEXT_SECONDARY)
        .lineHeight(OnboardingUiConfig.discoveredSheetUrlLineHeight)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      PrimaryButton({
        text: Localization.t('discovery_connect'),
        maxWidth: this.contentMaxWidth,
        action: (): void => {
          this.onSelectServer(item.url);
        }
      })
    }
    .width('100%')
    .padding({
      left: OnboardingUiConfig.discoveredSheetPaddingHorizontal,
      right: OnboardingUiConfig.discoveredSheetPaddingHorizontal,
      top: OnboardingUiConfig.discoveredSheetPaddingTop,
      bottom: OnboardingUiConfig.discoveredSheetPaddingBottom
    })
    .backgroundColor(HaColors.SURFACE)
    .borderRadius({ topLeft: OnboardingUiConfig.sheetRadius, topRight: OnboardingUiConfig.sheetRadius, bottomLeft: 0, bottomRight: 0 })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      Column() {
        OnboardingTopBar({ showBack: true, onBack: this.onBack, onHelp: this.onHelp })

        Text(Localization.t('discovery_title'))
          .fontSize(OnboardingUiConfig.discoveryTitleSize)
          .fontWeight(FontWeight.Bold)
          .fontColor(HaColors.TEXT_PRIMARY)
          .lineHeight(OnboardingUiConfig.discoveryTitleLineHeight)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: OnboardingUiConfig.discoveryTitleTopMargin })

        if (this.showDiscoveredSheet || this.discoveredServers.length === 0) {
          Row() {
            this.renderDiscoveryAnimation()
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: OnboardingUiConfig.discoveryAnimationTopMargin })
        } else {
          Column({ space: OnboardingUiConfig.discoveryListSpace }) {
            ForEach(this.discoveredServers, (item: HaServerItem) => {
              this.renderDiscoveryItem(item);
            }, (item: HaServerItem) => item.key)
          }
          .width('100%')
          .margin({ top: OnboardingUiConfig.discoveryListTopMargin })

          Row() {
            this.renderContinueSearching()
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: OnboardingUiConfig.discoveryAnimationTopMargin })
        }

        Blank()
          .layoutWeight(1)

        PrimaryButton({
          text: Localization.t('discovery_manual_input'),
          filled: false,
          maxWidth: this.contentMaxWidth,
          action: this.onManualInput
        })
      }
      .width('100%')
      .height('100%')
      .padding({
        left: OnboardingUiConfig.pagePadding,
        right: OnboardingUiConfig.pagePadding,
        top: OnboardingUiConfig.pageTopPadding,
        bottom: OnboardingUiConfig.pageBottomPadding
      })
      .alignItems(HorizontalAlign.Center)

      if (this.showDiscoveredSheet && this.discoveredServers.length > 0) {
        Blank()
          .width('100%')
          .height('100%')
          .backgroundColor(HaColors.SCRIM)
          .onClick(() => {
            this.onCloseSheet();
          })

        Column() {
          Blank()
            .layoutWeight(1)
            .width('100%')
            .backgroundColor('#00000000')
            .onClick(() => {
              this.onCloseSheet();
            })
          this.renderDiscoveredBottomSheet(this.discoveredServers[0])
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaColors.SURFACE)
    .onAppear(() => {
      this.onStartAnimation();
    })
    .onDisAppear(() => {
      this.onStopAnimation();
    })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetX > 60 || event.offsetX < -60) {
            this.onSwipeBack();
          }
        })
    )
  }
}
