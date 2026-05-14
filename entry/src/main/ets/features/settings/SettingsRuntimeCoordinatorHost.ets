import { AppRoute } from '../../app/AppRoute';
import { AppRuntimeOverlayActions, AppRuntimeOverlaySnapshot } from '../../app/AppRuntimeOverlayModels';
import { SettingsItem } from '../../models/SettingsItem';
import { DeviceFormFactor, DeviceProfileInfo, DisplaySizeClass } from '../../shared/device/DeviceProfile';
import {
  CompanionSettingsSurfaceHost
} from './SettingsSurfaceRuntimeHost';
import { SettingsRuntimeActions, SettingsRuntimeSnapshot } from './SettingsRuntimeCoordinatorModels';
import {
  CompanionNotificationHistoryBuilder,
  CompanionNotificationSettingsBuilder,
  CompanionSensorFrequencyBuilder,
  CompanionSensorSettingsBuilder,
  CompanionServerSettingsBuilder,
  CompanionSettingsDetailBuilder,
  SETTINGS_NAV_DETAIL,
  SETTINGS_NAV_NOTIFICATION,
  SETTINGS_NAV_NOTIFICATION_HISTORY,
  SETTINGS_NAV_SENSOR,
  SETTINGS_NAV_SENSOR_FREQUENCY,
  SETTINGS_NAV_SERVER,
  SettingsNavDestinationParam,
  openSettingsNavigationAction,
  openSettingsNavigationItem
} from './SettingsNavigationRoutes';
import { SettingsServerSystemDialogHost } from './SettingsSystemDialogs';

const DEFAULT_SETTINGS_RUNTIME_SNAPSHOT: SettingsRuntimeSnapshot = {
  route: AppRoute.COMPANION_SETTINGS,
  companionSections: [],
  serverSections: [],
  serverTitle: '',
  contentMaxWidth: 720,
  selectedKey: '',
  companionScrollOffset: 0,
  serverScrollOffset: 0,
  switchRevision: 0,
  showChoiceDialog: false,
  choiceDialogKey: '',
  screenOrientation: 'system',
  pageZoomLevel: '100',
  appLanguage: 'default',
  appTheme: 'light',
  secureConnectionChoice: '',
  websocketMode: 'system',
  serviceCardUpdateFrequency: 'default',
  dark: false,
  showDeleteServerDialog: false,
  deletingServer: false,
  showEditDialog: false,
  editTitle: '',
  editValue: '',
  editUnit: '',
  detailKey: '',
  detailTitle: '',
  detailSummary: '',
  detailBody: '',
  detailStatus: '',
  detailAction: '',
  detailTextValue: '',
  detailOptionValue: '',
  wifiSsids: [],
  ssidInput: '',
  prioritizeInternal: false,
  gestureGroups: []
};

const DEFAULT_SETTINGS_RUNTIME_ACTIONS: SettingsRuntimeActions = {
  gestureActionValue: () => '',
  onBackToHaSettings: () => {},
  onRoute: () => {},
  onOpen: () => {},
  onAction: () => {},
  onCompanionScrollOffsetChange: () => {},
  onServerScrollOffsetChange: () => {},
  onSwipeBack: () => {},
  onSelectCompanionChoice: () => {},
  onCloseCompanionChoice: () => {},
  onCancelDelete: () => {},
  onDeleteServer: () => {},
  onEditValueChange: () => {},
  onCancelEdit: () => {},
  onSaveEdit: () => {},
  onSetDetailHeader: () => {},
  onOpenDashboard: () => {},
  onSsidInputChange: () => {},
  onAddSsid: () => {},
  onRemoveSsid: () => {},
  onPrioritizeChange: () => {},
  onSelectGestureAction: () => {},
  onSelectDetailChoice: () => {},
  onDetailTextChange: () => {},
  onDetailOptionChange: () => {},
  onSaveServerDetail: () => {},
  onHelp: () => {}
};

class DefaultDeviceProfileInfo implements DeviceProfileInfo {
  widthVp: number = 0;
  heightVp: number = 0;
  formFactor: DeviceFormFactor = DeviceFormFactor.PHONE;
  sizeClass: DisplaySizeClass = DisplaySizeClass.COMPACT;
  contentMaxWidth: number = 0;
  settingsMaxWidth: number = 0;
}

const DEFAULT_OVERLAY_SNAPSHOT: AppRuntimeOverlaySnapshot = {
  route: AppRoute.COMPANION_SETTINGS,
  baseUrl: '',
  accessToken: '',
  refreshToken: '',
  assistStartListeningSignal: 0,
  assistStartListeningRequested: false,
  profile: new DefaultDeviceProfileInfo(),
  sensorGroups: [],
  sensorUpdateFrequency: 'normal',
  contentMaxWidth: 720,
  switchRevision: 0
};

const DEFAULT_OVERLAY_ACTIONS: AppRuntimeOverlayActions = {
  onRoute: () => {},
  onBackToNativeTarget: () => {},
  onSwipeBack: () => {},
  onCloseAssist: () => {},
  onSensorHelp: () => {},
  onSensorSearch: () => {},
  onSensorFilter: () => {},
  onToggleSensor: () => {},
  onSelectSensorFrequency: () => {}
};

const PATH_STACK_RESTORE_DELAY_MS: number = 50;
@Component
export struct SettingsRuntimeCoordinatorHost {
  @Prop snapshot: SettingsRuntimeSnapshot = DEFAULT_SETTINGS_RUNTIME_SNAPSHOT;
  @Prop overlaySnapshot: AppRuntimeOverlaySnapshot = DEFAULT_OVERLAY_SNAPSHOT;
  @Prop @Watch('onRuntimeChanged') route: number = AppRoute.COMPANION_SETTINGS;
  @Prop @Watch('onRuntimeChanged') detailKey: string = '';
  @Prop @Watch('onRuntimeChanged') switchRevision: number = 0;
  actions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  overlayActions: AppRuntimeOverlayActions = DEFAULT_OVERLAY_ACTIONS;
  @Provide('settingsRuntimeSnapshot') providedSnapshot: SettingsRuntimeSnapshot = DEFAULT_SETTINGS_RUNTIME_SNAPSHOT;
  @Provide('settingsRuntimeActions') providedActions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  @Provide('settingsOverlaySnapshot') providedOverlaySnapshot: AppRuntimeOverlaySnapshot = DEFAULT_OVERLAY_SNAPSHOT;
  @Provide('settingsOverlayActions') providedOverlayActions: AppRuntimeOverlayActions = DEFAULT_OVERLAY_ACTIONS;
  @Provide('settingsPathStack') pathStack: NavPathStack = new NavPathStack();
  private syncedRoute: number = AppRoute.COMPANION_SETTINGS;
  private syncedDetailKey: string = '';

  aboutToAppear(): void {
    this.refreshProvidedRuntime();
    this.schedulePathStackRestore(false);
  }

  aboutToRender(): void {
    this.refreshProvidedRuntime();
  }

  private onRuntimeChanged(): void {
    this.refreshProvidedRuntime();
    this.schedulePathStackRestore(true);
  }

  private refreshProvidedRuntime(): void {
    this.providedSnapshot = this.snapshot;
    this.providedActions = this.actions;
    this.providedOverlaySnapshot = this.overlaySnapshot;
    this.providedOverlayActions = this.overlayActions;
  }

  private popToRoot(animated: boolean): void {
    while (this.pathStack.size() > 0) {
      this.pathStack.pop(animated);
    }
  }

  private isRestorableSettingsRoute(): boolean {
    return this.snapshot.route === AppRoute.COMPANION_SETTINGS ||
      this.snapshot.route === AppRoute.SERVER_SETTINGS ||
      this.snapshot.route === AppRoute.SETTINGS_DETAIL;
  }

  private restorePathStackForSnapshot(animated: boolean): void {
    if (!this.isRestorableSettingsRoute()) {
      this.syncedRoute = this.snapshot.route;
      this.syncedDetailKey = this.snapshot.detailKey;
      return;
    }
    this.popToRoot(false);
    if (this.snapshot.route === AppRoute.SERVER_SETTINGS) {
      const serverParam: SettingsNavDestinationParam = { key: SETTINGS_NAV_SERVER };
      this.pathStack.pushPath({ name: SETTINGS_NAV_SERVER, param: serverParam }, animated);
    } else if (this.snapshot.route === AppRoute.SETTINGS_DETAIL && this.snapshot.detailKey.length > 0) {
      if (this.isServerDetail()) {
        const serverParam: SettingsNavDestinationParam = { key: SETTINGS_NAV_SERVER };
        this.pathStack.pushPath({ name: SETTINGS_NAV_SERVER, param: serverParam }, false);
      }
      const param: SettingsNavDestinationParam = { key: this.snapshot.detailKey };
      this.pathStack.pushPath({ name: SETTINGS_NAV_DETAIL, param: param }, animated);
    }
    this.syncedRoute = this.snapshot.route;
    this.syncedDetailKey = this.snapshot.detailKey;
  }

  private schedulePathStackRestore(animated: boolean): void {
    setTimeout((): void => {
      if (!this.isRestorableSettingsRoute()) {
        this.syncedRoute = this.snapshot.route;
        this.syncedDetailKey = this.snapshot.detailKey;
        return;
      }
      if (this.snapshot.route === this.syncedRoute && this.snapshot.detailKey === this.syncedDetailKey) {
        return;
      }
      this.restorePathStackForSnapshot(animated);
    }, PATH_STACK_RESTORE_DELAY_MS);
  }

  private openSettingsItem(item: SettingsItem): void {
    openSettingsNavigationItem(item, this.pathStack, this.actions);
  }

  private openSettingsAction(actionId: string): void {
    openSettingsNavigationAction(actionId, this.pathStack, this.actions);
  }

  private routeTo(route: number): void {
    this.actions.onRoute(route);
    if (route === AppRoute.COMPANION_SETTINGS) {
      this.popToRoot(true);
    } else if (route === AppRoute.SERVER_SETTINGS) {
      this.popToRoot(false);
      const param: SettingsNavDestinationParam = { key: SETTINGS_NAV_SERVER };
      this.pathStack.pushPath({ name: SETTINGS_NAV_SERVER, param: param }, true);
    }
  }

  private setDetailHeader(key: string, title: string): void {
    this.actions.onSetDetailHeader(key, title);
    const param: SettingsNavDestinationParam = { key: key };
    this.pathStack.pushPath({ name: SETTINGS_NAV_DETAIL, param: param }, true);
  }

  private isServerDetail(): boolean {
    return this.snapshot.detailKey.startsWith('server_');
  }

  @Builder
  private renderCompanionRoot(): void {
    CompanionSettingsSurfaceHost({
      sections: this.snapshot.companionSections,
      contentMaxWidth: this.snapshot.contentMaxWidth,
      selectedKey: this.snapshot.selectedKey,
      scrollOffset: this.snapshot.companionScrollOffset,
      switchRevision: this.snapshot.switchRevision,
      showChoiceDialog: this.snapshot.showChoiceDialog && this.snapshot.choiceDialogKey !== 'server_connection_security',
      choiceDialogKey: this.snapshot.choiceDialogKey,
      screenOrientation: this.snapshot.screenOrientation,
      pageZoomLevel: this.snapshot.pageZoomLevel,
      appLanguage: this.snapshot.appLanguage,
      appTheme: this.snapshot.appTheme,
      secureConnectionChoice: this.snapshot.secureConnectionChoice,
      websocketMode: this.snapshot.websocketMode,
      serviceCardUpdateFrequency: this.snapshot.serviceCardUpdateFrequency,
      dark: this.snapshot.dark,
      onBack: this.actions.onBackToHaSettings,
      onOpen: (item: SettingsItem): void => this.openSettingsItem(item),
      onAction: (actionId: string): void => this.openSettingsAction(actionId),
      onScrollOffsetChange: this.actions.onCompanionScrollOffsetChange,
      onSwipeBack: this.actions.onSwipeBack,
      onSelectChoice: this.actions.onSelectCompanionChoice,
      onCloseChoice: this.actions.onCloseCompanionChoice
    })
  }

  @Builder
  private renderSettingsDestination(name: string): void {
    if (name === SETTINGS_NAV_SERVER) {
      CompanionServerSettingsBuilder()
    } else if (name === SETTINGS_NAV_DETAIL) {
      CompanionSettingsDetailBuilder()
    } else if (name === SETTINGS_NAV_SENSOR) {
      CompanionSensorSettingsBuilder()
    } else if (name === SETTINGS_NAV_SENSOR_FREQUENCY) {
      CompanionSensorFrequencyBuilder()
    } else if (name === SETTINGS_NAV_NOTIFICATION) {
      CompanionNotificationSettingsBuilder()
    } else if (name === SETTINGS_NAV_NOTIFICATION_HISTORY) {
      CompanionNotificationHistoryBuilder()
    }
  }

  @Builder
  private renderStackRuntime(): void {
    Stack() {
      Navigation(this.pathStack) {
        this.renderCompanionRoot()
      }
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .hideToolBar(true)
      .navDestination(this.renderSettingsDestination)

      this.renderSettingsDialogs()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private renderSettingsDialogs(): void {
    SettingsServerSystemDialogHost({
      showDeleteDialog: this.snapshot.showDeleteServerDialog,
      deletingServer: this.snapshot.deletingServer,
      showEditDialog: this.snapshot.showEditDialog,
      editTitle: this.snapshot.editTitle,
      editValue: this.snapshot.editValue,
      editUnit: this.snapshot.editUnit,
      onCancelDelete: this.actions.onCancelDelete,
      onDeleteServer: this.actions.onDeleteServer,
      onEditValueChange: this.actions.onEditValueChange,
      onCancelEdit: this.actions.onCancelEdit,
      onSaveEdit: this.actions.onSaveEdit
    })
  }

  build() {
    this.renderStackRuntime()
  }
}
