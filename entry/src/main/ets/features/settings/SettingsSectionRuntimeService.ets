import { SettingsSection } from '../../models/SettingsItem';
import { StoredServerInfo } from '../../services/StorageService';
import { DeviceProfileInfo } from '../../shared/device/DeviceProfile';
import { SettingsSectionService } from './SettingsSectionService';
import { SettingsSummaryService } from './SettingsSummaryService';

export interface CompanionSettingsSectionInput {
  profile: DeviceProfileInfo;
  serverNameOverride: string;
  configSummary: string;
  deviceName: string;
  serverOptions: ServerOption[];
  sensorUpdateFrequency: string;
  fullScreenEnabled: boolean;
  screenOrientation: string;
  keepScreenOnEnabled: boolean;
  pageZoomLevel: string;
  pinchToZoomEnabled: boolean;
  autoPlayVideoEnabled: boolean;
  alwaysShowFirstViewOnAppStartEnabled: boolean;
  serviceCardUpdateFrequency: string;
  appLanguage: string;
  appTheme: string;
  notificationUnreadCount: number;
}

export interface ServerOption {
  id: string;
  name: string;
  summary: string;
  active: boolean;
}

export interface ServerSettingsSectionInput {
  profile: DeviceProfileInfo;
  serverNameOverride: string;
  configSummary: string;
  deviceName: string;
  serverExternalUrl: string;
  haBaseUrl: string;
  homeWifiSsids: string[];
  serverInternalUrl: string;
  secureConnectionChoice: string;
  trustServer: boolean;
  appLockEnabled: boolean;
  appLockHomeBypass: boolean;
  sessionTimeout: string;
  websocketMode: string;
  showActivateServer: boolean;
}

export interface SettingsSectionRuntimeState {
  serverNameOverride: string;
  configSummary: string;
  deviceName: string;
  sensorUpdateFrequency: string;
  fullScreenEnabled: boolean;
  screenOrientation: string;
  keepScreenOnEnabled: boolean;
  pageZoomLevel: string;
  pinchToZoomEnabled: boolean;
  autoPlayVideoEnabled: boolean;
  alwaysShowFirstViewOnAppStartEnabled: boolean;
  serviceCardUpdateFrequency: string;
  appLanguage: string;
  appTheme: string;
  serverOptions: ServerOption[];
  serverExternalUrl: string;
  haBaseUrl: string;
  homeWifiSsids: string[];
  homeNetworkName: string;
  serverInternalUrl: string;
  secureConnectionChoice: string;
  trustServer: boolean;
  appLockEnabled: boolean;
  appLockHomeBypass: boolean;
  sessionTimeout: string;
  websocketMode: string;
  notificationUnreadCount: number;
  selectedServerSettingsId: string;
  selectedServerSettingsName: string;
  selectedServerSettingsInfo: StoredServerInfo;
  selectedServerSettingsActive: boolean;
}

export class SettingsSectionRuntimeService {
  static companionSectionsFromState(
    state: SettingsSectionRuntimeState,
    profile: DeviceProfileInfo
  ): SettingsSection[] {
    return SettingsSectionRuntimeService.companionSections({
      profile: profile,
      serverNameOverride: '',
      configSummary: state.configSummary,
      deviceName: state.deviceName,
      serverOptions: state.serverOptions,
      sensorUpdateFrequency: state.sensorUpdateFrequency,
      fullScreenEnabled: state.fullScreenEnabled,
      screenOrientation: state.screenOrientation,
      keepScreenOnEnabled: state.keepScreenOnEnabled,
      pageZoomLevel: state.pageZoomLevel,
      pinchToZoomEnabled: state.pinchToZoomEnabled,
      autoPlayVideoEnabled: state.autoPlayVideoEnabled,
      alwaysShowFirstViewOnAppStartEnabled: state.alwaysShowFirstViewOnAppStartEnabled,
      serviceCardUpdateFrequency: state.serviceCardUpdateFrequency,
      appLanguage: state.appLanguage,
      appTheme: state.appTheme,
      notificationUnreadCount: state.notificationUnreadCount
    });
  }

  static serverSectionsFromState(
    state: SettingsSectionRuntimeState,
    profile: DeviceProfileInfo
  ): SettingsSection[] {
    const selectedInfo: StoredServerInfo | undefined = state.selectedServerSettingsId.length > 0
      ? state.selectedServerSettingsInfo
      : undefined;
    const selectedName: string = state.selectedServerSettingsId.length > 0
      ? state.selectedServerSettingsName
      : '';
    return SettingsSectionRuntimeService.serverSections({
      profile: profile,
      serverNameOverride: selectedName.length > 0 ? selectedName : '',
      configSummary: selectedName.length > 0 ? selectedName : state.configSummary,
      deviceName: selectedInfo ? selectedInfo.deviceName : state.deviceName,
      serverExternalUrl: selectedInfo ? selectedInfo.baseUrl : state.serverExternalUrl,
      haBaseUrl: selectedInfo ? selectedInfo.baseUrl : state.haBaseUrl,
      homeWifiSsids: state.homeWifiSsids,
      serverInternalUrl: state.serverInternalUrl,
      secureConnectionChoice: state.secureConnectionChoice,
      trustServer: state.trustServer,
      appLockEnabled: state.appLockEnabled,
      appLockHomeBypass: state.appLockHomeBypass,
      sessionTimeout: state.sessionTimeout,
      websocketMode: state.websocketMode,
      showActivateServer: state.selectedServerSettingsId.length > 0
    });
  }

  static companionSections(input: CompanionSettingsSectionInput): SettingsSection[] {
    return SettingsSectionService.companionSections({
      profile: input.profile,
      serverName: SettingsSummaryService.serverDisplayName(input.serverNameOverride, input.configSummary),
      deviceName: input.deviceName,
      serverOptions: input.serverOptions,
      sensorUpdateFrequencySummary: SettingsSummaryService.sensorUpdateFrequencySummary(input.sensorUpdateFrequency),
      fullScreenEnabled: input.fullScreenEnabled,
      screenOrientation: input.screenOrientation,
      keepScreenOnEnabled: input.keepScreenOnEnabled,
      pageZoomLevel: input.pageZoomLevel,
      pinchToZoomEnabled: input.pinchToZoomEnabled,
      autoPlayVideoEnabled: input.autoPlayVideoEnabled,
      alwaysShowFirstViewOnAppStartEnabled: input.alwaysShowFirstViewOnAppStartEnabled,
      serviceCardUpdateFrequency: input.serviceCardUpdateFrequency,
      appLanguage: input.appLanguage,
      appTheme: input.appTheme,
      notificationUnreadCount: input.notificationUnreadCount
    });
  }

  static serverSections(input: ServerSettingsSectionInput): SettingsSection[] {
    return SettingsSectionService.serverSections({
      profile: input.profile,
      serverName: SettingsSummaryService.serverDisplayName(input.serverNameOverride, input.configSummary),
      deviceName: input.deviceName,
      effectiveExternalUrl: SettingsSummaryService.effectiveExternalUrl(input.serverExternalUrl, input.haBaseUrl),
      homeNetworkSummary: SettingsSummaryService.homeNetworkSummary(input.homeWifiSsids),
      internalConnectionSummary: SettingsSummaryService.internalConnectionSummary(input.serverInternalUrl),
      securityLevelSummary: SettingsSummaryService.securityLevelSummary(input.secureConnectionChoice),
      trustServer: input.trustServer,
      appLockEnabled: input.appLockEnabled,
      appLockHomeBypass: input.appLockHomeBypass,
      sessionTimeoutSummary: SettingsSummaryService.sessionTimeoutSummary(input.sessionTimeout),
      websocketSummary: SettingsSummaryService.websocketSummary(input.websocketMode),
      showActivateServer: input.showActivateServer
    });
  }
}
