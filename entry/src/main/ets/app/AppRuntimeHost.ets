// Main runtime state holder for the phone app shell.
// It coordinates navigation, server selection, overlays, WebView state, and feature services.
import common from '@ohos.app.ability.common';
import web_webview from '@ohos.web.webview';
import { HaServerItem } from '../models/HaServerItem';
import { UrlGuardResult } from '../models/UrlGuardResult';
import { UrlService } from '../services/UrlService';
import { HaApiService } from '../services/HaApiService';
import {
  AuthRuntimeService
} from '../features/auth/AuthRuntimeService';
import { AuthFlowRuntimeService } from '../features/auth/AuthFlowRuntimeService';
import { ExternalAuthRuntimeService } from '../features/auth/ExternalAuthRuntimeService';
import { DiscoveryFlowRuntimeService } from '../features/discovery/DiscoveryFlowRuntimeService';
import { ServerAccountRuntimeService } from '../features/settings/ServerAccountRuntimeService';
import { SettingsSummaryService } from '../features/settings/SettingsSummaryService';
import { SettingsRouteService } from '../features/settings/SettingsRouteService';
import { SettingsChoiceRuntimeService } from '../features/settings/SettingsChoiceRuntimeService';
import { SettingsInteractionRuntimeService } from '../features/settings/SettingsInteractionRuntimeService';
import { ExternalAppProxy } from '../features/dashboard/ExternalAppProxy';
import { DashboardRuntimeService } from '../features/dashboard/DashboardRuntimeService';
import { AppLockRuntimeService } from '../features/security/AppLockRuntimeService';
import { AppLockUnlockRuntimeService } from '../features/security/AppLockUnlockRuntimeService';
import { SensorGroup, SensorUpdateFrequency } from '../features/sensors/SensorModels';
import { SensorRuntimeFlags } from '../features/sensors/SensorRuntimePresenter';
import { SensorRuntimeService, SensorRuntimeSnapshot } from '../features/sensors/SensorRuntimeService';
import { SensorRuntimeBridgeService } from '../features/sensors/SensorRuntimeBridgeService';
import { CardFormService } from '../features/cards/CardFormService';
import { MobileAppRegistrationService } from '../features/registration/MobileAppRegistrationService';
import { RegistrationRuntimeService } from '../features/registration/RegistrationRuntimeService';
import { DeviceProfileInfo } from '../shared/device/DeviceProfile';
import { Localization } from '../shared/i18n/Localization';
import { StorageService, StoredServerInfo } from '../services/StorageService';
import { DiscoveryCacheService } from '../services/DiscoveryCacheService';
import { ManagedServer, ServerManager } from '../services/ServerManager';
import { AppSettingsStore } from '../services/AppSettingsStore';
import { ExternalBusService } from '../services/ExternalBusService';
import { HaConnectionPolicyService } from '../services/HaConnectionPolicyService';
import { SystemEventService } from '../services/SystemEventService';
import {
  FrontendUrlResolution,
  HomeNetworkSettings,
  HomeNetworkService,
  WirelessSnapshot
} from '../services/HomeNetworkService';
import { NetworkService } from '../services/NetworkService';
import { AppBackDispatcher } from './AppBackDispatcher';
import { AppRoute } from './AppRoute';
import { AppRoutePolicy } from './AppRoutePolicy';
import { AppRuntimeOverlayService } from './AppRuntimeOverlayService';
import { AppWebRuntimeService } from './AppWebRuntimeService';
import { AppSettingsRuntimeService } from './AppSettingsRuntimeService';
import { AppOnboardingRuntimeService } from './AppOnboardingRuntimeService';
import { AppRuntimeShellHost } from './AppRuntimeShellHost';
import { AppRuntimeCallbackFactory } from './AppRuntimeCallbackFactory';
import { AppStorageDefaults } from './AppStorageDefaults';
import { AppDeviceRuntimeService } from './AppDeviceRuntimeService';
import { AppLifecycleRuntimeService } from './AppLifecycleRuntimeService';
import { AppNavigationRuntimeService } from './AppNavigationRuntimeService';
import { AppSessionRuntimeService } from './AppSessionRuntimeService';
import { AppWindowRuntimeService } from './AppWindowRuntimeService';
import { ServerOption } from '../features/settings/SettingsSectionRuntimeService';

AppStorageDefaults.register();

function initialRuntimeRoute(): AppRoute {
  const baseUrl = AppStorage.get<string>('haBaseUrl') ?? '';
  const accessToken = AppStorage.get<string>('haAccessToken') ?? '';
  if (baseUrl.trim().length > 0 && accessToken.trim().length > 0) {
    return AppRoute.DASHBOARD;
  }
  return AppRoute.WELCOME;
}

@Component
export struct AppRuntimeHost {
  backDispatcher: AppBackDispatcher | undefined = undefined;
  private firstAppearHandled: boolean = false;

  @StorageLink('haBaseUrl') haBaseUrl: string = '';
  @StorageLink('haAccessToken') haAccessToken: string = '';
  @StorageLink('haRefreshToken') haRefreshToken: string = '';
  @StorageLink('haWebhookId') haWebhookId: string = '';
  @StorageLink('haWebhookSecret') haWebhookSecret: string = '';
  @StorageLink('haCloudhookUrl') haCloudhookUrl: string = '';
  @StorageLink('haRemoteUiUrl') haRemoteUiUrl: string = '';
  @StorageLink('haMobileAppDeviceId') haMobileAppDeviceId: string = '';
  @StorageLink('serverNameOverride') @Watch('onAppSettingChanged') serverNameOverride: string = '';
  @StorageLink('serverExternalUrl') @Watch('onAppSettingChanged') serverExternalUrl: string = '';
  @StorageLink('serverInternalUrl') @Watch('onAppSettingChanged') serverInternalUrl: string = '';
  @StorageLink('homeNetworkName') @Watch('onAppSettingChanged') homeNetworkName: string = '';
  @StorageLink('trustServer') @Watch('onAppSettingChanged') trustServer: boolean = false;
  @StorageLink('appLockEnabled') @Watch('onAppSettingChanged') appLockEnabled: boolean = false;
  @StorageLink('appLockHomeBypass') @Watch('onAppSettingChanged') appLockHomeBypass: boolean = false;
  @StorageLink('sessionTimeout') @Watch('onAppSettingChanged') sessionTimeout: string = '0';
  @StorageLink('websocketMode') @Watch('onAppSettingChanged') websocketMode: string = 'system';
  @StorageLink('sensorBatterySOCEnabled') @Watch('onAppSettingChanged') sensorBatterySOCEnabled: boolean = false;
  @StorageLink('sensorChargingStatusEnabled') @Watch('onAppSettingChanged') sensorChargingStatusEnabled: boolean = false;
  @StorageLink('sensorPluggedTypeEnabled') @Watch('onAppSettingChanged') sensorPluggedTypeEnabled: boolean = false;
  @StorageLink('sensorBearerTypesEnabled') @Watch('onAppSettingChanged') sensorBearerTypesEnabled: boolean = false;
  @StorageLink('sensorLastUpdateTriggerEnabled') @Watch('onAppSettingChanged') sensorLastUpdateTriggerEnabled: boolean = false;
  @StorageLink('sensorLocationEnabled') @Watch('onAppSettingChanged') sensorLocationEnabled: boolean = false;
  @StorageLink('sensorZoneBackgroundEnabled') @Watch('onAppSettingChanged') sensorZoneBackgroundEnabled: boolean = false;
  @StorageLink('sensorAccurateLocationEnabled') @Watch('onAppSettingChanged') sensorAccurateLocationEnabled: boolean = false;
  @StorageLink('locationHistoryJson') @Watch('onAppSettingChanged') locationHistoryJson: string = '[]';
  @StorageLink('locationSentMode') @Watch('onAppSettingChanged') locationSentMode: string = 'never';
  @StorageLink('locationDiagnosticsJson') @Watch('onAppSettingChanged') locationDiagnosticsJson: string = '';
  @StorageLink('locationGeofenceStatus') @Watch('onAppSettingChanged') locationGeofenceStatus: string = 'not_started';
  @StorageLink('sensorDefaultMigrationVersion') @Watch('onAppSettingChanged') sensorDefaultMigrationVersion: number = 0;
  @StorageLink('sensorUpdateFrequency') @Watch('onAppSettingChanged') sensorUpdateFrequency: string = SensorUpdateFrequency.NORMAL;
  @StorageLink('fullScreenEnabled') @Watch('onAppSettingChanged') fullScreenEnabled: boolean = false;
  @StorageLink('screenOrientation') @Watch('onAppSettingChanged') screenOrientation: string = 'system';
  @StorageLink('keepScreenOnEnabled') @Watch('onAppSettingChanged') keepScreenOnEnabled: boolean = false;
  @StorageLink('pageZoomLevel') @Watch('onAppSettingChanged') pageZoomLevel: string = '100';
  @StorageLink('pinchToZoomEnabled') @Watch('onAppSettingChanged') pinchToZoomEnabled: boolean = false;
  @StorageLink('autoPlayVideoEnabled') @Watch('onAppSettingChanged') autoPlayVideoEnabled: boolean = false;
  @StorageLink('alwaysShowFirstViewOnAppStartEnabled') @Watch('onAppSettingChanged') alwaysShowFirstViewOnAppStartEnabled: boolean = false;
  @StorageLink('appLanguage') @Watch('onAppSettingChanged') appLanguage: string = 'default';
  @StorageLink('appTheme') @Watch('onAppSettingChanged') appTheme: string = 'light';
  @StorageLink('serviceCardUpdateFrequency') @Watch('onAppSettingChanged') serviceCardUpdateFrequency: string = 'default';
  @StorageLink('notificationUnreadCount') @Watch('onNotificationUnreadCountChanged') notificationUnreadCount: number = 0;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @StorageLink('gestureSwipeLeftTwoAction') @Watch('onAppSettingChanged') gestureSwipeLeftTwoAction: string = 'none';
  @StorageLink('gestureSwipeLeftThreeAction') @Watch('onAppSettingChanged') gestureSwipeLeftThreeAction: string = 'none';
  @StorageLink('gestureSwipeRightTwoAction') @Watch('onAppSettingChanged') gestureSwipeRightTwoAction: string = 'none';
  @StorageLink('gestureSwipeRightThreeAction') @Watch('onAppSettingChanged') gestureSwipeRightThreeAction: string = 'none';
  @StorageLink('gestureSwipeUpTwoAction') @Watch('onAppSettingChanged') gestureSwipeUpTwoAction: string = 'none';
  @StorageLink('gestureSwipeUpThreeAction') @Watch('onAppSettingChanged') gestureSwipeUpThreeAction: string = 'none';
  @StorageLink('gestureSwipeDownTwoAction') @Watch('onAppSettingChanged') gestureSwipeDownTwoAction: string = 'none';
  @StorageLink('gestureSwipeDownThreeAction') @Watch('onAppSettingChanged') gestureSwipeDownThreeAction: string = 'none';
  @StorageLink('appForegroundTick') @Watch('onAppForegroundTick') appForegroundTick: number = 0;
  @StorageLink('appBackgroundTick') @Watch('onAppBackgroundTick') appBackgroundTick: number = 0;
  @StorageLink('appConfigTick') @Watch('onAppConfigurationTick') appConfigTick: number = 0;

  @State @Watch('onStepChanged') step: number = initialRuntimeRoute();
  @State loading: boolean = false;
  @State discovering: boolean = false;
  @State message: string = Localization.t('app_ready');
  @State configSummary: string = Localization.t('common_not_set');
  @State serverOptions: ServerOption[] = [];
  @State selectedServerSettingsId: string = '';
  @State selectedServerSettingsName: string = '';
  @State selectedServerSettingsInfo: StoredServerInfo = StorageService.emptyServerInfo();
  @State selectedServerSettingsActive: boolean = true;

  @State manualAddress: string = '';
  @State deviceName: string = 'HarmonyOS Device';
  @StorageLink('secureConnectionChoice') @Watch('onAppSettingChanged') secureConnectionChoice: string = '';
  @State settingsDetailTitle: string = '';
  @State settingsDetailSummary: string = '';
  @State settingsDetailBody: string = '';
  @State settingsDetailStatus: string = '';
  @State settingsDetailAction: string = '';
  @State settingsDetailKey: string = '';
  @State settingsEditValue: string = '';
  @State settingsOptionValue: string = '';
  @State nativeFeatureBackTarget: number = AppRoute.COMPANION_SETTINGS;
  @State showDeleteServerDialog: boolean = false;
  @State deletingServer: boolean = false;
  @State showServerEditDialog: boolean = false;
  @State serverEditKey: string = '';
  @State serverEditTitle: string = '';
  @State serverEditValue: string = '';
  @State discoveredServers: HaServerItem[] = [];
  @State homeWifiSsids: string[] = [];
  @State homeSsidInput: string = '';
  @State dashboardInsecureBlocked: boolean = false;
  @State dashboardMissingHomeSetup: boolean = false;
  @State dashboardBlockedReason: string = '';
  @State prioritizeInternal: boolean = false;
  @State secureConnectionFromSettings: boolean = false;
  @State appLocked: boolean = false;
  @State appUnlocking: boolean = false;
  @State appLockAuthPending: boolean = false;

  @State showLoginWeb: boolean = false;
  @State authUrl: string = '';
  @State oauthState: string = '';
  @State handledAuthCode: string = '';
  @State dashboardUrl: string = '';
  @State dashboardLoadedUrl: string = '';
  @State dashboardCurrentUrl: string = '';
  @State nativeSettingsReturnUrl: string = '';
  @State dashboardBackToHomePending: boolean = false;
  @State dashboardBridgeReady: boolean = false;
  @State dashboardAuthProvided: boolean = false;
  @State preferredThemeDark: boolean = false;
  @State discoverySpinAngle: number = 0;
  @State discoveryPulseScale: number = 1;
  @State showDiscoveredSheet: boolean = false;
  @State onboardingBackTarget: number = AppRoute.WELCOME;
  @State addingServerFromSettings: boolean = false;
  private homeNetworkRefreshSeq: number = 0;
  @State viewportWidth: number = AppDeviceRuntimeService.defaultViewportWidth();
  @State viewportHeight: number = 0;
  @State settingsRevision: number = 0;
  @State companionSettingsScrollOffset: number = 0;
  @State serverSettingsScrollOffset: number = 0;
  @State showCompanionChoiceDialog: boolean = false;
  @State companionChoiceDialogKey: string = '';
  @State assistStartListeningSignal: number = 0;
  @State assistStartListeningRequested: boolean = false;
  discoveryAnimationToken: number = 0;
  discoveryAnimationRunning: boolean = false;
  discoverySheetPresented: boolean = false;
  addServerSnapshot: StoredServerInfo = StorageService.emptyServerInfo();
  private appLockIgnoreTransitionsUntil: number = 0;
  private restoringAppSettings: boolean = false;
  private systemEventService: SystemEventService = new SystemEventService();
  private sensorRuntimeService: SensorRuntimeService = new SensorRuntimeService();
  private mobileAppRegistrationInFlight: boolean = false;

  private webCtrl: web_webview.WebviewController = new web_webview.WebviewController();
  private externalAppProxy: ExternalAppProxy = new ExternalAppProxy(
    (payload: Object | string): void => {
      this.handleExternalGetAuth(payload);
    },
    (payload: Object | string): void => {
      this.handleExternalRevokeAuth(payload);
    },
    (payload: Object | string): void => {
      this.handleExternalBus(payload);
    }
  );

  initializeDeviceName(): void {
    if (this.deviceName.trim().length > 0 && this.deviceName !== 'HarmonyOS Device') { return; }
    const candidate = MobileAppRegistrationService.defaultDeviceName();
    if (candidate.length > 0) { this.deviceName = candidate; }
  }

  applySensorDefaultMigration(): void {
    if (this.sensorDefaultMigrationVersion >= 4) { return; }
    this.sensorDefaultMigrationVersion = 4;
  }

  sensorRuntimeSnapshot(): SensorRuntimeSnapshot {
    return {
      baseUrl: this.haBaseUrl,
      webhookId: this.haWebhookId,
      cloudhookUrl: this.haCloudhookUrl,
      registered: this.hasRegisteredCurrentDevice(),
      flags: SensorRuntimeBridgeService.flags(this),
      locationHistoryJson: this.locationHistoryJson,
      locationSentMode: this.locationSentMode,
      locationDiagnosticsJson: this.locationDiagnosticsJson,
      locationGeofenceStatus: this.locationGeofenceStatus
    };
  }

  subscribeBatteryEvents(onEvent: () => void): void { this.systemEventService.subscribeBatteryEvents(onEvent); }

  subscribeNetworkEvents(onEvent: () => void): void { this.systemEventService.subscribeNetworkEvents(onEvent); }

  registerBackDispatcher(handler: () => boolean): void { if (this.backDispatcher) { this.backDispatcher.register(handler); } }

  clearBackDispatcher(): void { if (this.backDispatcher) { this.backDispatcher.clear(); } }

  unsubscribeSystemEvents(): void { this.systemEventService.unsubscribeAll(); }

  stopSensorRuntime(): void { this.sensorRuntimeService.stop(); }

  resetSensorRuntime(): void { this.sensorRuntimeService.reset(); }

  resetAddServerSnapshot(): void { this.addServerSnapshot = StorageService.emptyServerInfo(); }

  context(): common.Context { return this.getUIContext().getHostContext() as common.Context; }

  private persistCurrentAppSettings(): void {
    if (this.restoringAppSettings) {
      return;
    }
    AppSettingsStore.saveCurrentAppStorage(this.context()).catch((): void => {});
  }

  private persistHomeNetworkSettings(): void {
    if (this.restoringAppSettings) {
      return;
    }
    AppSettingsStore.saveHomeNetwork(
      this.context(),
      this.homeWifiSsids,
      this.prioritizeInternal
    ).catch((): void => {});
  }

  private onAppSettingChanged(): void {
    if (this.restoringAppSettings) {
      return;
    }
    this.persistCurrentAppSettings();
    this.bumpSettingsRevision();
    this.refreshHomeNetworkStatus();
  }

  private onNotificationUnreadCountChanged(): void {
    this.bumpSettingsRevision();
  }

  async restoreInstanceAppSettingsState(): Promise<void> {
    this.restoringAppSettings = true;
    try {
      const context = this.context();
      await AppSettingsStore.restoreToAppStorage(context);
      const homeNetwork = await AppSettingsStore.loadHomeNetwork(context);
      this.homeWifiSsids = homeNetwork.wifiSsids;
      this.prioritizeInternal = homeNetwork.prioritizeInternal;
    } finally {
      this.restoringAppSettings = false;
    }
  }

  refreshHomeNetworkStatus(allowDashboardUrlReload: boolean = false): void {
    this.refreshHomeNetworkStatusNow('', allowDashboardUrlReload).catch((): void => {});
  }

  async refreshHomeNetworkStatusNow(
    currentUrlOverride: string = '',
    allowDashboardUrlReload: boolean = true
  ): Promise<void> {
    const seq = ++this.homeNetworkRefreshSeq;
    try {
      const snapshot = await NetworkService.wirelessSnapshot();
      if (seq !== this.homeNetworkRefreshSeq) {
        return;
      }
      const settings = this.currentHomeNetworkSettings();
      this.reconcileDashboardSecurity(snapshot, settings, currentUrlOverride, allowDashboardUrlReload);
    } catch (_) {
      if (seq !== this.homeNetworkRefreshSeq) {
        return;
      }
      const settings = this.currentHomeNetworkSettings();
      this.reconcileDashboardSecurity(
        HomeNetworkService.emptyWirelessSnapshot(),
        settings,
        currentUrlOverride,
        allowDashboardUrlReload
      );
    }
  }

  private currentHomeNetworkSettings(): HomeNetworkSettings {
    return {
      wifiSsids: this.homeWifiSsids,
      prioritizeInternal: this.prioritizeInternal
    };
  }

  private reconcileDashboardSecurity(
    snapshot: WirelessSnapshot,
    settings: HomeNetworkSettings,
    currentUrlOverride: string = '',
    allowDashboardUrlReload: boolean = true
  ): void {
    if (this.haAccessToken.trim().length === 0 || this.haBaseUrl.trim().length === 0) {
      this.clearDashboardSecurityBlock();
      return;
    }
    const currentUrl = currentUrlOverride.trim().length > 0 ? currentUrlOverride : this.currentDashboardUrl();
    const resolution: FrontendUrlResolution = HomeNetworkService.resolveFrontendUrl({
      externalUrl: this.serverExternalUrl.trim().length > 0 ? this.serverExternalUrl : this.haBaseUrl,
      internalUrl: this.serverInternalUrl,
      secureConnectionChoice: this.secureConnectionChoice,
      currentUrl: currentUrl,
      settings: settings,
      snapshot: snapshot
    });
    const wasBlocked = this.dashboardInsecureBlocked;
    if (resolution.kind === 'insecure_blocked') {
      this.dashboardInsecureBlocked = true;
      this.dashboardMissingHomeSetup = resolution.missingHomeSetup;
      this.dashboardBlockedReason = resolution.reason;
      this.dashboardBridgeReady = false;
      this.dashboardAuthProvided = false;
      try {
        this.webCtrl.loadUrl('about:blank');
      } catch (_) {
      }
      return;
    }
    this.dashboardInsecureBlocked = false;
    this.dashboardMissingHomeSetup = false;
    this.dashboardBlockedReason = '';
    if (resolution.kind === 'success' && resolution.url.length > 0 && this.dashboardUrl !== resolution.url) {
      const shouldReload = this.step === AppRoute.DASHBOARD &&
        (wasBlocked ||
          (allowDashboardUrlReload && this.shouldReloadForResolvedDashboardUrl(resolution.url, currentUrl)));
      if (shouldReload || this.dashboardUrl.trim().length === 0) {
        this.dashboardUrl = resolution.url;
        this.dashboardCurrentUrl = resolution.url;
        if (shouldReload || this.dashboardLoadedUrl.length === 0) {
          this.dashboardLoadedUrl = '';
        }
        this.dashboardBridgeReady = false;
        this.dashboardAuthProvided = false;
      } else if (UrlService.isHttpLikeUrl(currentUrl)) {
        this.dashboardCurrentUrl = currentUrl;
      }
      if (shouldReload) {
        this.forceLoadDashboard(resolution.url);
      }
    }
  }

  private shouldReloadForResolvedDashboardUrl(resolutionUrl: string, currentUrl: string): boolean {
    const targetUrl = resolutionUrl.trim();
    const activeUrl = currentUrl.trim();
    if (UrlService.isHttpLikeUrl(activeUrl) && UrlService.endpointKey(activeUrl) === UrlService.endpointKey(targetUrl)) {
      return false;
    }
    const knownDashboardUrl = this.dashboardUrl.trim();
    if (
      UrlService.isHttpLikeUrl(knownDashboardUrl) &&
      UrlService.endpointKey(knownDashboardUrl) === UrlService.endpointKey(targetUrl)
    ) {
      return false;
    }
    return true;
  }

  private clearDashboardSecurityBlock(): void {
    this.dashboardInsecureBlocked = false;
    this.dashboardMissingHomeSetup = false;
    this.dashboardBlockedReason = '';
  }

  setStep(route: AppRoute): void { this.step = route; }

  setMessage(message: string): void { this.message = message; }

  currentDashboardUrl(): string {
    try {
      const url = this.webCtrl.getUrl();
      if (url && UrlService.isHttpLikeUrl(url)) {
        this.rememberDashboardUrl(url);
        return url;
      }
    } catch (_) {
    }
    return this.dashboardCurrentUrl;
  }

  canDashboardGoBack(): boolean {
    try {
      return this.webCtrl.accessBackward();
    } catch (_) {
      return false;
    }
  }

  dashboardGoBack(): void {
    try { this.webCtrl.backward(); } catch (_) {}
  }

  aboutToAppear(): void {
    this.refreshServerOptions();
    if (this.firstAppearHandled) {
      this.refreshHomeNetworkStatus();
      return;
    }
    this.firstAppearHandled = true;
    this.restoreInstanceAppSettingsState()
      .then((): Promise<void> => this.refreshHomeNetworkStatusNow())
      .catch((): void => {})
      .finally((): void => {
        AppLifecycleRuntimeService.aboutToAppear(this, AppRuntimeCallbackFactory.lifecycle(this));
      });
  }

  aboutToDisappear(): void { AppLifecycleRuntimeService.aboutToDisappear(AppRuntimeCallbackFactory.lifecycle(this)); }

  startLocationSensorsIfNeeded(): void { this.sensorRuntimeService.startLocationSensorsIfNeeded(AppRuntimeCallbackFactory.sensors(this)); }

  reconcileBackgroundLocationPermission(): void {
    this.sensorRuntimeService.reconcileBackgroundLocationPermission(AppRuntimeCallbackFactory.sensors(this));
  }

  requestLocationPermissionAndEnable(reason: string, onFinished?: () => void): void {
    this.sensorRuntimeService.requestLocationPermissionAndEnable(reason, AppRuntimeCallbackFactory.sensors(this), onFinished);
  }

  stringifyError(err: Error | string | number | boolean | Object | ArrayBuffer): string {
    if (err instanceof Error) {
      return err.message ? `${err.name}: ${err.message}` : err.name;
    }
    try {
      return JSON.stringify(err);
    } catch (_) {
      return String(err);
    }
  }

  guardAndRewriteUrl(currentUrl: string): UrlGuardResult {
    const activeBaseUrl = this.step === AppRoute.DASHBOARD && this.dashboardUrl.trim().length > 0
      ? this.dashboardUrl
      : this.haBaseUrl;
    return UrlService.guardAndRewriteUrl(currentUrl, activeBaseUrl);
  }

  selectServer(url: string): void { DiscoveryFlowRuntimeService.selectServer(this, AppRuntimeCallbackFactory.discovery(this), url); }

  connectManualAddress(): void { DiscoveryFlowRuntimeService.connectManualAddress(this, AppRuntimeCallbackFactory.discovery(this)); }

  rememberDashboardUrl(url: string): void {
    if (!url || !UrlService.isHttpLikeUrl(url)) {
      return;
    }
    this.dashboardCurrentUrl = url;
  }

  rememberDashboardLoadedUrl(url: string): void {
    if (!url || !UrlService.isHttpLikeUrl(url)) {
      return;
    }
    this.dashboardLoadedUrl = url;
  }

  openAssistConversation(payload: Object | string): void {
    this.assistStartListeningRequested = ExternalBusService.booleanPayload(payload, 'start_listening', true);
    this.assistStartListeningSignal += 1;
    this.step = AppRoute.ASSIST_CONVERSATION;
  }
  openCompanionSettings(): void {
    this.settingsDetailTitle = '';
    this.settingsDetailSummary = '';
    this.settingsDetailBody = '';
    this.settingsDetailStatus = '';
    this.settingsDetailAction = '';
    this.settingsDetailKey = '';
    this.settingsEditValue = '';
    this.settingsOptionValue = '';
    this.showDeleteServerDialog = false;
    this.deletingServer = false;
    this.companionSettingsScrollOffset = 0;
    this.serverSettingsScrollOffset = 0;
    this.step = AppRoute.COMPANION_SETTINGS;
  }

  returnToHaSettingsPage(): void { this.dashboardBackToHomePending = false; this.step = 4; }

  returnToDashboardFromSettings(): void {
    this.dashboardBackToHomePending = false;
    this.nativeSettingsReturnUrl = '';
    this.secureConnectionFromSettings = false;
    this.showDeleteServerDialog = false;
    this.deletingServer = false;
    this.showServerEditDialog = false;
    const dashboardHomeUrl = UrlService.buildDashboardUrl(UrlService.normalizeBaseUrl(this.haBaseUrl));
    this.dashboardUrl = dashboardHomeUrl;
    this.dashboardLoadedUrl = '';
    this.dashboardCurrentUrl = dashboardHomeUrl;
    this.dashboardBridgeReady = false;
    this.dashboardAuthProvided = false;
    this.step = AppRoute.DASHBOARD;
    this.applyThemePreferences();
    this.applyWindowPreferences();
    this.applyDashboardPreferences();
    this.refreshHomeNetworkStatusNow(dashboardHomeUrl)
      .then((): void => {
        if (!this.dashboardInsecureBlocked) {
          this.forceLoadDashboard(this.dashboardUrl);
        }
      })
      .catch((): void => {
        if (!this.dashboardInsecureBlocked) {
          this.forceLoadDashboard(dashboardHomeUrl);
        }
      });
  }

  openServerSettings(): void {
    this.showDeleteServerDialog = false;
    this.deletingServer = false;
    this.showServerEditDialog = false;
    this.secureConnectionFromSettings = false;
    this.step = 12;
  }

  openSecureConnectionFromSettings(): void {
    this.showDeleteServerDialog = false;
    this.deletingServer = false;
    this.showServerEditDialog = false;
    this.secureConnectionFromSettings = false;
    this.openServerSettings();
    this.openCompanionChoiceDialog('server_connection_security');
  }

  openServerSettingsFor(serverId: string): void {
    ServerManager.listServers(this.context())
      .then((servers: ManagedServer[]): Promise<ManagedServer | undefined> => {
        return ServerManager.getActiveServer(this.context())
          .then((active: ManagedServer | undefined): ManagedServer | undefined => {
            const activeId = active ? active.id : '';
            this.serverOptions = this.serverOptionsFromServers(servers, activeId);
            const selected = servers.find((server: ManagedServer): boolean => server.id === serverId) ?? active;
            if (selected) {
              this.applySelectedServerSettings(selected, activeId);
              this.openServerSettings();
              this.refreshServerNameFromServer(selected.id, selected.info);
            }
            return selected;
          });
      })
      .catch((): void => {});
  }

  startAddServerFromSettings(): void { DiscoveryFlowRuntimeService.startAddServerFromSettings(this, AppRuntimeCallbackFactory.discovery(this)); }

  deleteCurrentServer(): void {
    ServerAccountRuntimeService.deleteCurrentServer(
      this,
      AppRuntimeCallbackFactory.serverAccount(this),
      {
        id: this.selectedServerSettingsId,
        info: this.selectedServerSettingsId.length > 0 ? this.selectedServerSettingsInfo : this.currentStoredServerInfo()
      }
    );
  }

  private handleExternalBus(payload: Object | string): void {
    if (ExternalBusService.type(payload) === 'harmony_url_changed') {
      const url = ExternalBusService.stringPayload(payload, 'url', '');
      this.rememberDashboardUrl(url);
      return;
    }
    ExternalAuthRuntimeService.handleExternalBus(payload, this, AppRuntimeCallbackFactory.externalAuth(this));
  }

  private handleExternalGetAuth(payload: Object | string): void { ExternalAuthRuntimeService.handleExternalGetAuth(payload, this, AppRuntimeCallbackFactory.externalAuth(this)); }

  private handleExternalRevokeAuth(payload: Object | string): void { ExternalAuthRuntimeService.handleExternalRevokeAuth(payload, this, AppRuntimeCallbackFactory.externalAuth(this)); }

  async refreshAccessToken(baseUrl: string): Promise<boolean> { return AuthFlowRuntimeService.refreshAccessToken(this, AppRuntimeCallbackFactory.authFlow(this), baseUrl); }

  private hasRegisteredCurrentDevice(): boolean { return RegistrationRuntimeService.hasRegisteredCurrentDevice(this); }

  completeDeviceRegistration(): void { RegistrationRuntimeService.completeDeviceRegistration(this, AppRuntimeCallbackFactory.registration(this)); }

  ensureMobileAppRegistration(reason: string): void {
    if (this.mobileAppRegistrationInFlight) {
      return;
    }
    if (!StorageService.hasLogin(this.currentStoredServerInfo()) || this.hasRegisteredCurrentDevice()) {
      return;
    }
    this.mobileAppRegistrationInFlight = true;
    this.resolveAllowedServerBaseUrl('', this.haBaseUrl)
      .then((baseUrl: string): Promise<boolean> => {
        if (baseUrl.length === 0) {
          return Promise.resolve(false);
        }
        return RegistrationRuntimeService.ensureCurrentDeviceRegistered(
          this,
          AppRuntimeCallbackFactory.registration(this),
          reason,
          baseUrl
        );
      })
      .catch((error: Error | string | number | boolean | Object | ArrayBuffer): void => {
        this.message = this.stringifyError(error);
      })
      .finally((): void => {
        this.mobileAppRegistrationInFlight = false;
      });
  }

  async fetchHaConfig(): Promise<void> {
    const connectionBaseUrl = await this.resolveAllowedServerBaseUrl('', this.haBaseUrl);
    if (StorageService.hasLogin(this.currentStoredServerInfo()) && connectionBaseUrl.length === 0) {
      return;
    }
    await AuthFlowRuntimeService.fetchHaConfig(this, AppRuntimeCallbackFactory.authFlow(this), connectionBaseUrl);
    this.persistActiveServerNameFromConfig();
  }

  startOfficialLogin(): void { AuthFlowRuntimeService.startOfficialLogin(this); }

  handleAuthRedirect(url: string): void { AuthFlowRuntimeService.handleAuthRedirect(this, AppRuntimeCallbackFactory.authFlow(this), url); }

  startDiscoveryFlow(backTarget: AppRoute = AppRoute.WELCOME): void { DiscoveryFlowRuntimeService.startFlow(this, AppRuntimeCallbackFactory.discovery(this), backTarget); }

  startDiscoveryAnimation(): void { DiscoveryFlowRuntimeService.startAnimation(this); }

  stopDiscoveryAnimation(): void { DiscoveryFlowRuntimeService.stopAnimation(this); }

  cancelAddServerFromSettings(): void {
    const snapshot = this.addServerSnapshot;
    DiscoveryFlowRuntimeService.cancelAddServerFromSettings(this, AppRuntimeCallbackFactory.discovery(this));
    if (!StorageService.hasLogin(snapshot)) {
      return;
    }
    const dashboardHomeUrl = UrlService.buildDashboardUrl(UrlService.normalizeBaseUrl(snapshot.baseUrl));
    this.dashboardUrl = dashboardHomeUrl;
    this.dashboardLoadedUrl = '';
    this.dashboardCurrentUrl = dashboardHomeUrl;
    this.dashboardBridgeReady = false;
    this.dashboardAuthProvided = false;
  }

  handleBackNavigation(): boolean { return AppNavigationRuntimeService.handleBackNavigation(this, AppRuntimeCallbackFactory.navigation(this)); }

  onBackPress(): boolean { return this.handleBackNavigation(); }

  moveAbilityToBackground(): void {
    try {
      const abilityContext = this.context() as common.UIAbilityContext;
      abilityContext.moveAbilityToBackground().catch((): void => {});
    } catch (_) {
    }
  }

  openDashboard(): void {
    this.ensureMobileAppRegistration('dashboard_opened');
    this.dashboardBackToHomePending = false;
    this.nativeSettingsReturnUrl = '';
    DashboardRuntimeService.openDashboard(this, AppRuntimeCallbackFactory.dashboard(this));
    this.refreshHomeNetworkStatus();
  }

  private unlockApp(): void {
    AppLockUnlockRuntimeService.unlock(
      this.context(),
      this,
      (): void => this.ignoreAppLockTransitions()
    );
  }

  setDiscoverySheetVisible(visible: boolean): void {
    this.showDiscoveredSheet = visible;
  }

  applyActiveTheme(): void {
    this.appResolvedDark = this.preferredThemeDark;
  }

  private refreshResolvedTheme(): void {
    AppWindowRuntimeService.refreshResolvedTheme(this.context(), this);
  }

  applyThemePreferences(): void {
    AppWindowRuntimeService.applyThemePreferences(this.context(), this);
  }

  installFrontendUrlObserver(): void {
    DashboardRuntimeService.installFrontendUrlObserver(this.webCtrl, this);
  }

  applyDashboardPreferences(): void {
    DashboardRuntimeService.applyDashboardPreferences(this.webCtrl, this);
  }

  refreshDashboardTheme(): void {
    DashboardRuntimeService.refreshDashboardTheme(this.webCtrl, this);
  }

  prewarmDiscovery(): void {
    DiscoveryCacheService.warm(this.context());
  }

  private onStepChanged(): void {
    this.applyWindowPreferences();
    if (this.step === AppRoute.DASHBOARD) {
      this.syncPublicSensors('dashboard_opened');
    } else if (this.step === AppRoute.SENSOR_SETTINGS) {
      this.refreshCurrentLocationForDiagnostics('sensor_settings_opened');
    }
  }

  isWebControllerMounted(): boolean { return DashboardRuntimeService.isWebControllerMounted(this); }

  tryRunWebScript(
    script: string,
    onResolve?: (raw: Object | string | number | ArrayBuffer) => void
  ): void {
    DashboardRuntimeService.runScript(this.webCtrl, script, onResolve);
  }

  tryLoadWebUrl(url: string): void { DashboardRuntimeService.loadUrl(this.webCtrl, url); }

  private forceLoadDashboard(url: string): void {
    const targetUrl = url.trim();
    if (targetUrl.length === 0) {
      return;
    }
    this.dashboardLoadedUrl = '';
    setTimeout((): void => {
      if (this.step === AppRoute.DASHBOARD && this.dashboardUrl === targetUrl) {
        this.tryLoadWebUrl(targetUrl);
      }
    }, 0);
    setTimeout((): void => {
      if (this.step === AppRoute.DASHBOARD && this.dashboardUrl === targetUrl) {
        this.tryLoadWebUrl(targetUrl);
      }
    }, 250);
  }

  maybeResetDashboardToFirstView(): void { DashboardRuntimeService.maybeResetDashboardToFirstView(this.webCtrl, this); }

  retryDashboardSecurity(): void {
    this.refreshHomeNetworkStatus();
  }

  openDashboardSecuritySettings(): void {
    this.openServerSettings();
  }

  changeDashboardSecurityLevel(): void {
    this.openSecureConnectionFromSettings();
  }

  configureDashboardHomeNetwork(): void {
    this.openServerSettings();
  }

  applyWindowPreferences(): void {
    AppWindowRuntimeService.applyPreferencesForState(this.context(), this);
  }

  private resetLoginState(): void {
    AppSessionRuntimeService.resetLoginState(
      this.context(),
      this,
      (): void => this.syncCardServerConnection(),
      (): void => this.applyActiveTheme(),
      (): void => this.stopDiscoveryAnimation()
    );
  }

  onboardingContentMaxWidth(): number { return AppDeviceRuntimeService.onboardingContentMaxWidth(this); }

  private updateViewportSize(width: Length, height: Length): void { AppDeviceRuntimeService.updateViewportSize(this, width, height); }

  currentDeviceProfile(): DeviceProfileInfo { return AppDeviceRuntimeService.profile(this); }

  settingsContentMaxWidth(): number { return AppDeviceRuntimeService.settingsContentMaxWidth(this); }

  private isWearableProfile(): boolean { return AppDeviceRuntimeService.isWearableProfile(this); }

  private isSignedIn(): boolean { return AppSessionRuntimeService.hasLogin(this); }

  shouldLockApp(): boolean { return AppLockRuntimeService.shouldLock(this.appLockEnabled, this.isSignedIn()); }

  bumpSettingsRevision(): void { this.settingsRevision += 1; }

  ignoreAppLockTransitions(durationMs: number = 8000): void { this.appLockIgnoreTransitionsUntil = Date.now() + durationMs; }

  isIgnoringAppLockTransitions(): boolean { return this.appLockAuthPending || this.appUnlocking || Date.now() < this.appLockIgnoreTransitionsUntil; }

  private onAppForegroundTick(): void { AppLifecycleRuntimeService.onForeground(this, AppRuntimeCallbackFactory.lifecycle(this)); }

  private onAppBackgroundTick(): void { AppLifecycleRuntimeService.onBackground(this, AppRuntimeCallbackFactory.lifecycle(this)); }

  private onAppConfigurationTick(): void { AppLifecycleRuntimeService.onConfiguration(this, AppRuntimeCallbackFactory.lifecycle(this)); }

  currentStoredServerInfo(): StoredServerInfo { return AppSessionRuntimeService.currentStoredServerInfo(this); }

  currentSettingsServerInfo(): StoredServerInfo {
    if (this.selectedServerSettingsId.length > 0) {
      return this.selectedServerSettingsInfo;
    }
    return this.currentStoredServerInfo();
  }

  private async resolveAllowedServerBaseUrl(serverId: string, fallbackBaseUrl: string): Promise<string> {
    const context = this.context();
    let targetId = serverId.trim();
    if (targetId.length === 0) {
      targetId = ServerManager.getActiveServerIdSync(context);
    }
    if (targetId.length === 0 && fallbackBaseUrl.trim().length > 0) {
      targetId = ServerManager.findServerIdByBaseUrlSync(context, fallbackBaseUrl);
    }
    if (targetId.length === 0) {
      return UrlService.normalizeBaseUrl(fallbackBaseUrl);
    }
    const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, targetId);
    return policy.allowed ? policy.baseUrl : '';
  }

  applySettingsServerInfo(info: StoredServerInfo): void {
    if (this.selectedServerSettingsId.length === 0) {
      this.applyStoredServerInfo(info);
      return;
    }
    this.selectedServerSettingsInfo = info;
    if (this.selectedServerSettingsActive) {
      AppSessionRuntimeService.applyServerInfoToState(this, info);
      ServerManager.applyActiveToAppStorage(info);
    }
    ServerManager.updateServerInfo(this.context(), this.selectedServerSettingsId, info)
      .then((): void => {
        this.refreshServerOptions();
      })
      .catch((): void => {});
  }

  updateSettingsServerName(name: string, info: StoredServerInfo): void {
    const value = name.trim();
    if (value.length === 0 || this.selectedServerSettingsId.length === 0) {
      return;
    }
    this.selectedServerSettingsName = value;
    ServerManager.updateServerName(this.context(), this.selectedServerSettingsId, value)
      .then((): void => {
        this.refreshServerOptions();
      })
      .catch((): void => {});
  }

  syncSettingsServerNameToHomeAssistant(name: string, info: StoredServerInfo): void {
    const value = name.trim();
    if (value.length === 0 || !StorageService.hasLogin(info)) {
      return;
    }
    this.resolveAllowedServerBaseUrl(this.selectedServerSettingsId, info.baseUrl)
      .then((baseUrl: string): Promise<void> => {
        if (baseUrl.length === 0) {
          return Promise.resolve();
        }
        return HaApiService.updateCoreLocationName(baseUrl, info.accessToken, value);
      })
      .then((): void => {
        this.message = Localization.t('server_name_synced');
        if (this.selectedServerSettingsId.length > 0) {
          this.refreshServerNameFromServer(this.selectedServerSettingsId, info);
        } else {
          this.fetchHaConfig().catch((): void => {});
        }
      })
      .catch((err: Error): void => {
        this.message = Localization.format('server_name_sync_failed', 'error', this.stringifyError(err));
      });
  }

  applyStoredServerInfo(info: StoredServerInfo): void {
    if (this.addingServerFromSettings) {
      AppSessionRuntimeService.applyServerInfoToState(this, info);
      ServerManager.applyActiveToAppStorage(info);
      if (StorageService.hasLogin(info) && info.accessToken !== this.addServerSnapshot.accessToken) {
        ServerManager.addServerAndActivate(this.context(), info)
          .then(async (): Promise<void> => {
            await this.fetchHaConfig().catch((): void => {});
            this.syncCardServerConnection();
            this.refreshServerOptions();
          })
          .catch((): void => {});
      }
      return;
    }
    AppSessionRuntimeService.applyStoredServerInfo(
      this.context(),
      this,
      info,
      (): void => {
        this.syncCardServerConnection();
        this.refreshServerOptions();
      }
    );
  }

  refreshServerOptions(): void {
    ServerManager.listServers(this.context())
      .then((servers: ManagedServer[]): Promise<ManagedServer | undefined> => {
        return ServerManager.getActiveServer(this.context())
          .then((active: ManagedServer | undefined): ManagedServer | undefined => {
            const activeId = active ? active.id : '';
            this.serverOptions = this.serverOptionsFromServers(servers, activeId);
            if (this.selectedServerSettingsId.length > 0) {
              const selected = servers.find((server: ManagedServer): boolean => server.id === this.selectedServerSettingsId);
              if (selected) {
                this.applySelectedServerSettings(selected, activeId);
              }
            } else if (active) {
              this.applySelectedServerSettings(active, activeId);
            }
            this.bumpSettingsRevision();
            return active;
          });
      })
      .catch((): void => {});
  }

  private serverOptionsFromServers(servers: ManagedServer[], activeId: string): ServerOption[] {
    return servers.map((server: ManagedServer): ServerOption => {
      if (this.shouldRefreshManagedServerName(server)) {
        this.refreshServerNameFromServer(server.id, server.info);
      }
      return {
        id: server.id,
        name: this.managedServerDisplayName(server),
        summary: this.serverDeviceSummary(server.info),
        active: server.id === activeId
      };
    });
  }

  private applySelectedServerSettings(server: ManagedServer, activeId: string): void {
    this.selectedServerSettingsId = server.id;
    this.selectedServerSettingsName = this.managedServerDisplayName(server);
    this.selectedServerSettingsInfo = server.info;
    this.selectedServerSettingsActive = server.id === activeId;
  }

  private managedServerDisplayName(server: ManagedServer): string {
    const name = server.name.trim();
    if (name.length > 0 && !this.isGeneratedServerName(name, server.info)) {
      return name;
    }
    return 'Home Assistant';
  }

  private shouldRefreshManagedServerName(server: ManagedServer): boolean {
    return StorageService.hasLogin(server.info) && this.isGeneratedServerName(server.name, server.info);
  }

  private isGeneratedServerName(name: string, info: StoredServerInfo): boolean {
    const value = name.trim().replace(/\/+$/, '');
    if (value.length === 0) {
      return true;
    }
    return value === info.baseUrl.trim().replace(/\/+$/, '');
  }

  private serverDeviceSummary(info: StoredServerInfo): string {
    const savedDeviceName = info.deviceName.trim();
    if (savedDeviceName.length > 0) {
      return savedDeviceName;
    }
    const currentDeviceName = this.deviceName.trim();
    if (currentDeviceName.length > 0 && currentDeviceName !== 'HarmonyOS Device') {
      return currentDeviceName;
    }
    return MobileAppRegistrationService.defaultDeviceName();
  }

  private persistActiveServerNameFromConfig(): void {
    const name = SettingsSummaryService.serverDisplayName('', this.configSummary).trim();
    if (name.length === 0 || name === Localization.t('common_not_set')) {
      return;
    }
    this.serverNameOverride = '';
    ServerManager.updateActiveServerName(this.context(), name)
      .then((): void => {
        this.refreshServerOptions();
      })
      .catch((): void => {});
  }

  private serverNameFromConfigSummary(summary: string): string {
    if (summary.indexOf('|') < 0) {
      return '';
    }
    const name = SettingsSummaryService.serverDisplayName('', summary).trim();
    return name === Localization.t('common_not_set') ? '' : name;
  }

  private refreshServerNameFromServer(serverId: string, info: StoredServerInfo): void {
    if (serverId.length === 0 || !StorageService.hasLogin(info)) {
      return;
    }
    this.resolveAllowedServerBaseUrl(serverId, info.baseUrl)
      .then((baseUrl: string) => {
        if (baseUrl.length === 0) {
          return Promise.reject(new Error('blocked_by_connection_policy'));
        }
        return AuthRuntimeService.fetchConfigWithRefresh(baseUrl, info.accessToken, info.refreshToken);
      })
      .then(async (result): Promise<void> => {
        let latestInfo: StoredServerInfo = info;
        if (result.refreshed && result.accessToken.length > 0) {
          latestInfo = StorageService.applyRefresh(info, result.accessToken, result.refreshToken, result.accessTokenExpiresAt);
          await ServerManager.updateServerInfo(this.context(), serverId, latestInfo);
        }
        const name = this.serverNameFromConfigSummary(result.summary);
        if (name.length === 0) {
          return;
        }
        await ServerManager.updateServerName(this.context(), serverId, name);
        if (this.selectedServerSettingsId === serverId) {
          this.selectedServerSettingsName = name;
          this.selectedServerSettingsInfo = latestInfo;
        }
        this.refreshServerOptions();
      })
      .catch((): void => {});
  }

  switchServer(serverId: string): void {
    const context = this.context();
    AppSettingsStore.saveCurrentAppStorage(context)
      .then((): Promise<StoredServerInfo> => ServerManager.activateServer(context, serverId))
      .then(async (info: StoredServerInfo): Promise<StoredServerInfo> => {
        await this.restoreInstanceAppSettingsState();
        return info;
      })
      .then((info: StoredServerInfo): void => {
        if (!StorageService.hasLogin(info)) {
          return;
        }
        this.applyStoredServerInfo(info);
        this.configSummary = Localization.t('common_not_set');
        const nextDashboardUrl = UrlService.buildDashboardUrl(info.baseUrl);
        this.dashboardUrl = nextDashboardUrl;
        this.dashboardLoadedUrl = '';
        this.dashboardCurrentUrl = nextDashboardUrl;
        this.dashboardBridgeReady = false;
        this.dashboardAuthProvided = false;
        this.nativeSettingsReturnUrl = '';
        this.dashboardBackToHomePending = false;
        this.applyThemePreferences();
        this.applyWindowPreferences();
        this.applyDashboardPreferences();
        this.resetSensorRuntime();
        this.syncPublicSensors('server_switched');
        this.selectedServerSettingsId = serverId;
        this.selectedServerSettingsInfo = info;
        this.selectedServerSettingsName = SettingsSummaryService.serverDisplayName('', info.baseUrl);
        this.selectedServerSettingsActive = true;
        this.refreshServerOptions();
        this.fetchHaConfig().catch((): void => {});
        this.openDashboard();
        this.forceLoadDashboard(nextDashboardUrl);
      })
      .catch((err: Error): void => {
        this.message = err.message;
      });
  }

  private openSelectedServerDashboard(): void {
    const baseUrl = this.selectedServerSettingsInfo.baseUrl.trim().length > 0
      ? this.selectedServerSettingsInfo.baseUrl
      : this.haBaseUrl;
    const normalized = UrlService.normalizeBaseUrl(baseUrl);
    if (!normalized) {
      return;
    }
    const nextDashboardUrl = UrlService.buildDashboardUrl(normalized);
    this.dashboardUrl = nextDashboardUrl;
    this.dashboardLoadedUrl = '';
    this.dashboardCurrentUrl = nextDashboardUrl;
    this.dashboardBridgeReady = false;
    this.dashboardAuthProvided = false;
    this.nativeSettingsReturnUrl = '';
    this.dashboardBackToHomePending = false;
    this.applyDashboardPreferences();
    this.openDashboard();
    this.forceLoadDashboard(nextDashboardUrl);
  }

  private activateSelectedServerOrRefresh(): void {
    if (this.selectedServerSettingsId.length === 0) {
      return;
    }
    const context = this.context();
    const activeId = ServerManager.getActiveServerIdSync(context);
    if (activeId === this.selectedServerSettingsId) {
      AppSettingsStore.saveCurrentAppStorage(context)
        .then((): void => this.openSelectedServerDashboard())
        .catch((): void => this.openSelectedServerDashboard());
      return;
    }
    this.switchServer(this.selectedServerSettingsId);
  }

  syncCardServerConnection(): void {
    CardFormService.refreshRegisteredForms(this.context()).catch((): void => {});
  }

  openCompanionChoiceDialog(key: string): void {
    SettingsChoiceRuntimeService.openDialog(this, key);
    this.bumpSettingsRevision();
  }

  closeCompanionChoiceDialog(): void {
    SettingsChoiceRuntimeService.closeDialog(this);
    this.bumpSettingsRevision();
  }

  selectCompanionChoice(value: string): void { SettingsChoiceRuntimeService.selectCompanionChoice(this, AppRuntimeCallbackFactory.settingsChoice(this), value); }

  selectSettingsDetailChoice(key: string, value: string): void { SettingsChoiceRuntimeService.selectSettingsDetailChoice(this, AppRuntimeCallbackFactory.settingsChoice(this), key, value); }

  applySensorFlags(flags: SensorRuntimeFlags): void {
    SensorRuntimeBridgeService.applyFlags(this, flags);
    AppSettingsStore.saveSensorFlags(this.context(), flags).catch((): void => {});
  }

  setLocationHistoryJsonValue(value: string): void { this.locationHistoryJson = value; }

  setLocationSentModeValue(value: string): void {
    this.locationSentMode = value;
    AppSettingsStore.saveLocationSentMode(this.context(), value).catch((): void => {});
  }

  setLocationDiagnosticsJsonValue(value: string): void { this.locationDiagnosticsJson = value; }

  setLocationGeofenceStatusValue(value: string): void { this.locationGeofenceStatus = value; }

  refreshLocationZones(syncAfterRefresh: boolean): void { this.sensorRuntimeService.refreshLocationZones(syncAfterRefresh, AppRuntimeCallbackFactory.sensors(this)); }

  refreshCurrentLocationForDiagnostics(trigger: string): void {
    this.sensorRuntimeService.refreshCurrentLocationForDiagnostics(trigger, AppRuntimeCallbackFactory.sensors(this));
  }

  syncPublicSensors(reason: string): void { this.sensorRuntimeService.syncPublicSensors(reason, AppRuntimeCallbackFactory.sensors(this)); }

  toggleSensor(sensorId: string): void {
    SensorRuntimeBridgeService.toggleSensor(
      this.sensorRuntimeService,
      this,
      sensorId,
      AppRuntimeCallbackFactory.sensors(this),
      (): void => {
        this.bumpSettingsRevision();
        this.syncPublicSensors('sensor_preferences_changed');
      }
    );
  }

  overlaySensorGroups(): SensorGroup[] { return SensorRuntimeBridgeService.sensorGroups(this.sensorRuntimeService, this); }

  openAssistSettings(): void { this.step = 13; }

  handleSettingsAction(actionId: string): void {
    if (actionId.startsWith('open_server_detail:')) {
      this.openServerSettingsFor(actionId.substring('open_server_detail:'.length));
      return;
    }
    if (actionId === 'activate_server') {
      this.activateSelectedServerOrRefresh();
      return;
    }
    if (actionId === 'server_name') {
      if (this.selectedServerSettingsId.length > 0) {
        this.refreshServerNameFromServer(this.selectedServerSettingsId, this.selectedServerSettingsInfo);
      } else {
        this.fetchHaConfig().catch((): void => {});
      }
      return;
    }
    if (actionId.startsWith('switch_server:')) {
      this.switchServer(actionId.substring('switch_server:'.length));
      return;
    }
    SettingsInteractionRuntimeService.handleSettingsAction(actionId, this, AppRuntimeCallbackFactory.settingsInteraction(this));
  }

  private isCompanionSettingsFlowVisible(): boolean {
    return SettingsRouteService.isCompanionSettingsFlowVisible(
      this.step,
      this.settingsDetailKey,
      this.nativeFeatureBackTarget
    );
  }

  build() {
    AppRuntimeShellHost({
      appLocked: this.appLocked,
      wearableProfile: this.isWearableProfile(),
      route: this.step,
      companionSettingsFlowVisible: this.isCompanionSettingsFlowVisible(),
      dark: this.appResolvedDark,
      appUnlocking: this.appUnlocking,
      wearSignedIn: this.isSignedIn(),
      wearServerName: SettingsSummaryService.serverDisplayName('', this.configSummary),
      wearServerUrl: this.haBaseUrl,
      onboardingSnapshot: AppOnboardingRuntimeService.snapshot(this),
      onboardingActions: AppOnboardingRuntimeService.actions(this),
      settingsSnapshot: AppSettingsRuntimeService.snapshot(this),
      settingsActions: AppSettingsRuntimeService.actions(this),
      overlaySnapshot: AppRuntimeOverlayService.snapshot(this),
      overlayActions: AppRuntimeOverlayService.actions(this),
      webSnapshot: AppWebRuntimeService.snapshot(this),
      webActions: AppWebRuntimeService.actions(this),
      webController: this.webCtrl,
      externalAppProxy: this.externalAppProxy,
      onViewportAreaChange: (width: Length, height: Length): void => this.updateViewportSize(width, height),
      onBackGesture: (): void => {
        if (!this.handleBackNavigation()) {
          this.moveAbilityToBackground();
        }
      },
      onUnlock: (): void => this.unlockApp(),
      onWearMessage: (message: string): void => {
        this.message = message;
      },
      onWearSwipeBack: (): void => {
        this.handleBackNavigation();
      },
      isNativeOnboardingStep: (): boolean => AppRoutePolicy.isNativeOnboardingStep(this.step),
    })
  }

}


