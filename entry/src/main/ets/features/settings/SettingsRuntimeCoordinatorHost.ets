import { AppRoute } from '../../app/AppRoute';
import { AppRuntimeOverlayActions, AppRuntimeOverlaySnapshot } from '../../app/AppRuntimeOverlayModels';
import { SensorGroup } from '../sensors/SensorModels';
import { SettingsItem, SettingsSection } from '../../models/SettingsItem';
import { SettingsLiveStateStore } from '../../services/SettingsLiveStateStore';
import { DeviceFormFactor, DeviceProfileInfo, DisplaySizeClass } from '../../shared/device/DeviceProfile';
import {
  CompanionSettingsSurfaceHost
} from './SettingsSurfaceRuntimeHost';
import { GestureSettingGroup } from './CompanionSettingsData';
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
  SettingsNavSyncActions,
  SettingsNavSyncTarget,
  openSettingsNavigationAction,
  openSettingsNavigationItem
} from './SettingsNavigationRoutes';
import { SettingsServerSystemDialogHost } from './SettingsSystemDialogs';

const DEFAULT_SETTINGS_RUNTIME_SNAPSHOT: SettingsRuntimeSnapshot = {
  route: AppRoute.COMPANION_SETTINGS,
  refreshTick: 0,
  companionSections: [],
  serverSections: [],
  serverTitle: '',
  contentMaxWidth: 720,
  selectedKey: '',
  companionScrollOffset: 0,
  serverScrollOffset: 0,
  showChoiceDialog: false,
  choiceDialogKey: '',
  screenOrientation: 'system',
  pageZoomLevel: '100',
  appLanguage: 'default',
  appTheme: 'system',
  secureConnectionChoice: '',
  websocketMode: 'system',
  serviceCardUpdateFrequency: 'default',
  assistWakeDetectionEnabled: true,
  assistWakeWord: 'wake_word_1',
  assistProbabilityCutoff: '',
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
  onToggleAssistWakeDetection: () => {},
  onOpenAssistProbabilityCutoff: () => {},
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
  contentMaxWidth: 720
};

const DEFAULT_OVERLAY_ACTIONS: AppRuntimeOverlayActions = {
  onRoute: () => {},
  onBackToNativeTarget: () => {},
  onSwipeBack: () => {},
  onCloseAssist: () => {},
  onSensorHelp: () => {},
  onSensorSearch: () => {},
  onSensorFilter: () => {},
  onToggleSensor: (_id: string, _enabled: boolean): void => {},
  onSelectSensorFrequency: () => {}
};

const DEFAULT_SETTINGS_NAV_SYNC_ACTIONS: SettingsNavSyncActions = {
  onSynced: () => {}
};

const PATH_STACK_RESTORE_DELAY_MS: number = 50;
@Component
export struct SettingsRuntimeCoordinatorHost {
  @Prop @Watch('onRuntimeDataChanged') snapshot: SettingsRuntimeSnapshot = DEFAULT_SETTINGS_RUNTIME_SNAPSHOT;
  @Prop @Watch('onRuntimeDataChanged') overlaySnapshot: AppRuntimeOverlaySnapshot = DEFAULT_OVERLAY_SNAPSHOT;
  @Prop @Watch('onRuntimeRouteChanged') route: number = AppRoute.COMPANION_SETTINGS;
  @Prop @Watch('onRuntimeRouteChanged') detailKey: string = '';
  actions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  overlayActions: AppRuntimeOverlayActions = DEFAULT_OVERLAY_ACTIONS;
  @Provide('settingsRuntimeSnapshot') providedSnapshot: SettingsRuntimeSnapshot = DEFAULT_SETTINGS_RUNTIME_SNAPSHOT;
  @Provide('settingsRuntimeActions') providedActions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  @Provide('settingsOverlaySnapshot') providedOverlaySnapshot: AppRuntimeOverlaySnapshot = DEFAULT_OVERLAY_SNAPSHOT;
  @Provide('settingsOverlayActions') providedOverlayActions: AppRuntimeOverlayActions = DEFAULT_OVERLAY_ACTIONS;
  @Provide('settingsOverlaySensorGroups') providedOverlaySensorGroups: SensorGroup[] = [];
  @Provide('settingsNavSyncActions') providedNavSyncActions: SettingsNavSyncActions = DEFAULT_SETTINGS_NAV_SYNC_ACTIONS;
  @Provide('settingsPathStack') pathStack: NavPathStack = new NavPathStack();
  private navSyncActionsCache: SettingsNavSyncActions | undefined = undefined;
  private syncedRoute: number = AppRoute.COMPANION_SETTINGS;
  private syncedDetailKey: string = '';

  aboutToAppear(): void {
    this.refreshProvidedRuntime();
    this.schedulePathStackRestore(false);
  }

  private onRuntimeDataChanged(): void {
    this.refreshProvidedRuntime();
  }

  private onRuntimeRouteChanged(): void {
    this.refreshProvidedRuntime();
    this.schedulePathStackRestore(true);
  }

  private refreshProvidedRuntime(): void {
    SettingsLiveStateStore.applySections(this.snapshot.companionSections);
    SettingsLiveStateStore.applySections(this.snapshot.serverSections);
    if (!this.sameSettingsSnapshot(this.providedSnapshot, this.snapshot)) {
      this.providedSnapshot = this.snapshot;
    }
    if (this.providedActions !== this.actions) {
      this.providedActions = this.actions;
    }
    if (!this.sameOverlaySnapshot(this.providedOverlaySnapshot, this.overlaySnapshot)) {
      this.providedOverlaySnapshot = this.overlaySnapshot;
    }
    if (this.providedOverlayActions !== this.overlayActions) {
      this.providedOverlayActions = this.overlayActions;
    }
    if (this.providedOverlaySensorGroups !== this.overlaySnapshot.sensorGroups) {
      this.providedOverlaySensorGroups = this.overlaySnapshot.sensorGroups;
    }
    const navSyncActions = this.navSyncActions();
    if (this.providedNavSyncActions !== navSyncActions) {
      this.providedNavSyncActions = navSyncActions;
    }
  }

  private navSyncActions(): SettingsNavSyncActions {
    if (!this.navSyncActionsCache) {
      this.navSyncActionsCache = {
        onSynced: (target: SettingsNavSyncTarget): void => {
          this.markPathStackSynced(target);
        }
      };
    }
    return this.navSyncActionsCache;
  }

  private sameSettingsSnapshot(left: SettingsRuntimeSnapshot, right: SettingsRuntimeSnapshot): boolean {
    return left.route === right.route &&
      left.refreshTick === right.refreshTick &&
      left.serverTitle === right.serverTitle &&
      left.contentMaxWidth === right.contentMaxWidth &&
      left.selectedKey === right.selectedKey &&
      left.companionScrollOffset === right.companionScrollOffset &&
      left.serverScrollOffset === right.serverScrollOffset &&
      left.showChoiceDialog === right.showChoiceDialog &&
      left.choiceDialogKey === right.choiceDialogKey &&
      left.screenOrientation === right.screenOrientation &&
      left.pageZoomLevel === right.pageZoomLevel &&
      left.appLanguage === right.appLanguage &&
      left.appTheme === right.appTheme &&
      left.secureConnectionChoice === right.secureConnectionChoice &&
      left.websocketMode === right.websocketMode &&
      left.serviceCardUpdateFrequency === right.serviceCardUpdateFrequency &&
      left.assistWakeDetectionEnabled === right.assistWakeDetectionEnabled &&
      left.assistWakeWord === right.assistWakeWord &&
      left.assistProbabilityCutoff === right.assistProbabilityCutoff &&
      left.dark === right.dark &&
      left.showDeleteServerDialog === right.showDeleteServerDialog &&
      left.deletingServer === right.deletingServer &&
      left.showEditDialog === right.showEditDialog &&
      left.editTitle === right.editTitle &&
      left.editValue === right.editValue &&
      left.editUnit === right.editUnit &&
      left.detailKey === right.detailKey &&
      left.detailTitle === right.detailTitle &&
      left.detailSummary === right.detailSummary &&
      left.detailBody === right.detailBody &&
      left.detailStatus === right.detailStatus &&
      left.detailAction === right.detailAction &&
      left.detailTextValue === right.detailTextValue &&
      left.detailOptionValue === right.detailOptionValue &&
      left.ssidInput === right.ssidInput &&
      left.prioritizeInternal === right.prioritizeInternal &&
      this.sameStringArray(left.wifiSsids, right.wifiSsids) &&
      this.settingsSectionsSignature(left.companionSections) === this.settingsSectionsSignature(right.companionSections) &&
      this.settingsSectionsSignature(left.serverSections) === this.settingsSectionsSignature(right.serverSections) &&
      this.gestureGroupsSignature(left.gestureGroups) === this.gestureGroupsSignature(right.gestureGroups);
  }

  private sameStringArray(left: string[], right: string[]): boolean {
    if (left.length !== right.length) {
      return false;
    }
    for (let i = 0; i < left.length; i++) {
      if (left[i] !== right[i]) {
        return false;
      }
    }
    return true;
  }

  private settingsSectionsSignature(sections: SettingsSection[]): string {
    const parts: string[] = [];
    for (let i = 0; i < sections.length; i++) {
      const section = sections[i];
      parts.push(section.title);
      for (let j = 0; j < section.items.length; j++) {
        parts.push(this.settingsItemSignature(section.items[j]));
      }
    }
    return parts.join('\u001f');
  }

  private settingsItemSignature(item: SettingsItem): string {
    return [
      item.type.toString(),
      item.icon,
      item.title,
      item.summary,
      item.status,
      item.body,
      item.action,
      item.actionId,
      item.badge,
      item.isOn ? '1' : '0',
      item.capability.toString()
    ].join('\u001e');
  }

  private gestureGroupsSignature(groups: GestureSettingGroup[]): string {
    const parts: string[] = [];
    for (let i = 0; i < groups.length; i++) {
      const group = groups[i];
      parts.push(group.title);
      for (let j = 0; j < group.items.length; j++) {
        const item = group.items[j];
        parts.push([item.key, item.title, item.summary].join('\u001e'));
      }
    }
    return parts.join('\u001f');
  }

  private sameOverlaySnapshot(left: AppRuntimeOverlaySnapshot, right: AppRuntimeOverlaySnapshot): boolean {
    return left.route === right.route &&
      left.baseUrl === right.baseUrl &&
      left.accessToken === right.accessToken &&
      left.refreshToken === right.refreshToken &&
      left.assistStartListeningSignal === right.assistStartListeningSignal &&
      left.assistStartListeningRequested === right.assistStartListeningRequested &&
      left.sensorGroups === right.sensorGroups &&
      left.sensorUpdateFrequency === right.sensorUpdateFrequency &&
      left.contentMaxWidth === right.contentMaxWidth &&
      this.sameDeviceProfile(left.profile, right.profile);
  }

  private sameDeviceProfile(left: DeviceProfileInfo, right: DeviceProfileInfo): boolean {
    return left.widthVp === right.widthVp &&
      left.heightVp === right.heightVp &&
      left.formFactor === right.formFactor &&
      left.sizeClass === right.sizeClass &&
      left.contentMaxWidth === right.contentMaxWidth &&
      left.settingsMaxWidth === right.settingsMaxWidth;
  }

  private popToRoot(animated: boolean): void {
    while (this.pathStack.size() > 0) {
      this.pathStack.pop(animated);
    }
  }

  private isRestorableSettingsRoute(): boolean {
    return this.route === AppRoute.COMPANION_SETTINGS ||
      this.route === AppRoute.SERVER_SETTINGS ||
      this.route === AppRoute.SETTINGS_DETAIL ||
      this.route === AppRoute.SENSOR_SETTINGS ||
      this.route === AppRoute.SENSOR_UPDATE_FREQUENCY ||
      this.route === AppRoute.NOTIFICATION_SETTINGS;
  }

  private restorePathStackForSnapshot(animated: boolean): void {
    if (!this.isRestorableSettingsRoute()) {
      this.syncedRoute = this.route;
      this.syncedDetailKey = this.detailKey;
      return;
    }
    this.popToRoot(false);
    if (this.route === AppRoute.SERVER_SETTINGS) {
      const serverParam: SettingsNavDestinationParam = { key: SETTINGS_NAV_SERVER };
      this.pathStack.pushPath({ name: SETTINGS_NAV_SERVER, param: serverParam }, animated);
    } else if (this.route === AppRoute.SENSOR_SETTINGS) {
      const sensorParam: SettingsNavDestinationParam = { key: SETTINGS_NAV_SENSOR };
      this.pathStack.pushPath({ name: SETTINGS_NAV_SENSOR, param: sensorParam }, animated);
    } else if (this.route === AppRoute.SENSOR_UPDATE_FREQUENCY) {
      const frequencyParam: SettingsNavDestinationParam = { key: SETTINGS_NAV_SENSOR_FREQUENCY };
      this.pathStack.pushPath({ name: SETTINGS_NAV_SENSOR_FREQUENCY, param: frequencyParam }, animated);
    } else if (this.route === AppRoute.NOTIFICATION_SETTINGS) {
      const notificationParam: SettingsNavDestinationParam = { key: SETTINGS_NAV_NOTIFICATION };
      this.pathStack.pushPath({ name: SETTINGS_NAV_NOTIFICATION, param: notificationParam }, animated);
    } else if (this.route === AppRoute.SETTINGS_DETAIL && this.detailKey.length > 0) {
      if (this.isServerDetail()) {
        const serverParam: SettingsNavDestinationParam = { key: SETTINGS_NAV_SERVER };
        this.pathStack.pushPath({ name: SETTINGS_NAV_SERVER, param: serverParam }, false);
      }
      const param: SettingsNavDestinationParam = { key: this.detailKey };
      this.pathStack.pushPath({ name: SETTINGS_NAV_DETAIL, param: param }, animated);
    }
    this.syncedRoute = this.route;
    this.syncedDetailKey = this.detailKey;
  }

  private schedulePathStackRestore(animated: boolean): void {
    setTimeout((): void => {
      if (!this.isRestorableSettingsRoute()) {
        this.syncedRoute = this.route;
        this.syncedDetailKey = this.detailKey;
        return;
      }
      if (this.route === this.syncedRoute && this.detailKey === this.syncedDetailKey) {
        return;
      }
      this.restorePathStackForSnapshot(animated);
    }, PATH_STACK_RESTORE_DELAY_MS);
  }

  private markPathStackSynced(target: SettingsNavSyncTarget): void {
    this.syncedRoute = target.route;
    this.syncedDetailKey = target.detailKey;
  }

  private openSettingsItem(item: SettingsItem): void {
    openSettingsNavigationItem(item, this.pathStack, this.actions, (target: SettingsNavSyncTarget): void => {
      this.markPathStackSynced(target);
    });
  }

  private openSettingsAction(actionId: string): void {
    openSettingsNavigationAction(actionId, this.pathStack, this.actions, (target: SettingsNavSyncTarget): void => {
      this.markPathStackSynced(target);
    });
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
    return this.detailKey.startsWith('server_');
  }

  @Builder
  private renderCompanionRoot(): void {
    CompanionSettingsSurfaceHost({
      sections: this.snapshot.companionSections,
      contentMaxWidth: this.snapshot.contentMaxWidth,
      selectedKey: this.snapshot.selectedKey,
      scrollOffset: this.snapshot.companionScrollOffset,
      showChoiceDialog: this.snapshot.showChoiceDialog && this.snapshot.choiceDialogKey !== 'server_connection_security',
      choiceDialogKey: this.snapshot.choiceDialogKey,
      screenOrientation: this.snapshot.screenOrientation,
      pageZoomLevel: this.snapshot.pageZoomLevel,
      appLanguage: this.snapshot.appLanguage,
      appTheme: this.snapshot.appTheme,
      secureConnectionChoice: this.snapshot.secureConnectionChoice,
      websocketMode: this.snapshot.websocketMode,
      serviceCardUpdateFrequency: this.snapshot.serviceCardUpdateFrequency,
      assistWakeDetectionEnabled: this.snapshot.assistWakeDetectionEnabled,
      assistWakeWord: this.snapshot.assistWakeWord,
      assistProbabilityCutoff: this.snapshot.assistProbabilityCutoff,
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
