import { AppRoute } from '../../app/AppRoute';
import { AppWebRuntimeActions, AppWebRuntimeSnapshot } from '../../app/AppWebRuntimeModels';
import common from '@ohos.app.ability.common';
import web_webview from '@ohos.web.webview';
import { ExternalAppProxy } from '../dashboard/ExternalAppProxy';
import { AppPromptService } from '../../shared/services/AppPromptService';
import { WelcomePage } from './WelcomePage';
import {
  isOnboardingNavigationStep,
  onboardingRouteName,
  onboardingStepDepth
} from './OnboardingNavigationRoutes';
import { OnboardingRuntimeActions, OnboardingRuntimeSnapshot } from './OnboardingRuntimeModels';

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
  connectionErrorDetail: ''
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

const DEFAULT_WEB_RUNTIME_SNAPSHOT: AppWebRuntimeSnapshot = {
  route: AppRoute.LOGIN,
  baseUrl: '',
  showLoginWeb: false,
  authUrl: '',
  loading: false,
  dashboardUrl: '',
  dashboardLoadedUrl: '',
  dashboardAuthProvided: false,
  dashboardInsecureBlocked: false,
  dashboardMissingHomeSetup: false,
  dashboardBlockedReason: '',
  pageZoomLevel: '100',
  pinchToZoomEnabled: false,
  autoPlayVideoEnabled: false,
  appTheme: 'light',
  dark: false
};

const DEFAULT_WEB_RUNTIME_ACTIONS: AppWebRuntimeActions = {
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

const PATH_STACK_SYNC_DELAY_MS: number = 50;
const PRIVACY_POLICY_URL: string = 'https://www.home-assistant.io/privacy/';

@Component
export struct OnboardingAppRuntimeHost {
  @Prop @Watch('onRuntimeChanged') snapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Prop webSnapshot: AppWebRuntimeSnapshot = DEFAULT_WEB_RUNTIME_SNAPSHOT;
  actions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;
  webActions: AppWebRuntimeActions = DEFAULT_WEB_RUNTIME_ACTIONS;
  webController: web_webview.WebviewController = new web_webview.WebviewController();
  externalAppProxy: ExternalAppProxy = new ExternalAppProxy(() => {}, () => {}, () => {});
  @Provide('onboardingRuntimeSnapshot') providedSnapshot: OnboardingRuntimeSnapshot = DEFAULT_ONBOARDING_SNAPSHOT;
  @Provide('onboardingRuntimeActions') providedActions: OnboardingRuntimeActions = DEFAULT_ONBOARDING_ACTIONS;
  @Provide('onboardingWebRuntimeSnapshot') providedWebSnapshot: AppWebRuntimeSnapshot = DEFAULT_WEB_RUNTIME_SNAPSHOT;
  @Provide('onboardingWebRuntimeActions') providedWebActions: AppWebRuntimeActions = DEFAULT_WEB_RUNTIME_ACTIONS;
  @Provide('onboardingWebController') providedWebController: web_webview.WebviewController = new web_webview.WebviewController();
  @Provide('onboardingExternalAppProxy') providedExternalAppProxy: ExternalAppProxy = new ExternalAppProxy(() => {}, () => {}, () => {});
  @Provide('onboardingPathStack') pathStack: NavPathStack = new NavPathStack();
  private syncedStep: number = AppRoute.WELCOME;

  aboutToAppear(): void {
    this.refreshProvidedRuntime();
    this.syncedStep = AppRoute.WELCOME;
    this.schedulePathStackSync(false);
  }

  aboutToRender(): void {
    this.refreshProvidedRuntime();
  }

  private onRuntimeChanged(): void {
    this.refreshProvidedRuntime();
    this.schedulePathStackSync(true);
  }

  private refreshProvidedRuntime(): void {
    this.providedSnapshot = this.snapshot;
    this.providedActions = this.actions;
    this.providedWebSnapshot = this.webSnapshot;
    this.providedWebActions = this.webActions;
    this.providedWebController = this.webController;
    this.providedExternalAppProxy = this.externalAppProxy;
  }

  private popToRoot(animated: boolean): void {
    while (this.pathStack.size() > 0) {
      this.pathStack.pop(animated);
    }
  }

  private syncPathStack(animated: boolean): void {
    const targetStep = this.snapshot.step;
    if (!isOnboardingNavigationStep(targetStep) || targetStep === this.syncedStep) {
      return;
    }
    const targetDepth = onboardingStepDepth(targetStep);
    const currentDepth = onboardingStepDepth(this.syncedStep);
    const routeName = onboardingRouteName(targetStep);

    if (targetStep === AppRoute.WELCOME) {
      this.popToRoot(animated);
    } else if (targetDepth === currentDepth - 1) {
      this.pathStack.pop(animated);
    } else if (targetDepth === currentDepth + 1 && routeName.length > 0) {
      this.pathStack.pushPath({ name: routeName }, animated);
    } else {
      this.popToRoot(false);
      if (routeName.length > 0) {
        this.pathStack.pushPath({ name: routeName }, animated);
      }
    }
    this.syncedStep = targetStep;
  }

  private schedulePathStackSync(animated: boolean): void {
    setTimeout((): void => {
      this.syncPathStack(animated);
    }, PATH_STACK_SYNC_DELAY_MS);
  }

  private openPrivacyPolicy(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({
      action: 'ohos.want.action.viewData',
      uri: PRIVACY_POLICY_URL
    }).catch((): void => {
      AppPromptService.showInfo(this.getUIContext(), PRIVACY_POLICY_URL);
    });
  }

  build() {
    Navigation(this.pathStack) {
      WelcomePage({
        contentMaxWidth: this.snapshot.contentMaxWidth,
        onConnect: this.actions.onStartDiscoveryFlow,
        onLearnMore: (): void => AppPromptService.showLearnMoreUnavailable(this.getUIContext()),
        onPrivacyPolicy: (): void => this.openPrivacyPolicy()
      })
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
  }
}
