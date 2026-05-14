import { SettingsItem } from '../models/SettingsItem';
import { DeviceProfileInfo } from '../shared/device/DeviceProfile';
import { SettingsSummaryService } from '../features/settings/SettingsSummaryService';
import { SettingsSectionRuntimeService, SettingsSectionRuntimeState } from '../features/settings/SettingsSectionRuntimeService';
import { SettingsInteractionRuntimeService, SettingsInteractionState } from '../features/settings/SettingsInteractionRuntimeService';
import { SettingsChoiceRuntimeService } from '../features/settings/SettingsChoiceRuntimeService';
import { GestureRuntimeService, GestureRuntimeState } from '../features/settings/GestureRuntimeService';
import { SettingsRuntimeActions, SettingsRuntimeSnapshot } from '../features/settings/SettingsRuntimeCoordinatorModels';
import { Localization } from '../shared/i18n/Localization';
import { AppSettingsStore } from '../services/AppSettingsStore';
import { NetworkService } from '../services/NetworkService';
import { AppRuntimeCallbackFactory, AppRuntimeCallbackTarget } from './AppRuntimeCallbackFactory';
import { AppRoute } from './AppRoute';

export interface AppSettingsRuntimeTarget extends SettingsSectionRuntimeState, GestureRuntimeState, SettingsInteractionState, AppRuntimeCallbackTarget {
  step: number;
  configSummary: string;
  serverNameOverride: string;
  companionSettingsScrollOffset: number;
  serverSettingsScrollOffset: number;
  settingsRevision: number;
  showCompanionChoiceDialog: boolean;
  companionChoiceDialogKey: string;
  screenOrientation: string;
  pageZoomLevel: string;
  appLanguage: string;
  appTheme: string;
  secureConnectionChoice: string;
  serviceCardUpdateFrequency: string;
  notificationUnreadCount: number;
  appResolvedDark: boolean;
  showDeleteServerDialog: boolean;
  deletingServer: boolean;
  showServerEditDialog: boolean;
  serverEditTitle: string;
  serverEditValue: string;
  settingsDetailKey: string;
  settingsDetailTitle: string;
  settingsDetailSummary: string;
  settingsDetailBody: string;
  settingsDetailStatus: string;
  settingsDetailAction: string;
  settingsEditValue: string;
  settingsOptionValue: string;
  homeWifiSsids: string[];
  homeSsidInput: string;
  prioritizeInternal: boolean;
  websocketMode: string;
  message: string;
  currentDeviceProfile(): DeviceProfileInfo;
  settingsContentMaxWidth(): number;
  returnToHaSettingsPage(): void;
  handleBackNavigation(): boolean;
  selectCompanionChoice(value: string): void;
  selectSettingsDetailChoice(key: string, value: string): void;
  closeCompanionChoiceDialog(): void;
  deleteCurrentServer(): void;
  handleSettingsAction(actionId: string): void;
  openDashboard(): void;
  returnToDashboardFromSettings(): void;
  refreshHomeNetworkStatus(): void;
}

export class AppSettingsRuntimeService {
  private static selectedSettingsKey(route: number, detailKey: string): string {
    if (route === AppRoute.SERVER_SETTINGS) {
      return 'open_server';
    }
    if (route === AppRoute.SENSOR_SETTINGS) {
      return 'open_sensor_settings';
    }
    if (route === AppRoute.SENSOR_UPDATE_FREQUENCY) {
      return 'open_sensor_update_frequency';
    }
    if (route === AppRoute.NOTIFICATION_SETTINGS) {
      return 'open_notification_settings';
    }
    if (route !== AppRoute.SETTINGS_DETAIL) {
      return '';
    }
    if (detailKey === 'display_gestures') {
      return 'open_display_gestures';
    }
    if (detailKey === 'display_orientation') {
      return 'open_display_orientation';
    }
    if (detailKey === 'display_zoom') {
      return 'open_display_zoom';
    }
    if (detailKey === 'display_language') {
      return 'open_display_language';
    }
    if (detailKey === 'display_theme') {
      return 'open_display_theme';
    }
    return detailKey;
  }

  static snapshot(target: AppSettingsRuntimeTarget): SettingsRuntimeSnapshot {
    const profile = target.currentDeviceProfile();
    return {
      route: target.step,
      companionSections: SettingsSectionRuntimeService.companionSectionsFromState(target, profile),
      serverSections: SettingsSectionRuntimeService.serverSectionsFromState(target, profile),
      serverTitle: target.selectedServerSettingsName.length > 0
        ? target.selectedServerSettingsName
        : SettingsSummaryService.serverDisplayName('', target.configSummary),
      contentMaxWidth: target.settingsContentMaxWidth(),
      selectedKey: AppSettingsRuntimeService.selectedSettingsKey(target.step, target.settingsDetailKey),
      companionScrollOffset: target.companionSettingsScrollOffset,
      serverScrollOffset: target.serverSettingsScrollOffset,
      switchRevision: target.settingsRevision,
      showChoiceDialog: target.showCompanionChoiceDialog,
      choiceDialogKey: target.companionChoiceDialogKey,
      screenOrientation: target.screenOrientation,
      pageZoomLevel: target.pageZoomLevel,
      appLanguage: target.appLanguage,
      appTheme: target.appTheme,
      secureConnectionChoice: target.secureConnectionChoice,
      websocketMode: target.websocketMode,
      serviceCardUpdateFrequency: target.serviceCardUpdateFrequency,
      dark: target.appResolvedDark,
      showDeleteServerDialog: target.showDeleteServerDialog,
      deletingServer: target.deletingServer,
      showEditDialog: target.showServerEditDialog,
      editTitle: target.serverEditTitle,
      editValue: target.serverEditValue,
      editUnit: target.serverEditKey === 'server_session_timeout' ? Localization.t('unit_seconds') : '',
      detailKey: target.settingsDetailKey,
      detailTitle: target.settingsDetailTitle,
      detailSummary: target.settingsDetailSummary,
      detailBody: target.settingsDetailBody,
      detailStatus: target.settingsDetailStatus,
      detailAction: target.settingsDetailAction,
      detailTextValue: target.settingsEditValue,
      detailOptionValue: target.settingsOptionValue,
      wifiSsids: target.homeWifiSsids,
      ssidInput: target.homeSsidInput,
      prioritizeInternal: target.prioritizeInternal,
      gestureGroups: GestureRuntimeService.groups(target)
    };
  }

  static actions(target: AppSettingsRuntimeTarget): SettingsRuntimeActions {
    return {
      gestureActionValue: (key: string): string => GestureRuntimeService.value(target, key),
      onBackToHaSettings: (): void => target.returnToHaSettingsPage(),
      onRoute: (route: number): void => {
        target.step = route;
      },
      onOpen: (item: SettingsItem): void => {
        SettingsInteractionRuntimeService.openSettingsItem(
          item,
          target,
          AppRuntimeCallbackFactory.settingsInteraction(target)
        );
      },
      onAction: (actionId: string): void => target.handleSettingsAction(actionId),
      onCompanionScrollOffsetChange: (offset: number): void => {
        target.companionSettingsScrollOffset = offset;
      },
      onServerScrollOffsetChange: (offset: number): void => {
        target.serverSettingsScrollOffset = offset;
      },
      onSwipeBack: (): void => {
        target.handleBackNavigation();
      },
      onSelectCompanionChoice: (value: string): void => {
        target.selectCompanionChoice(value);
        AppSettingsStore.saveCurrentAppStorage(target.context()).catch((): void => {});
      },
      onCloseCompanionChoice: (): void => target.closeCompanionChoiceDialog(),
      onCancelDelete: (): void => {
        target.showDeleteServerDialog = false;
      },
      onDeleteServer: (): void => target.deleteCurrentServer(),
      onEditValueChange: (value: string): void => {
        target.serverEditValue = value;
      },
      onCancelEdit: (): void => {
        target.showServerEditDialog = false;
      },
      onSaveEdit: (): void => {
        SettingsInteractionRuntimeService.saveServerEditDialog(
          target,
          AppRuntimeCallbackFactory.settingsInteraction(target)
        );
      },
      onSetDetailHeader: (key: string, title: string): void => {
        target.settingsDetailKey = key;
        target.settingsDetailTitle = title;
      },
      onOpenDashboard: (): void => target.returnToDashboardFromSettings(),
      onSsidInputChange: (value: string): void => {
        target.homeSsidInput = value;
        target.bumpSettingsRevision();
      },
      onAddSsid: (): void => {
        target.homeSsidInput = NetworkService.normalizeWifiSsids([target.homeSsidInput])[0] ?? '';
        SettingsInteractionRuntimeService.addHomeWifiSsid(target);
        target.bumpSettingsRevision();
        AppSettingsStore.saveHomeNetwork(
          target.context(),
          target.homeWifiSsids,
          target.prioritizeInternal
        ).catch((): void => {});
        target.refreshHomeNetworkStatus();
      },
      onRemoveSsid: (value: string): void => {
        SettingsInteractionRuntimeService.removeHomeWifiSsid(value, target);
        target.bumpSettingsRevision();
        AppSettingsStore.saveHomeNetwork(
          target.context(),
          target.homeWifiSsids,
          target.prioritizeInternal
        ).catch((): void => {});
        target.refreshHomeNetworkStatus();
      },
      onPrioritizeChange: (value: boolean): void => {
        target.prioritizeInternal = value;
        target.bumpSettingsRevision();
        AppSettingsStore.saveHomeNetwork(
          target.context(),
          target.homeWifiSsids,
          target.prioritizeInternal
        ).catch((): void => {});
        target.refreshHomeNetworkStatus();
      },
      onSelectGestureAction: (key: string, value: string): void => {
        GestureRuntimeService.setValue(target, key, value);
        AppSettingsStore.saveCurrentAppStorage(target.context()).catch((): void => {});
      },
      onSelectDetailChoice: (key: string, value: string): void => {
        target.selectSettingsDetailChoice(key, value);
        AppSettingsStore.saveCurrentAppStorage(target.context()).catch((): void => {});
      },
      onDetailTextChange: (value: string): void => {
        target.settingsEditValue = value;
      },
      onDetailOptionChange: (value: string): void => {
        target.settingsOptionValue = value;
        if (target.settingsDetailKey === 'server_websocket') {
          SettingsInteractionRuntimeService.applyPersistentConnectionMode(
            value.length > 0 ? value : 'system',
            target,
            AppRuntimeCallbackFactory.settingsInteraction(target)
          );
        }
      },
      onSaveServerDetail: (): void => {
        SettingsInteractionRuntimeService.saveServerSettingDetail(
          target,
          AppRuntimeCallbackFactory.settingsInteraction(target)
        );
      },
      onHelp: (): void => {
        target.message = 'https://companion.home-assistant.io/docs/notifications/notification-local';
      }
    };
  }
}
