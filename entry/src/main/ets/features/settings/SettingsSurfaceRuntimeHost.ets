import { SettingsItem, SettingsSection } from '../../models/SettingsItem';
import { CompanionSettingsHost } from './CompanionSettingsHost';
import { ServerSettingsPage } from './ServerSettingsPage';
import { SettingsDetailHost } from './SettingsDetailHost';
import { AppRoute } from '../../app/AppRoute';
import { CompanionSettingsData, GestureSettingGroup, SettingChoiceGroup } from './CompanionSettingsData';
import { SettingsChoiceRuntimeService, SettingsChoiceRuntimeState } from './SettingsChoiceRuntimeService';
import { Localization } from '../../shared/i18n/Localization';
import { CompanionChoiceDialog } from './CompanionChoiceDialog';
import { SettingsDialogUiConfig } from './components/SettingsDialogUiConfig';

@Component
export struct CompanionSettingsSurfaceHost {
  @Prop sections: SettingsSection[] = [];
  @Prop contentMaxWidth: number = 0;
  @Prop selectedKey: string = '';
  @Prop scrollOffset: number = 0;
  @Prop switchRevision: number = 0;
  @Prop showChoiceDialog: boolean = false;
  @Prop choiceDialogKey: string = '';
  @Prop screenOrientation: string = 'system';
  @Prop pageZoomLevel: string = '100';
  @Prop appLanguage: string = 'default';
  @Prop appTheme: string = 'light';
  @Prop secureConnectionChoice: string = '';
  @Prop websocketMode: string = 'system';
  @Prop serviceCardUpdateFrequency: string = 'default';
  @Prop dark: boolean = false;

  onBack: () => void = () => {};
  onOpen: (item: SettingsItem) => void = () => {};
  onAction: (actionId: string) => void = () => {};
  onScrollOffsetChange: (offset: number) => void = () => {};
  onSwipeBack: () => void = () => {};
  onSelectChoice: (value: string) => void = () => {};
  onCloseChoice: () => void = () => {};

  build() {
    CompanionSettingsHost({
      sections: this.sections,
      contentMaxWidth: this.contentMaxWidth,
      selectedKey: this.selectedKey,
      scrollOffset: this.scrollOffset,
      switchRevision: this.switchRevision,
      showChoiceDialog: this.showChoiceDialog,
      choiceTitle: SettingsChoiceRuntimeService.dialogTitle(this.choiceState()),
      choiceSelectedValue: SettingsChoiceRuntimeService.selectedValue(this.choiceState()),
      choiceGroups: SettingsChoiceRuntimeService.groups(this.choiceState()),
      dark: this.dark,
      onBack: this.onBack,
      onOpen: this.onOpen,
      onAction: this.onAction,
      onScrollOffsetChange: this.onScrollOffsetChange,
      onSwipeBack: this.onSwipeBack,
      onSelectChoice: this.onSelectChoice,
      onCloseChoice: this.onCloseChoice
    })
  }

  private choiceState(): SettingsChoiceRuntimeState {
    return {
      companionChoiceDialogKey: this.choiceDialogKey,
      showCompanionChoiceDialog: this.showChoiceDialog,
      screenOrientation: this.screenOrientation,
      pageZoomLevel: this.pageZoomLevel,
      appLanguage: this.appLanguage,
      appTheme: this.appTheme,
      secureConnectionChoice: this.secureConnectionChoice,
      websocketMode: this.websocketMode,
      serviceCardUpdateFrequency: this.serviceCardUpdateFrequency,
      appConfigTick: 0,
      step: 0
    };
  }
}

@Component
export struct ServerSettingsSurfaceHost {
  @Prop title: string = '';
  @Prop sections: SettingsSection[] = [];
  @Prop contentMaxWidth: number = 0;
  @Prop selectedKey: string = '';
  @Prop scrollOffset: number = 0;
  @Prop switchRevision: number = 0;
  @Prop @Watch('syncChoiceDialog') showChoiceDialog: boolean = false;
  @Prop choiceDialogKey: string = '';
  @Prop secureConnectionChoice: string = '';
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
      title: SettingsChoiceRuntimeService.dialogTitle(this.choiceState()),
      selectedValue: SettingsChoiceRuntimeService.selectedValue(this.choiceState()),
      groups: SettingsChoiceRuntimeService.groups(this.choiceState()),
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

  private choiceState(): SettingsChoiceRuntimeState {
    return {
      companionChoiceDialogKey: this.choiceDialogKey,
      showCompanionChoiceDialog: this.showChoiceDialog,
      screenOrientation: 'system',
      pageZoomLevel: '100',
      appLanguage: 'default',
      appTheme: 'light',
      secureConnectionChoice: this.secureConnectionChoice,
      websocketMode: 'system',
      serviceCardUpdateFrequency: 'default',
      appConfigTick: 0,
      step: 0
    };
  }

  build() {
    ServerSettingsPage({
      title: this.title,
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

@Component
export struct SettingsDetailSurfaceHost {
  @Prop detailKey: string = '';
  @Prop title: string = '';
  @Prop summary: string = '';
  @Prop body: string = '';
  @Prop status: string = '';
  @Prop action: string = '';
  @Prop textValue: string = '';
  @Prop optionValue: string = '';
  @Prop contentMaxWidth: number = 720;
  @Prop wifiSsids: string[] = [];
  @Prop ssidInput: string = '';
  @Prop prioritizeInternal: boolean = false;
  @Prop gestureGroups: GestureSettingGroup[] = [];
  @Prop screenOrientation: string = 'system';
  @Prop pageZoomLevel: string = '100';
  @Prop appLanguage: string = 'default';
  @Prop appTheme: string = 'light';
  @Prop serviceCardUpdateFrequency: string = 'default';

  gestureActionValue: (key: string) => string = () => '';
  onRoute: (route: number) => void = () => {};
  onSetDetailHeader: (key: string, title: string) => void = () => {};
  onOpenDashboard: () => void = () => {};
  onSsidInputChange: (value: string) => void = () => {};
  onAddSsid: () => void = () => {};
  onRemoveSsid: (value: string) => void = () => {};
  onPrioritizeChange: (value: boolean) => void = () => {};
  onSelectGestureAction: (key: string, value: string) => void = () => {};
  onSelectChoice: (key: string, value: string) => void = () => {};
  onTextChange: (value: string) => void = () => {};
  onOptionChange: (value: string) => void = () => {};
  onSaveServerDetail: () => void = () => {};
  onHelp: () => void = () => {};
  onSwipeBack: () => void = () => {};

  build() {
    SettingsDetailHost({
      detailKey: this.detailKey,
      title: this.title,
      summary: this.summary,
      body: this.body,
      status: this.status,
      action: this.action,
      textValue: this.textValue,
      optionValue: this.optionValue,
      contentMaxWidth: this.contentMaxWidth,
      wifiSsids: this.wifiSsids,
      ssidInput: this.ssidInput,
      prioritizeInternal: this.prioritizeInternal,
      gestureGroups: this.gestureGroups,
      screenOrientation: this.screenOrientation,
      pageZoomLevel: this.pageZoomLevel,
      appLanguage: this.appLanguage,
      appTheme: this.appTheme,
      serviceCardUpdateFrequency: this.serviceCardUpdateFrequency,
      gestureActionValue: this.gestureActionValue,
      onBackToServer: (): void => {
        this.onRoute(AppRoute.SERVER_SETTINGS);
      },
      onBackToCompanion: (): void => {
        this.onRoute(AppRoute.COMPANION_SETTINGS);
      },
      onBackToGestures: (): void => {
        this.onSetDetailHeader('display_gestures', Localization.t('settings_gestures'));
      },
      onOpenDashboard: this.onOpenDashboard,
      onSsidInputChange: this.onSsidInputChange,
      onAddSsid: this.onAddSsid,
      onRemoveSsid: this.onRemoveSsid,
      onPrioritizeChange: this.onPrioritizeChange,
      onOpenGesture: (key: string): void => {
        this.onSetDetailHeader(`gesture_action_${key}`, CompanionSettingsData.gestureTitle(key));
      },
      onSelectGestureAction: (key: string, value: string): void => {
        this.onSelectGestureAction(key, value);
        this.onSetDetailHeader('display_gestures', Localization.t('settings_gestures'));
      },
      onSelectChoice: this.onSelectChoice,
      onTextChange: this.onTextChange,
      onOptionChange: this.onOptionChange,
      onSaveServerDetail: this.onSaveServerDetail,
      onHelp: this.onHelp,
      onSwipeBack: this.onSwipeBack
    })
  }
}
