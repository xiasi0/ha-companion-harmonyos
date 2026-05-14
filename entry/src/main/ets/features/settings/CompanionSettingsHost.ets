import { SettingsItem, SettingsSection } from '../../models/SettingsItem';
import { SettingsHomePage } from './SettingsHomePage';
import { CompanionChoiceDialog } from './CompanionChoiceDialog';
import { SettingChoiceGroup } from './CompanionSettingsData';
import { SettingsDialogUiConfig } from './components/SettingsDialogUiConfig';

@Component
export struct CompanionSettingsHost {
  @Prop sections: SettingsSection[] = [];
  @Prop contentMaxWidth: number = 0;
  @Prop selectedKey: string = '';
  @Prop scrollOffset: number = 0;
  @Prop switchRevision: number = 0;
  @Prop @Watch('syncChoiceDialog') showChoiceDialog: boolean = false;
  @Prop choiceTitle: string = '';
  @Prop choiceSelectedValue: string = '';
  @Prop choiceGroups: SettingChoiceGroup[] = [];
  @Prop dark: boolean = false;
  onBack: () => void = () => {};
  onOpen: (item: SettingsItem) => void = () => {};
  onAction: (actionId: string) => void = () => {};
  onScrollOffsetChange: (offset: number) => void = () => {};
  onSwipeBack: () => void = () => {};
  onSelectChoice: (value: string) => void = () => {};
  onCloseChoice: () => void = () => {};
  private choiceDialogOpen: boolean = false;
  private choiceDialogController: CustomDialogController = new CustomDialogController({
    builder: CompanionChoiceDialog({
      title: this.choiceTitle,
      selectedValue: this.choiceSelectedValue,
      groups: this.choiceGroups,
      dark: this.dark,
      onSelect: this.onSelectChoice,
      onClose: this.onCloseChoice
    }),
    cancel: (): void => {
      this.onCloseChoice();
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
    this.syncChoiceDialog();
  }

  private syncChoiceDialog(): void {
    if (this.showChoiceDialog && !this.choiceDialogOpen) {
      this.choiceDialogController.open();
      this.choiceDialogOpen = true;
      return;
    }
    if (!this.showChoiceDialog && this.choiceDialogOpen) {
      this.choiceDialogController.close();
      this.choiceDialogOpen = false;
    }
  }

  build() {
    SettingsHomePage({
      sections: this.sections,
      contentMaxWidth: this.contentMaxWidth,
      selectedKey: this.selectedKey,
      scrollOffset: this.scrollOffset,
      switchRevision: this.switchRevision,
      onBack: this.onBack,
      onOpen: this.onOpen,
      onAction: this.onAction,
      onScrollOffsetChange: this.onScrollOffsetChange,
      onSwipeBack: this.onSwipeBack
    })
  }
}
