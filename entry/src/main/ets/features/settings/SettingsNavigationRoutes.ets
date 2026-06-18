// Maps native settings routes to ArkUI pages and overlay hosts.
// Keep route-to-page wiring here so settings navigation remains auditable.
import { AppRoute } from '../../app/AppRoute';
import { AppRuntimeOverlayActions, AppRuntimeOverlaySnapshot } from '../../app/AppRuntimeOverlayModels';
import { SettingsItem, SettingsItemType } from '../../models/SettingsItem';
import {
  ServerSettingsSurfaceHost,
  SettingsDetailSurfaceHost
} from './SettingsSurfaceRuntimeHost';
import { SettingsRuntimeActions, SettingsRuntimeSnapshot } from './SettingsRuntimeCoordinatorModels';
import { CompanionSettingsData } from './CompanionSettingsData';
import { NativeSettingsOverlayHost } from './NativeSettingsOverlayHost';
import { SensorSettingsOverlayHost } from '../sensors/SensorSettingsOverlayHost';
import { SensorGroup } from '../sensors/SensorModels';
import { NotificationHistoryPage } from '../notifications/NotificationHistoryPage';
import { NotificationService } from '../notifications/NotificationService';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import { HdsNavDestination } from '@kit.UIDesignKit';
import common from '@ohos.app.ability.common';

export const SETTINGS_NAV_SERVER: string = 'CompanionServerSettings';
export const SETTINGS_NAV_DETAIL: string = 'CompanionSettingsDetail';
export const SETTINGS_NAV_SENSOR: string = 'CompanionSensorSettings';
export const SETTINGS_NAV_SENSOR_FREQUENCY: string = 'CompanionSensorFrequency';
export const SETTINGS_NAV_NOTIFICATION: string = 'CompanionNotificationSettings';
export const SETTINGS_NAV_NOTIFICATION_HISTORY: string = 'CompanionNotificationHistory';

export interface SettingsNavDestinationParam {
  key: string;
}

export interface SettingsNavSyncTarget {
  route: AppRoute;
  detailKey: string;
}

export interface SettingsNavSyncActions {
  onSynced: (target: SettingsNavSyncTarget) => void;
}

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

function isServerDetail(detailKey: string): boolean {
  return detailKey.startsWith('server_');
}

function popToRoot(pathStack: NavPathStack, animated: boolean): void {
  while (pathStack.size() > 0) {
    pathStack.pop(animated);
  }
}

function navParam(key: string): SettingsNavDestinationParam {
  return { key: key };
}

function routeToRoot(
  pathStack: NavPathStack,
  actions: SettingsRuntimeActions,
  onSynced?: (target: SettingsNavSyncTarget) => void
): void {
  actions.onRoute(AppRoute.COMPANION_SETTINGS);
  popToRoot(pathStack, true);
  notifySynced(onSynced, AppRoute.COMPANION_SETTINGS);
}

function routeToServer(
  pathStack: NavPathStack,
  actions: SettingsRuntimeActions,
  onSynced?: (target: SettingsNavSyncTarget) => void
): void {
  actions.onRoute(AppRoute.SERVER_SETTINGS);
  popToRoot(pathStack, false);
  pathStack.pushPath({ name: SETTINGS_NAV_SERVER, param: navParam(SETTINGS_NAV_SERVER) }, true);
  notifySynced(onSynced, AppRoute.SERVER_SETTINGS);
}

function routeToDetail(
  pathStack: NavPathStack,
  detailKey: string,
  onSynced?: (target: SettingsNavSyncTarget) => void
): void {
  const param: SettingsNavDestinationParam = { key: detailKey };
  pathStack.pushPath({ name: SETTINGS_NAV_DETAIL, param: param }, true);
  notifySynced(onSynced, AppRoute.SETTINGS_DETAIL, detailKey);
}

function notifySynced(
  onSynced: ((target: SettingsNavSyncTarget) => void) | undefined,
  route: AppRoute,
  detailKey: string = ''
): void {
  if (!onSynced) {
    return;
  }
  onSynced({ route: route, detailKey: detailKey });
}

function usesServerEditDialog(actionId: string): boolean {
  return actionId === 'server_name' ||
    actionId === 'server_device_name' ||
    actionId === 'server_external_url' ||
    actionId === 'server_internal_url' ||
    actionId === 'server_session_timeout';
}

function usesExternalServerFlow(actionId: string): boolean {
  return actionId === 'server_connection_security';
}

function routeAction(
  pathStack: NavPathStack,
  actions: SettingsRuntimeActions,
  actionId: string,
  onSynced?: (target: SettingsNavSyncTarget) => void
): void {
  actions.onAction(actionId);
  setTimeout((): void => {
    if (actionId === 'open_server' || actionId.startsWith('open_server_detail:')) {
      routeToServer(pathStack, actions, onSynced);
    } else if (actionId === 'open_display_gestures') {
      routeToDetail(pathStack, 'display_gestures', onSynced);
    } else if (actionId === 'open_sensor_settings') {
      pathStack.pushPath({ name: SETTINGS_NAV_SENSOR, param: navParam(SETTINGS_NAV_SENSOR) }, true);
      notifySynced(onSynced, AppRoute.SENSOR_SETTINGS);
    } else if (actionId === 'open_sensor_update_frequency') {
      pathStack.pushPath({ name: SETTINGS_NAV_SENSOR_FREQUENCY, param: navParam(SETTINGS_NAV_SENSOR_FREQUENCY) }, true);
      notifySynced(onSynced, AppRoute.SENSOR_UPDATE_FREQUENCY);
    } else if (actionId === 'open_notification_settings') {
      pathStack.pushPath({ name: SETTINGS_NAV_NOTIFICATION, param: navParam(SETTINGS_NAV_NOTIFICATION) }, true);
      notifySynced(onSynced, AppRoute.NOTIFICATION_SETTINGS);
    }
  }, 0);
}

export function openSettingsNavigationItem(
  item: SettingsItem,
  pathStack: NavPathStack,
  actions: SettingsRuntimeActions,
  onSynced?: (target: SettingsNavSyncTarget) => void
): void {
  actions.onOpen(item);
  if (item.type === SettingsItemType.SWITCH ||
    usesServerEditDialog(item.actionId) ||
    usesExternalServerFlow(item.actionId)) {
    return;
  }
  setTimeout((): void => {
    if (item.actionId.startsWith('server_')) {
      routeToDetail(pathStack, item.actionId, onSynced);
    } else if (item.actionId === 'open_server' || item.actionId.startsWith('open_server_detail:')) {
      routeToServer(pathStack, actions, onSynced);
    } else if (item.actionId.length > 0) {
      routeToDetail(pathStack, item.actionId, onSynced);
    }
  }, 0);
}

export function openSettingsNavigationAction(
  actionId: string,
  pathStack: NavPathStack,
  actions: SettingsRuntimeActions,
  onSynced?: (target: SettingsNavSyncTarget) => void
): void {
  routeAction(pathStack, actions, actionId, onSynced);
}

@Builder
export function CompanionServerSettingsBuilder(): void {
  CompanionServerSettingsRoute()
}

@Builder
export function CompanionSettingsDetailBuilder(): void {
  CompanionSettingsDetailRoute()
}

@Builder
export function CompanionSensorSettingsBuilder(): void {
  CompanionSensorSettingsRoute()
}

@Builder
export function CompanionSensorFrequencyBuilder(): void {
  CompanionSensorFrequencyRoute()
}

@Builder
export function CompanionNotificationSettingsBuilder(): void {
  CompanionNativeSettingsRoute({ route: AppRoute.NOTIFICATION_SETTINGS })
}

@Builder
export function CompanionNotificationHistoryBuilder(): void {
  CompanionNotificationHistoryRoute()
}

@Component
struct CompanionServerSettingsRoute {
  @Consume('settingsRuntimeSnapshot') snapshot: SettingsRuntimeSnapshot = DEFAULT_SETTINGS_RUNTIME_SNAPSHOT;
  @Consume('settingsRuntimeActions') actions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  @Consume('settingsPathStack') pathStack: NavPathStack;
  @Consume('settingsNavSyncActions') navSyncActions: SettingsNavSyncActions = DEFAULT_SETTINGS_NAV_SYNC_ACTIONS;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;

  build() {
    HdsNavDestination() {
      ServerSettingsSurfaceHost({
        title: this.snapshot.serverTitle,
        sections: this.snapshot.serverSections,
        contentMaxWidth: this.snapshot.contentMaxWidth,
        selectedKey: this.snapshot.selectedKey,
        scrollOffset: this.snapshot.serverScrollOffset,
        showChoiceDialog: this.snapshot.showChoiceDialog && this.snapshot.choiceDialogKey === 'server_connection_security',
        choiceDialogKey: this.snapshot.choiceDialogKey,
        secureConnectionChoice: this.snapshot.secureConnectionChoice,
        dark: this.snapshot.dark,
        onBack: (): void => routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced),
        onOpen: (item: SettingsItem): void =>
          openSettingsNavigationItem(item, this.pathStack, this.actions, this.navSyncActions.onSynced),
        onAction: (actionId: string): void =>
          openSettingsNavigationAction(actionId, this.pathStack, this.actions, this.navSyncActions.onSynced),
        onScrollOffsetChange: this.actions.onServerScrollOffsetChange,
        onSwipeBack: this.actions.onSwipeBack,
        onSelectChoice: this.actions.onSelectCompanionChoice,
        onCloseChoice: this.actions.onCloseCompanionChoice
      })
    }
    .titleBar(SettingsUiConfig.titleBar(this.snapshot.serverTitle,
      (): void => routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced), this.appResolvedDark))
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced);
      return true;
    })
  }
}

@Component
struct CompanionSensorSettingsRoute {
  @Consume('settingsRuntimeActions') actions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  @Consume('settingsOverlaySnapshot') overlaySnapshot: AppRuntimeOverlaySnapshot;
  @Consume('settingsOverlaySensorGroups') sensorGroups: SensorGroup[];
  @Consume('settingsOverlayActions') overlayActions: AppRuntimeOverlayActions = DEFAULT_OVERLAY_ACTIONS;
  @Consume('settingsPathStack') pathStack: NavPathStack;
  @Consume('settingsNavSyncActions') navSyncActions: SettingsNavSyncActions = DEFAULT_SETTINGS_NAV_SYNC_ACTIONS;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;

  build() {
    HdsNavDestination() {
      SensorSettingsOverlayHost({
        route: AppRoute.SENSOR_SETTINGS,
        groups: this.sensorGroups,
        selectedFrequency: this.overlaySnapshot.sensorUpdateFrequency,
        contentMaxWidth: this.overlaySnapshot.contentMaxWidth,
        onBack: (): void => routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced),
        onHelp: this.overlayActions.onSensorHelp,
        onSearch: this.overlayActions.onSensorSearch,
        onFilter: this.overlayActions.onSensorFilter,
        onToggleSensor: this.overlayActions.onToggleSensor,
        onSelectFrequency: this.overlayActions.onSelectSensorFrequency,
        onSwipeBack: this.overlayActions.onSwipeBack
      })
    }
    .titleBar(SettingsUiConfig.titleBar(Localization.t('sensor_title'),
      (): void => routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced), this.appResolvedDark))
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced);
      return true;
    })
  }
}

@Component
struct CompanionSensorFrequencyRoute {
  @Consume('settingsRuntimeActions') actions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  @Consume('settingsOverlaySnapshot') overlaySnapshot: AppRuntimeOverlaySnapshot;
  @Consume('settingsOverlayActions') overlayActions: AppRuntimeOverlayActions = DEFAULT_OVERLAY_ACTIONS;
  @Consume('settingsPathStack') pathStack: NavPathStack;
  @Consume('settingsNavSyncActions') navSyncActions: SettingsNavSyncActions = DEFAULT_SETTINGS_NAV_SYNC_ACTIONS;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;

  build() {
    HdsNavDestination() {
      SensorSettingsOverlayHost({
        route: AppRoute.SENSOR_UPDATE_FREQUENCY,
        groups: this.overlaySnapshot.sensorGroups,
        selectedFrequency: this.overlaySnapshot.sensorUpdateFrequency,
        contentMaxWidth: this.overlaySnapshot.contentMaxWidth,
        onBack: (): void => routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced),
        onHelp: this.overlayActions.onSensorHelp,
        onSearch: this.overlayActions.onSensorSearch,
        onFilter: this.overlayActions.onSensorFilter,
        onToggleSensor: this.overlayActions.onToggleSensor,
        onSelectFrequency: this.overlayActions.onSelectSensorFrequency,
        onSwipeBack: this.overlayActions.onSwipeBack
      })
    }
    .titleBar(SettingsUiConfig.titleBar(Localization.t('settings_sensor_update_frequency'),
      (): void => routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced), this.appResolvedDark))
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .hideBackButton(false)
    .onBackPressed((): boolean => {
      routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced);
      return true;
    })
  }
}

@Component
struct CompanionNativeSettingsRoute {
  @Prop route: number = AppRoute.NOTIFICATION_SETTINGS;
  @Consume('settingsRuntimeActions') actions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  @Consume('settingsOverlaySnapshot') overlaySnapshot: AppRuntimeOverlaySnapshot;
  @Consume('settingsOverlayActions') overlayActions: AppRuntimeOverlayActions = DEFAULT_OVERLAY_ACTIONS;
  @Consume('settingsPathStack') pathStack: NavPathStack;
  @Consume('settingsNavSyncActions') navSyncActions: SettingsNavSyncActions = DEFAULT_SETTINGS_NAV_SYNC_ACTIONS;

  build() {
    NavDestination() {
      NativeSettingsOverlayHost({
        route: this.route,
        profile: this.overlaySnapshot.profile,
        onBack: (): void => routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced),
        onOpenNotificationHistory: (): void => {
          this.pathStack.pushPath({
            name: SETTINGS_NAV_NOTIFICATION_HISTORY,
            param: navParam(SETTINGS_NAV_NOTIFICATION_HISTORY)
          }, true);
        },
        onSwipeBack: this.overlayActions.onSwipeBack
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced);
      return true;
    })
  }
}

@Component
struct CompanionNotificationHistoryRoute {
  @Consume('settingsRuntimeActions') actions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  @Consume('settingsOverlaySnapshot') overlaySnapshot: AppRuntimeOverlaySnapshot;
  @Consume('settingsPathStack') pathStack: NavPathStack;
  @Consume('settingsNavSyncActions') navSyncActions: SettingsNavSyncActions = DEFAULT_SETTINGS_NAV_SYNC_ACTIONS;

  private backToNotifications(): void {
    this.actions.onRoute(AppRoute.NOTIFICATION_SETTINGS);
    this.pathStack.pop(true);
    this.navSyncActions.onSynced({ route: AppRoute.NOTIFICATION_SETTINGS, detailKey: '' });
  }

  build() {
    NavDestination() {
      NotificationHistoryPage({
        contentMaxWidth: this.overlaySnapshot.contentMaxWidth,
        onBack: (): void => this.backToNotifications(),
        onClearAll: (): void => {
          const context = this.getUIContext().getHostContext() as common.Context;
          NotificationService.cancelAll(context).catch((): void => {});
        },
        onSwipeBack: (): void => this.backToNotifications()
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.backToNotifications();
      return true;
    })
  }
}

@Component
struct CompanionSettingsDetailRoute {
  @Consume('settingsRuntimeSnapshot') snapshot: SettingsRuntimeSnapshot = DEFAULT_SETTINGS_RUNTIME_SNAPSHOT;
  @Consume('settingsRuntimeActions') actions: SettingsRuntimeActions = DEFAULT_SETTINGS_RUNTIME_ACTIONS;
  @Consume('settingsPathStack') pathStack: NavPathStack;
  @Consume('settingsNavSyncActions') navSyncActions: SettingsNavSyncActions = DEFAULT_SETTINGS_NAV_SYNC_ACTIONS;

  private backToParent(): void {
    if (isServerDetail(this.snapshot.detailKey)) {
      this.actions.onRoute(AppRoute.SERVER_SETTINGS);
      this.navSyncActions.onSynced({ route: AppRoute.SERVER_SETTINGS, detailKey: '' });
    } else {
      this.actions.onRoute(AppRoute.COMPANION_SETTINGS);
      this.navSyncActions.onSynced({ route: AppRoute.COMPANION_SETTINGS, detailKey: '' });
    }
    this.pathStack.pop(true);
  }

  build() {
    NavDestination() {
      SettingsDetailSurfaceHost({
        detailKey: this.snapshot.detailKey,
        title: this.snapshot.detailTitle,
        summary: this.snapshot.detailSummary,
        body: this.snapshot.detailBody,
        status: this.snapshot.detailStatus,
        action: this.snapshot.detailAction,
        textValue: this.snapshot.detailTextValue,
        optionValue: this.snapshot.detailOptionValue,
        contentMaxWidth: this.snapshot.contentMaxWidth,
        wifiSsids: this.snapshot.wifiSsids,
        ssidInput: this.snapshot.ssidInput,
        prioritizeInternal: this.snapshot.prioritizeInternal,
        gestureGroups: this.snapshot.gestureGroups,
        screenOrientation: this.snapshot.screenOrientation,
        pageZoomLevel: this.snapshot.pageZoomLevel,
        appLanguage: this.snapshot.appLanguage,
        appTheme: this.snapshot.appTheme,
        serviceCardUpdateFrequency: this.snapshot.serviceCardUpdateFrequency,
        assistWakeDetectionEnabled: this.snapshot.assistWakeDetectionEnabled,
        assistWakeWord: this.snapshot.assistWakeWord,
        assistProbabilityCutoff: this.snapshot.assistProbabilityCutoff,
        gestureActionValue: this.actions.gestureActionValue,
        onRoute: (route: number): void => {
          if (route === AppRoute.SERVER_SETTINGS) {
            routeToServer(this.pathStack, this.actions, this.navSyncActions.onSynced);
          } else {
            routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced);
          }
        },
        onSetDetailHeader: (key: string, title: string): void => {
          this.actions.onSetDetailHeader(key, title);
          routeToDetail(this.pathStack, key, this.navSyncActions.onSynced);
        },
        onToggleAssistWakeDetection: this.actions.onToggleAssistWakeDetection,
        onOpenAssistProbabilityCutoff: this.actions.onOpenAssistProbabilityCutoff,
        onOpenDashboard: this.actions.onOpenDashboard,
        onSsidInputChange: this.actions.onSsidInputChange,
        onAddSsid: this.actions.onAddSsid,
        onRemoveSsid: this.actions.onRemoveSsid,
        onPrioritizeChange: this.actions.onPrioritizeChange,
        onSelectGestureAction: (key: string, value: string): void => {
          this.actions.onSelectGestureAction(key, value);
          this.actions.onSetDetailHeader('display_gestures', CompanionSettingsData.gestureTitle(key));
          this.pathStack.pop(true);
          this.navSyncActions.onSynced({ route: AppRoute.SETTINGS_DETAIL, detailKey: 'display_gestures' });
        },
        onSelectChoice: (key: string, value: string): void => {
          this.actions.onSelectDetailChoice(key, value);
          if (key !== 'assist_voice') {
            routeToRoot(this.pathStack, this.actions, this.navSyncActions.onSynced);
          }
        },
        onTextChange: this.actions.onDetailTextChange,
        onOptionChange: (value: string): void => {
          this.actions.onDetailOptionChange(value);
          if (this.snapshot.detailKey === 'server_websocket') {
            this.backToParent();
          }
        },
        onSaveServerDetail: this.actions.onSaveServerDetail,
        onHelp: this.actions.onHelp,
        onSwipeBack: this.actions.onSwipeBack
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.backToParent();
      return true;
    })
  }
}
