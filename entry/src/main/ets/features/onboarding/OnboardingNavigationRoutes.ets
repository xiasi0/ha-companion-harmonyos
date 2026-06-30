import { AppRoute } from '../../app/AppRoute';
import { HaServerItem } from '../../models/HaServerItem';
import { UrlService } from '../../services/UrlService';
import { Localization } from '../../shared/i18n/Localization';
import { DiscoveryPage } from './DiscoveryPage';
import { HomeNetworkPage } from './HomeNetworkPage';
import { LocalFirstPage } from './LocalFirstPage';
import { LocationSharingPage } from './LocationSharingPage';
import { ManualServerPage } from './ManualServerPage';
import { NameDevicePage } from './NameDevicePage';
import { OnboardingConnectionErrorPage } from './OnboardingConnectionErrorPage';
import { OnboardingRuntimeActions, OnboardingRuntimeSnapshot } from './OnboardingRuntimeModels';
import { SecureConnectionPage } from './SecureConnectionPage';

export const ONBOARDING_NAV_DISCOVERY: string = 'CompanionOnboardingDiscovery';
export const ONBOARDING_NAV_MANUAL_SERVER: string = 'CompanionOnboardingManualServer';
export const ONBOARDING_NAV_CONNECTION_ERROR: string = 'CompanionOnboardingConnectionError';
export const ONBOARDING_NAV_NAME_DEVICE: string = 'CompanionOnboardingNameDevice';
export const ONBOARDING_NAV_LOCAL_FIRST: string = 'CompanionOnboardingLocalFirst';
export const ONBOARDING_NAV_LOCATION_SHARING: string = 'CompanionOnboardingLocationSharing';
export const ONBOARDING_NAV_SECURE_CONNECTION: string = 'CompanionOnboardingSecureConnection';
export const ONBOARDING_NAV_HOME_NETWORK: string = 'CompanionOnboardingHomeNetwork';

const DEFAULT_ONBOARDING_SNAPSHOT: OnboardingRuntimeSnapshot = {
  step: AppRoute.WELCOME,
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
  secureConnectionFromSettings: false,
  connectionErrorUrl: '',
  connectionErrorCode: 0,
  connectionErrorDetail: '',
  connectionError: undefined
};

const DEFAULT_ONBOARDING_ACTIONS: OnboardingRuntimeActions = {
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
  onClearSecureConnectionFromSettings: () => {},
  onRetryConnectionError: () => {}
};

export function onboardingRouteName(step: number): string {
  if (step === AppRoute.DISCOVERY) {
    return ONBOARDING_NAV_DISCOVERY;
  }
  if (step === AppRoute.MANUAL_SERVER) {
    return ONBOARDING_NAV_MANUAL_SERVER;
  }
  if (step === AppRoute.CONNECTION_ERROR) {
    return ONBOARDING_NAV_CONNECTION_ERROR;
  }
  if (step === AppRoute.NAME_DEVICE) {
    return ONBOARDING_NAV_NAME_DEVICE;
  }
  if (step === AppRoute.LOCAL_FIRST) {
    return ONBOARDING_NAV_LOCAL_FIRST;
  }
  if (step === AppRoute.LOCATION_SHARING) {
    return ONBOARDING_NAV_LOCATION_SHARING;
  }
  if (step === AppRoute.SECURE_CONNECTION) {
    return ONBOARDING_NAV_SECURE_CONNECTION;
  }
  if (step === AppRoute.HOME_NETWORK) {
    return ONBOARDING_NAV_HOME_NETWORK;
  }
  return '';
}

export function onboardingStepDepth(step: number): number {
  if (step === AppRoute.WELCOME) {
    return 0;
  }
  if (step === AppRoute.DISCOVERY) {
    return 1;
  }
  if (step === AppRoute.MANUAL_SERVER) {
    return 2;
  }
  if (step === AppRoute.CONNECTION_ERROR) {
    return 3;
  }
  if (step === AppRoute.NAME_DEVICE) {
    return 3;
  }
  if (step === AppRoute.LOCAL_FIRST) {
    return 4;
  }
  if (step === AppRoute.LOCATION_SHARING) {
    return 5;
  }
  if (step === AppRoute.SECURE_CONNECTION) {
    return 6;
  }
  if (step === AppRoute.HOME_NETWORK) {
    return 7;
  }
  return -1;
}

export function isOnboardingNavigationStep(step: number): boolean {
  return onboardingStepDepth(step) >= 0;
}

@Builder
export function CompanionOnboardingDiscoveryBuilder(): void {
  CompanionOnboardingDiscoveryRoute()
}

@Builder
export function CompanionOnboardingManualServerBuilder(): void {
  CompanionOnboardingManualServerRoute()
}

@Builder
export function CompanionOnboardingConnectionErrorBuilder(): void {
  CompanionOnboardingConnectionErrorRoute()
}

@Builder
export function CompanionOnboardingNameDeviceBuilder(): void {
  CompanionOnboardingNameDeviceRoute()
}

@Builder
export function CompanionOnboardingLocalFirstBuilder(): void {
  CompanionOnboardingLocalFirstRoute()
}

@Builder
export function CompanionOnboardingLocationSharingBuilder(): void {
  CompanionOnboardingLocationSharingRoute()
}

@Builder
export function CompanionOnboardingSecureConnectionBuilder(): void {
  CompanionOnboardingSecureConnectionRoute()
}

@Builder
export function CompanionOnboardingHomeNetworkBuilder(): void {
  CompanionOnboardingHomeNetworkRoute()
}

@Component
struct CompanionOnboardingDiscoveryRoute {
  @Consume('onboardingRuntimeSnapshot') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Consume('onboardingRuntimeActions') actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;

  build() {
    NavDestination() {
      DiscoveryPage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        discoveredServers: this.snapshot.discoveredServers,
        showDiscoveredSheet: this.snapshot.showDiscoveredSheet,
        discoverySpinAngle: this.snapshot.discoverySpinAngle,
        discoveryPulseScale: this.snapshot.discoveryPulseScale,
        onBack: this.actions.onHandleBackNavigation,
        onHelp: (): void => this.actions.onSetMessage(Localization.t('docs_home_assistant_help')),
        onManualInput: (): void => {
          this.actions.onSetDiscoverySheetVisible(false);
          this.actions.onSetStep(AppRoute.MANUAL_SERVER);
          this.actions.onSetMessage(Localization.t('manual_server_enter_address'));
        },
        onSelectServer: this.actions.onSelectServer,
        onCloseSheet: (): void => this.actions.onSetDiscoverySheetVisible(false),
        onStartAnimation: (): void => {
          if (this.snapshot.step === AppRoute.DISCOVERY) {
            this.actions.onStartDiscoveryAnimation();
          }
        },
        onStopAnimation: this.actions.onStopDiscoveryAnimation,
        onSwipeBack: this.actions.onHandleBackNavigation
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.actions.onHandleBackNavigation();
      return true;
    })
  }
}

@Component
struct CompanionOnboardingManualServerRoute {
  @Consume('onboardingRuntimeSnapshot') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Consume('onboardingRuntimeActions') actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;

  build() {
    NavDestination() {
      ManualServerPage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        manualAddress: this.snapshot.manualAddress,
        addressInvalid: this.snapshot.manualAddress.trim().length > 0 &&
          UrlService.normalizeBaseUrl(this.snapshot.manualAddress).length === 0,
        onBack: this.actions.onHandleBackNavigation,
        onHelp: (): void => this.actions.onSetMessage(Localization.t('docs_home_assistant_help')),
        onAddressChange: this.actions.onManualAddressChange,
        onConnect: this.actions.onManualConnect,
        onSwipeBack: this.actions.onHandleBackNavigation
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.actions.onHandleBackNavigation();
      return true;
    })
  }
}

@Component
struct CompanionOnboardingConnectionErrorRoute {
  @Consume('onboardingRuntimeSnapshot') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Consume('onboardingRuntimeActions') actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;

  build() {
    NavDestination() {
      OnboardingConnectionErrorPage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        error: this.snapshot.connectionError,
        onBack: this.actions.onHandleBackNavigation,
        onHelp: (): void => this.actions.onSetMessage(Localization.t('connection_error_help')),
        onRetry: this.actions.onRetryConnectionError
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.actions.onHandleBackNavigation();
      return true;
    })
  }
}

@Component
struct CompanionOnboardingNameDeviceRoute {
  @Consume('onboardingRuntimeSnapshot') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Consume('onboardingRuntimeActions') actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;

  build() {
    NavDestination() {
      NameDevicePage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        deviceName: this.snapshot.deviceName,
        onBack: this.actions.onHandleBackNavigation,
        onHelp: (): void => this.actions.onSetMessage(Localization.t('docs_home_assistant_help')),
        onDeviceNameChange: this.actions.onDeviceNameChange,
        onContinue: this.actions.onCompleteDeviceRegistration
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.actions.onHandleBackNavigation();
      return true;
    })
  }
}

@Component
struct CompanionOnboardingLocalFirstRoute {
  @Consume('onboardingRuntimeSnapshot') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Consume('onboardingRuntimeActions') actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;

  build() {
    NavDestination() {
      LocalFirstPage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        onBack: this.actions.onHandleBackNavigation,
        onHelp: (): void => this.actions.onSetMessage(Localization.t('docs_home_assistant_help')),
        onContinue: (): void => this.actions.onSetStep(AppRoute.LOCATION_SHARING)
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.actions.onHandleBackNavigation();
      return true;
    })
  }
}

@Component
struct CompanionOnboardingLocationSharingRoute {
  @Consume('onboardingRuntimeSnapshot') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Consume('onboardingRuntimeActions') actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;

  build() {
    NavDestination() {
      LocationSharingPage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        onBack: this.actions.onHandleBackNavigation,
        onHelp: (): void => this.actions.onSetMessage(Localization.t('docs_home_assistant_help')),
        onShareLocation: (): void => {
          this.actions.onRequestLocationAndEnable((): void => this.actions.onSetStep(AppRoute.SECURE_CONNECTION));
        },
        onSkipLocation: (): void => this.actions.onSetStep(AppRoute.SECURE_CONNECTION)
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.actions.onHandleBackNavigation();
      return true;
    })
  }
}

@Component
struct CompanionOnboardingSecureConnectionRoute {
  @Consume('onboardingRuntimeSnapshot') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Consume('onboardingRuntimeActions') actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;

  private handleBack(): void {
    if (this.snapshot.secureConnectionFromSettings) {
      this.actions.onClearSecureConnectionFromSettings();
      this.actions.onSetStep(AppRoute.SERVER_SETTINGS);
    } else {
      this.actions.onHandleBackNavigation();
    }
  }

  private handleContinue(): void {
    if (this.snapshot.secureConnectionFromSettings) {
      this.actions.onClearSecureConnectionFromSettings();
      this.actions.onSetStep(AppRoute.SERVER_SETTINGS);
      return;
    }
    if (this.snapshot.secureConnectionChoice === 'most') {
      this.actions.onSetStep(AppRoute.HOME_NETWORK);
      return;
    }
    this.actions.onOpenDashboard();
  }

  build() {
    NavDestination() {
      SecureConnectionPage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        haBaseUrl: this.snapshot.haBaseUrl,
        secureConnectionChoice: this.snapshot.secureConnectionChoice,
        onBack: (): void => this.handleBack(),
        onHelp: (): void => this.actions.onSetMessage(Localization.t('docs_home_assistant_help')),
        onChoiceChange: this.actions.onSecureChoiceChange,
        onContinue: (): void => this.handleContinue()
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.handleBack();
      return true;
    })
  }
}

@Component
struct CompanionOnboardingHomeNetworkRoute {
  @Consume('onboardingRuntimeSnapshot') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Consume('onboardingRuntimeActions') actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;

  build() {
    NavDestination() {
      HomeNetworkPage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        homeNetworkName: this.snapshot.homeNetworkName,
        onBack: this.actions.onHandleBackNavigation,
        onHelp: (): void => this.actions.onSetMessage(Localization.t('docs_home_assistant_help')),
        onHomeNetworkNameChange: this.actions.onHomeNetworkNameChange,
        onContinue: this.actions.onOpenDashboard
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.actions.onHandleBackNavigation();
      return true;
    })
  }
}
