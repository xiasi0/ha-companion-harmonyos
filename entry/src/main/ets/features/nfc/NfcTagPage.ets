import { tag } from '@kit.ConnectivityKit';
import { bundleManager } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HaColors } from '../../shared/constants/HaStyle';
import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import { actionSettingsItem } from '../../models/SettingsItem';
import { SettingsBoundary } from '../settings/components/SettingsBoundary';
import { SettingsDialogUiConfig } from '../settings/components/SettingsDialogUiConfig';
import { SettingsRow } from '../settings/components/SettingsRow';
import { SettingsUiConfig } from '../settings/components/SettingsUiConfig';
import { NfcTagMode } from './NfcTagModels';
import { NfcTagService } from './NfcTagService';

@CustomDialog
@Component
struct NfcTagOperationDialog {
  controller: CustomDialogController;
  @Prop mode: NfcTagMode = NfcTagMode.READ;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @StorageLink('appForegroundTick') @Watch('onAppForeground') appForegroundTick: number = 0;
  @StorageLink('appBackgroundTick') @Watch('onAppBackground') appBackgroundTick: number = 0;
  @State private tagId: string = '';
  @State private status: string = 'waiting';
  @State private message: string = '';
  @State private readerEnabled: boolean = false;
  private elementName: bundleManager.ElementName | undefined = undefined;
  private readerCallback: ((error: Error, tagInfo: tag.TagInfo) => void) | undefined = undefined;
  private operationInFlight: boolean = false;

  onClose: () => void = () => {};

  aboutToAppear(): void {
    this.operationInFlight = false;
    this.status = 'waiting';
    this.message = '';
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.elementName = {
      bundleName: context.abilityInfo.bundleName,
      abilityName: context.abilityInfo.name,
      moduleName: context.abilityInfo.moduleName
    };
    this.tagId = this.mode === NfcTagMode.WRITE ? NfcTagService.newTagId() : '';
    this.startReader();
  }

  aboutToDisappear(): void {
    this.stopReader();
  }

  private onAppForeground(): void {
    this.startReader();
  }

  private onAppBackground(): void {
    this.stopReader();
  }

  private startReader(): void {
    if (!NfcTagService.isSupported()) {
      this.status = 'error';
      this.message = Localization.t('nfc_not_supported');
      return;
    }
    if (!this.elementName || this.readerEnabled || this.operationInFlight) {
      return;
    }
    this.readerCallback = (error: Error, tagInfo: tag.TagInfo): void => {
      if (error) {
        this.status = 'error';
        this.message = error.message;
        this.stopReader();
        return;
      }
      this.handleTag(tagInfo);
    };
    try {
      tag.registerForegroundDispatch(this.elementName, [tag.NFC_A, tag.NFC_B, tag.NFC_F, tag.NFC_V], this.readerCallback);
      this.readerEnabled = true;
    } catch (error) {
      this.status = 'error';
      this.message = String(error);
    }
  }

  private stopReader(): void {
    if (!this.readerEnabled || !this.elementName) {
      return;
    }
    this.readerEnabled = false;
    try {
      tag.unregisterForegroundDispatch(this.elementName);
    } catch (_) {}
  }

  private handleTag(tagInfo: tag.TagInfo): void {
    if (this.operationInFlight) {
      return;
    }
    this.operationInFlight = true;
    this.stopReader();
    this.status = 'scanning';
    if (this.mode === NfcTagMode.WRITE) {
      NfcTagService.writeTag(tagInfo, this.tagId)
        .then((): void => {
          this.status = 'success';
        })
        .catch((error: Error): void => {
          this.status = 'error';
          this.message = error.message;
        });
      return;
    }
    NfcTagService.readTagId(tagInfo)
      .then((tagId: string): void => {
        this.tagId = tagId;
        this.status = 'success';
      })
      .catch((error: Error): void => {
        this.status = 'error';
        this.message = error.message;
      });
  }

  private title(): string {
    return this.mode === NfcTagMode.WRITE ? Localization.t('nfc_write_title') : Localization.t('nfc_read_title');
  }

  private prompt(): string {
    if (this.status === 'success' && this.mode === NfcTagMode.WRITE) {
      return Localization.t('nfc_write_success');
    }
    if (this.status === 'error') {
      return this.message.length > 0 ? this.message : Localization.t('nfc_event_failed');
    }
    if (this.status === 'scanning') {
      return Localization.t('nfc_processing');
    }
    return this.mode === NfcTagMode.WRITE ? Localization.t('nfc_write_prompt') : Localization.t('nfc_read_prompt');
  }

  private showDoneButton(): boolean {
    return this.status === 'success' || this.status === 'error';
  }

  build() {
    Column({ space: 16 }) {
      Text(this.title())
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(HaTheme.textPrimary(this.appResolvedDark))
        .width('100%')

      Text(this.prompt())
        .fontSize(16)
        .lineHeight(24)
        .fontColor(HaTheme.textSecondary(this.appResolvedDark))
        .width('100%')

      if (this.tagId.length > 0) {
        if (this.mode === NfcTagMode.READ) {
          Text(Localization.t('nfc_tag_identifier'))
            .fontSize(14)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
            .width('100%')
        }
        Text(this.tagId)
          .fontSize(16)
          .fontColor(HaTheme.textPrimary(this.appResolvedDark))
          .width('100%')
      }

      Row() {
        Blank()
          .layoutWeight(1)

        Button(this.showDoneButton() ? Localization.t('common_done') : Localization.t('action_cancel'))
          .height(SettingsDialogUiConfig.dialogButtonHeight)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(HaColors.PRIMARY)
          .backgroundColor(SettingsDialogUiConfig.transparentBackground)
          .borderRadius(SettingsDialogUiConfig.dialogButtonRadius)
          .onClick(this.onClose)
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding(SettingsDialogUiConfig.dialogPadding())
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
  }
}

@Component
export struct NfcTagPage {
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  private readDialogOpen: boolean = false;
  private writeDialogOpen: boolean = false;

  onBack: () => void = () => {};
  onSwipeBack: () => void = () => {};
  private readDialogController: CustomDialogController = new CustomDialogController({
    builder: NfcTagOperationDialog({
      mode: NfcTagMode.READ,
      onClose: (): void => this.closeReadDialog()
    }),
    cancel: (): void => this.closeReadDialog(),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    maskColor: SettingsDialogUiConfig.dialogMaskColor,
    width: SettingsDialogUiConfig.dialogWidth(),
    cornerRadius: SettingsDialogUiConfig.dialogCornerRadius,
    openAnimation: { duration: SettingsDialogUiConfig.dialogOpenDuration, curve: Curve.EaseOut },
    closeAnimation: { duration: SettingsDialogUiConfig.dialogCloseDuration, curve: Curve.EaseIn }
  });
  private writeDialogController: CustomDialogController = new CustomDialogController({
    builder: NfcTagOperationDialog({
      mode: NfcTagMode.WRITE,
      onClose: (): void => this.closeWriteDialog()
    }),
    cancel: (): void => this.closeWriteDialog(),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    maskColor: SettingsDialogUiConfig.dialogMaskColor,
    width: SettingsDialogUiConfig.dialogWidth(),
    cornerRadius: SettingsDialogUiConfig.dialogCornerRadius,
    openAnimation: { duration: SettingsDialogUiConfig.dialogOpenDuration, curve: Curve.EaseOut },
    closeAnimation: { duration: SettingsDialogUiConfig.dialogCloseDuration, curve: Curve.EaseIn }
  });

  private openReadDialog(): void {
    if (this.readDialogOpen) {
      return;
    }
    this.readDialogController.open();
    this.readDialogOpen = true;
  }

  private closeReadDialog(): void {
    if (!this.readDialogOpen) {
      return;
    }
    this.readDialogOpen = false;
    this.readDialogController.close();
  }

  private openWriteDialog(): void {
    if (this.writeDialogOpen) {
      return;
    }
    this.writeDialogController.open();
    this.writeDialogOpen = true;
  }

  private closeWriteDialog(): void {
    if (!this.writeDialogOpen) {
      return;
    }
    this.writeDialogOpen = false;
    this.writeDialogController.close();
  }

  @Builder
  private operationGroup(): void {
    Column() {
      SettingsRow({
        item: actionSettingsItem('nfc', Localization.t('nfc_read_title'), '', '', 'read_nfc_tag'),
        onAction: (): void => this.openReadDialog()
      })
      SettingsBoundary()
      SettingsRow({
        item: actionSettingsItem('nfc', Localization.t('nfc_write_title'), '', '', 'write_nfc_tag'),
        onAction: (): void => this.openWriteDialog()
      })
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  private isSupported(): boolean {
    return NfcTagService.isSupported();
  }

  @Builder
  private pageContent(): void {
    List({ scroller: this.scroller }) {
      ListItem() {
        Column({ space: 16 }) {
          if (this.isSupported()) {
            this.operationGroup()
          }
        }
        .width('100%')
      }
      .width('100%')
    }
    .padding(SettingsUiConfig.listPadding())
    .layoutWeight(1)
    .width('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth })
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(SettingsUiConfig.listContentEndOffset)
    .clip(false)
    .scrollBar(SettingsUiConfig.scrollBarState())
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .alignListItem(ListItemAlign.Center)
  }

  build() {
    HdsNavigation() {
      this.pageContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .titleBar(SettingsUiConfig.titleBar(Localization.t('nfc_title'), this.onBack, this.appResolvedDark))
    .bindToScrollable([this.scroller])
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 24 }).onActionEnd((event: GestureEvent) => {
      if (event.offsetX > 60 || event.offsetX < -60) {
        this.onSwipeBack();
      }
    }))
  }
}
