import { HaColors } from '../../shared/constants/HaStyle';
import { Localization } from '../../shared/i18n/Localization';
import { HaTheme } from '../../shared/theme/HaTheme';
import { SettingsDialogUiConfig } from './components/SettingsDialogUiConfig';

@CustomDialog
@Component
export struct SettingsTextEditSystemDialog {
  controller: CustomDialogController;
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop unit: string = '';
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  onChange: (value: string) => void = () => {};
  onCancel: () => void = () => {};
  onSave: () => void = () => {};

  build() {
    Column({ space: 18 }) {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(HaTheme.textPrimary(this.appResolvedDark))
        .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.value })
          .onChange((value: string) => {
            this.onChange(value);
          })
          .type(this.unit === Localization.t('unit_seconds') ? InputType.Number : InputType.Normal)
          .height(SettingsDialogUiConfig.dialogInputHeight)
          .fontSize(16)
          .fontColor(HaTheme.textPrimary(this.appResolvedDark))
          .backgroundColor(HaTheme.surface(this.appResolvedDark))
          .border({ width: SettingsDialogUiConfig.dialogInputBorderWidth, color: HaTheme.outline(this.appResolvedDark) })
          .borderRadius(SettingsDialogUiConfig.dialogInputRadius)
          .cancelButton({ style: CancelButtonStyle.CONSTANT })
          .layoutWeight(1)

        if (this.unit.length > 0) {
          Text(this.unit)
            .fontSize(16)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Blank()
          .layoutWeight(1)

        Button(Localization.t('action_cancel'))
          .height(SettingsDialogUiConfig.dialogButtonHeight)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(HaColors.PRIMARY)
          .backgroundColor(SettingsDialogUiConfig.transparentBackground)
          .borderRadius(SettingsDialogUiConfig.dialogButtonRadius)
          .onClick(() => {
            this.onCancel();
          })

        Button(Localization.t('action_confirm'))
          .height(SettingsDialogUiConfig.dialogButtonHeight)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(HaColors.PRIMARY)
          .backgroundColor(SettingsDialogUiConfig.transparentBackground)
          .borderRadius(SettingsDialogUiConfig.dialogButtonRadius)
          .onClick(() => {
            this.onSave();
          })
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
export struct SettingsServerSystemDialogHost {
  @Prop @Watch('syncDeleteDialog') showDeleteDialog: boolean = false;
  @Prop deletingServer: boolean = false;
  @Prop @Watch('syncEditDialog') showEditDialog: boolean = false;
  @Prop editTitle: string = '';
  @Prop editValue: string = '';
  @Prop editUnit: string = '';
  onCancelDelete: () => void = () => {};
  onDeleteServer: () => void = () => {};
  onEditValueChange: (value: string) => void = () => {};
  onCancelEdit: () => void = () => {};
  onSaveEdit: () => void = () => {};
  private deleteDialogOpen: boolean = false;
  private editDialogOpen: boolean = false;
  private editDialogController: CustomDialogController = new CustomDialogController({
    builder: SettingsTextEditSystemDialog({
      title: this.editTitle,
      value: this.editValue,
      unit: this.editUnit,
      onChange: this.onEditValueChange,
      onCancel: this.onCancelEdit,
      onSave: this.onSaveEdit
    }),
    cancel: (): void => {
      this.onCancelEdit();
    },
    autoCancel: true,
    alignment: DialogAlignment.Center,
    maskColor: SettingsDialogUiConfig.dialogMaskColor,
    width: SettingsDialogUiConfig.dialogWidth(),
    cornerRadius: SettingsDialogUiConfig.dialogCornerRadius,
    openAnimation: { duration: SettingsDialogUiConfig.dialogOpenDuration, curve: Curve.EaseOut },
    closeAnimation: { duration: SettingsDialogUiConfig.dialogCloseDuration, curve: Curve.EaseIn }
  });

  aboutToAppear(): void {
    this.syncDeleteDialog();
    this.syncEditDialog();
  }

  private syncDeleteDialog(): void {
    if (!this.showDeleteDialog || this.deletingServer) {
      this.deleteDialogOpen = false;
      return;
    }
    if (this.deleteDialogOpen) {
      return;
    }
    this.deleteDialogOpen = true;
    this.getUIContext().showAlertDialog({
      title: Localization.t('action_delete'),
      message: Localization.t('server_delete_confirm'),
      autoCancel: true,
      cancel: (): void => {
        this.deleteDialogOpen = false;
        this.onCancelDelete();
      },
      primaryButton: {
        value: Localization.t('action_cancel'),
        fontColor: HaColors.PRIMARY,
        action: (): void => {
          this.deleteDialogOpen = false;
          this.onCancelDelete();
        }
      },
      secondaryButton: {
        value: Localization.t('action_delete'),
        fontColor: HaColors.ERROR,
        action: (): void => {
          this.deleteDialogOpen = false;
          this.onDeleteServer();
        }
      },
      transition: TransitionEffect.OPACITY
    })
  }

  private syncEditDialog(): void {
    if (this.showEditDialog && !this.editDialogOpen) {
      this.editDialogController.open();
      this.editDialogOpen = true;
      return;
    }
    if (!this.showEditDialog && this.editDialogOpen) {
      this.editDialogController.close();
      this.editDialogOpen = false;
    }
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}
