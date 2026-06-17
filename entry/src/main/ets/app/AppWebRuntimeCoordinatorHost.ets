import web_webview from '@ohos.web.webview';
import { ExternalAppProxy } from '../features/dashboard/ExternalAppProxy';
import { AppWebRuntimeHost } from './AppWebRuntimeHost';
import { AppWebRuntimeActions, AppWebRuntimeSnapshot } from './AppWebRuntimeModels';
import { AppRoute } from './AppRoute';

const DEFAULT_WEB_RUNTIME_SNAPSHOT: AppWebRuntimeSnapshot = {
  route: AppRoute.DASHBOARD,
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
  appTheme: 'system',
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

@Component
export struct AppWebRuntimeCoordinatorHost {
  @Prop snapshot: AppWebRuntimeSnapshot = DEFAULT_WEB_RUNTIME_SNAPSHOT;
  actions: AppWebRuntimeActions = DEFAULT_WEB_RUNTIME_ACTIONS;
  controller: web_webview.WebviewController = new web_webview.WebviewController();
  externalAppProxy: ExternalAppProxy = new ExternalAppProxy(() => {}, () => {}, () => {});

  build() {
    AppWebRuntimeHost({
      route: this.snapshot.route,
      baseUrl: this.snapshot.baseUrl,
      showLoginWeb: this.snapshot.showLoginWeb,
      authUrl: this.snapshot.authUrl,
      loading: this.snapshot.loading,
      dashboardUrl: this.snapshot.dashboardUrl,
      dashboardLoadedUrl: this.snapshot.dashboardLoadedUrl,
      dashboardInsecureBlocked: this.snapshot.dashboardInsecureBlocked,
      dashboardMissingHomeSetup: this.snapshot.dashboardMissingHomeSetup,
      dashboardBlockedReason: this.snapshot.dashboardBlockedReason,
      dashboardAuthProvided: this.snapshot.dashboardAuthProvided,
      pageZoomLevel: this.snapshot.pageZoomLevel,
      pinchToZoomEnabled: this.snapshot.pinchToZoomEnabled,
      autoPlayVideoEnabled: this.snapshot.autoPlayVideoEnabled,
      appTheme: this.snapshot.appTheme,
      dark: this.snapshot.dark,
      controller: this.controller,
      externalAppProxy: this.externalAppProxy,
      onLoadingChange: this.actions.onLoadingChange,
      onUrlGuard: this.actions.onUrlGuard,
      onLoadUrl: this.actions.onLoadUrl,
      onAuthRedirect: this.actions.onAuthRedirect,
      onSwipeBack: this.actions.onSwipeBack,
      onDashboardBridgeReady: this.actions.onDashboardBridgeReady,
      onDashboardPageReady: this.actions.onDashboardPageReady,
      onRememberDashboardUrl: this.actions.onRememberDashboardUrl,
      onDashboardLoadedUrlChange: this.actions.onDashboardLoadedUrlChange,
      onRetryDashboardSecurity: this.actions.onRetryDashboardSecurity,
      onOpenDashboardSecuritySettings: this.actions.onOpenDashboardSecuritySettings,
      onChangeDashboardSecurityLevel: this.actions.onChangeDashboardSecurityLevel,
      onConfigureDashboardHomeNetwork: this.actions.onConfigureDashboardHomeNetwork,
      onMessage: this.actions.onMessage
    })
  }
}
