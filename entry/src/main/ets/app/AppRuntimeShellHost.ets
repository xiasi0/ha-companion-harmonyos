import web_webview from '@ohos.web.webview';
import { DeviceFormFactor, DeviceProfileInfo, DisplaySizeClass } from '../shared/device/DeviceProfile';
import { ExternalAppProxy } from '../features/dashboard/ExternalAppProxy';
import { WearRuntimeHost } from '../features/wear/WearRuntimeHost';
import { AppLockRuntimeHost } from '../features/security/AppLockRuntimeHost';
import { OnboardingAppRuntimeHost } from '../features/onboarding/OnboardingAppRuntimeHost';
import { OnboardingRuntimeActions, OnboardingRuntimeSnapshot } from '../features/onboarding/OnboardingRuntimeModels';
import { SecureConnectionPage } from '../features/onboarding/SecureConnectionPage';
import { SettingsRuntimeCoordinatorHost } from '../features/settings/SettingsRuntimeCoordinatorHost';
import { SettingsRuntimeActions, SettingsRuntimeSnapshot } from '../features/settings/SettingsRuntimeCoordinatorModels';
import { AppRuntimeOverlaysHost } from './AppRuntimeOverlaysHost';
import { AppRuntimeOverlayActions, AppRuntimeOverlaySnapshot } from './AppRuntimeOverlayModels';
import { AppWebRuntimeCoordinatorHost } from './AppWebRuntimeCoordinatorHost';
import { AppWebRuntimeActions, AppWebRuntimeSnapshot } from './AppWebRuntimeModels';
import { AppRuntimeScaffold } from './AppRuntimeScaffold';
import { Localization } from '../shared/i18n/Localization';

class EmptyDeviceProfileInfo implements DeviceProfileInfo {
  widthVp: number = 0;
  heightVp: number = 0;
  formFactor: DeviceFormFactor = DeviceFormFactor.PHONE;
  sizeClass: DisplaySizeClass = DisplaySizeClass.COMPACT;
  contentMaxWidth: number = 0;
  settingsMaxWidth: number = 0;
}

const EMPTY_ONBOARDING_SNAPSHOT: OnboardingRuntimeSnapshot = {
  step: 0,
  contentMaxWidth: 720,
  discoveredServers: [],
  showDiscoveredSheet: false,
  discoverySpinAngle: 0,
  discoveryPulseScale: 1,
  manualAddress: '',
  deviceName: '',
  haBaseUrl: '',
  secureConnectionChoice: '',
  homeNetworkName: '',
  secureConnectionFromSettings: false
};

const EMPTY_ONBOARDING_ACTIONS: OnboardingRuntimeActions = {
  onSetStep: () => {},
  onSetMessage: () => {},
  onSetDiscoverySheetVisible: () => {},
  onStartDiscoveryFlow: () => {},
  onHandleBackNavigation: () => {},
  onSelectServer: () => {},
  onStartDiscoveryAnimation: () => {},
  onStopDiscoveryAnimation: () => {},
  onManualAddressChange: () => {},
  onManualConnect: () => {},
  onDeviceNameChange: () => {},
  onCompleteDeviceRegistration: () => {},
  onRequestLocationAndEnable: () => {},
  onSecureChoiceChange: () => {},
  onOpenDashboard: () => {},
  onHomeNetworkNameChange: () => {},
  onClearSecureConnectionFromSettings: () => {}
};

const EMPTY_SETTINGS_SNAPSHOT: SettingsRuntimeSnapshot = {
  route: 0,
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

const EMPTY_SETTINGS_ACTIONS: SettingsRuntimeActions = {
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

const EMPTY_OVERLAY_SNAPSHOT: AppRuntimeOverlaySnapshot = {
  route: 0,
  baseUrl: '',
  accessToken: '',
  refreshToken: '',
  assistStartListeningSignal: 0,
  assistStartListeningRequested: false,
  profile: new EmptyDeviceProfileInfo(),
  sensorGroups: [],
  sensorUpdateFrequency: 'normal',
  contentMaxWidth: 720,
  switchRevision: 0
};

const EMPTY_OVERLAY_ACTIONS: AppRuntimeOverlayActions = {
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

const EMPTY_WEB_SNAPSHOT: AppWebRuntimeSnapshot = {
  route: 0,
  baseUrl: '',
  showLoginWeb: false,
  authUrl: '',
  loading: false,
  dashboardUrl: '',
  dashboardLoadedUrl: '',
  dashboardInsecureBlocked: false,
  dashboardMissingHomeSetup: false,
  dashboardBlockedReason: '',
  dashboardAuthProvided: false,
  pageZoomLevel: '100',
  pinchToZoomEnabled: false,
  autoPlayVideoEnabled: false,
  appTheme: 'light',
  dark: false
};

const EMPTY_WEB_ACTIONS: AppWebRuntimeActions = {
  onLoadingChange: () => {},
  onUrlGuard: () => ({ intercept: false, rewrittenUrl: '' }),
  onLoadUrl: () => {},
  onAuthRedirect: () => {},
  onSwipeBack: () => {},
  onDashboardBridgeReady: () => {},
  onDashboardPageReady: () => {},
  onRememberDashboardUrl: () => {},
  onDashboardLoadedUrlChange: () => {},
  onRetryDashboardSecurity: () => {},
  onOpenDashboardSecuritySettings: () => {},
  onChangeDashboardSecurityLevel: () => {},
  onConfigureDashboardHomeNetwork: () => {},
  onMessage: () => {}
};

@Component
export struct AppRuntimeShellHost {
  @Prop appLocked: boolean = false;
  @Prop wearableProfile: boolean = false;
  @Prop route: number = 0;
  @Prop companionSettingsFlowVisible: boolean = false;
  @Prop dark: boolean = false;
  @Prop appUnlocking: boolean = false;
  @Prop wearSignedIn: boolean = false;
  @Prop wearServerName: string = '';
  @Prop wearServerUrl: string = '';

  @Prop onboardingSnapshot: OnboardingRuntimeSnapshot = EMPTY_ONBOARDING_SNAPSHOT;
  onboardingActions: OnboardingRuntimeActions = EMPTY_ONBOARDING_ACTIONS;
  @Prop settingsSnapshot: SettingsRuntimeSnapshot = EMPTY_SETTINGS_SNAPSHOT;
  settingsActions: SettingsRuntimeActions = EMPTY_SETTINGS_ACTIONS;
  @Prop overlaySnapshot: AppRuntimeOverlaySnapshot = EMPTY_OVERLAY_SNAPSHOT;
  overlayActions: AppRuntimeOverlayActions = EMPTY_OVERLAY_ACTIONS;
  @Prop webSnapshot: AppWebRuntimeSnapshot = EMPTY_WEB_SNAPSHOT;
  webActions: AppWebRuntimeActions = EMPTY_WEB_ACTIONS;
  webController: web_webview.WebviewController = new web_webview.WebviewController();
  externalAppProxy: ExternalAppProxy = new ExternalAppProxy(() => {}, () => {}, () => {});
  onViewportAreaChange: (width: Length, height: Length) => void = () => {};
  onBackGesture: () => void = () => {};
  onUnlock: () => void = () => {};
  onWearMessage: (message: string) => void = () => {};
  onWearSwipeBack: () => void = () => {};
  isNativeOnboardingStep: () => boolean = () => false;

  @Builder
  private renderOnboardingFlow(): void {
    OnboardingAppRuntimeHost({
      snapshot: this.onboardingSnapshot,
      webSnapshot: this.webSnapshot,
      actions: this.onboardingActions,
      webActions: this.webActions,
      webController: this.webController,
      externalAppProxy: this.externalAppProxy
    })
  }

  @Builder
  private renderSettingsSecureConnection(): void {
    SecureConnectionPage({
      contentMaxWidth: this.onboardingSnapshot.contentMaxWidth,
      haBaseUrl: this.onboardingSnapshot.haBaseUrl,
      secureConnectionChoice: this.onboardingSnapshot.secureConnectionChoice,
      onBack: (): void => this.closeSettingsSecureConnection(),
      onHelp: (): void => this.onboardingActions.onSetMessage(Localization.t('docs_home_assistant_help')),
      onChoiceChange: this.onboardingActions.onSecureChoiceChange,
      onContinue: (): void => this.closeSettingsSecureConnection()
    })
  }

  private closeSettingsSecureConnection(): void {
    this.onboardingActions.onClearSecureConnectionFromSettings();
  }

  @Builder
  private renderWearHome(): void {
    WearRuntimeHost({
      isSignedIn: this.wearSignedIn,
      serverName: this.wearServerName,
      serverUrl: this.wearServerUrl,
      onMessage: this.onWearMessage,
      onSwipeBack: this.onWearSwipeBack
    })
  }

  @Builder
  private renderSettingsRuntime(): void {
    SettingsRuntimeCoordinatorHost({
      snapshot: this.settingsSnapshot,
      overlaySnapshot: this.overlaySnapshot,
      route: this.settingsSnapshot.route,
      detailKey: this.settingsSnapshot.detailKey,
      switchRevision: this.settingsSnapshot.switchRevision,
      actions: this.settingsActions,
      overlayActions: this.overlayActions
    })
  }

  @Builder
  private renderRuntimeOverlays(): void {
    AppRuntimeOverlaysHost({
      snapshot: this.overlaySnapshot,
      route: this.overlaySnapshot.route,
      actions: this.overlayActions
    })
  }

  @Builder
  private renderAppLock(): void {
    AppLockRuntimeHost({
      unlocking: this.appUnlocking,
      dark: this.dark,
      onUnlock: this.onUnlock
    })
  }

  @Builder
  private renderWebRuntime(): void {
    AppWebRuntimeCoordinatorHost({
      snapshot: this.webSnapshot,
      actions: this.webActions,
      controller: this.webController,
      externalAppProxy: this.externalAppProxy
    })
  }

  build() {
    AppRuntimeScaffold({
      appLocked: this.appLocked,
      wearableProfile: this.wearableProfile,
      route: this.route,
      companionSettingsFlowVisible: this.companionSettingsFlowVisible,
      secureConnectionFromSettings: this.onboardingSnapshot.secureConnectionFromSettings,
      dark: this.dark,
      onViewportAreaChange: this.onViewportAreaChange,
      onBackGesture: this.onBackGesture,
      isNativeOnboardingStep: this.isNativeOnboardingStep,
      renderAppLock: (): void => this.renderAppLock(),
      renderWearHome: (): void => this.renderWearHome(),
      renderLoggedIn: (): void => this.renderWebRuntime(),
      renderOnboardingFlow: (): void => this.renderOnboardingFlow(),
      renderLoginWeb: (): void => this.renderWebRuntime(),
      renderCompanionSettings: (): void => this.renderSettingsRuntime(),
      renderSettingsDetail: (): void => this.renderSettingsRuntime(),
      renderServerSettings: (): void => this.renderSettingsRuntime(),
      renderSettingsSecureConnection: (): void => this.renderSettingsSecureConnection(),
      renderRuntimeOverlays: (): void => this.renderRuntimeOverlays()
    })
  }
}
