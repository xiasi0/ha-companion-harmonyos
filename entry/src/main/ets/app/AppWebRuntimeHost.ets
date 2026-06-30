import web_webview from '@ohos.web.webview';
import { UrlGuardResult } from '../models/UrlGuardResult';
import { UrlService } from '../services/UrlService';
import { LoginWebPage } from '../features/auth/LoginWebPage';
import { AuthRuntimeService } from '../features/auth/AuthRuntimeService';
import { DashboardPage } from '../features/dashboard/DashboardPage';
import { DashboardInsecureBlockPage } from '../features/dashboard/DashboardInsecureBlockPage';
import { ExternalAppProxy } from '../features/dashboard/ExternalAppProxy';
import { DashboardConnectionErrorDialog } from '../features/dashboard/DashboardConnectionErrorDialog';
import { AppRoute } from './AppRoute';

@Component
export struct AppWebRuntimeHost {
  @Prop route: number = AppRoute.DASHBOARD;
  @Prop baseUrl: string = '';
  @Prop authUrl: string = '';
  @Prop loading: boolean = false;
  @Prop showLoginWeb: boolean = false;
  @Prop dashboardUrl: string = '';
  @Prop dashboardLoadedUrl: string = '';
  @Prop dashboardInsecureBlocked: boolean = false;
  @Prop dashboardMissingHomeSetup: boolean = false;
  @Prop dashboardBlockedReason: string = '';
  @Prop dashboardConnectionErrorVisible: boolean = false;
  @Prop dashboardAuthProvided: boolean = false;
  @Prop pageZoomLevel: string = '100';
  @Prop pinchToZoomEnabled: boolean = false;
  @Prop autoPlayVideoEnabled: boolean = false;
  @Prop appTheme: string = 'system';
  @Prop dark: boolean = false;

  controller: web_webview.WebviewController = new web_webview.WebviewController();
  externalAppProxy: ExternalAppProxy = new ExternalAppProxy(() => {}, () => {}, () => {});
  onLoadingChange: (loading: boolean) => void = () => {};
  onUrlGuard: (url: string) => UrlGuardResult = () => {
    return {
      intercept: false,
      rewrittenUrl: ''
    };
  };
  onLoadUrl: (url: string) => void = () => {};
  onAuthRedirect: (url: string) => void = () => {};
  onSwipeBack: () => void = () => {};
  onDashboardBridgeReady: () => void = () => {};
  onDashboardPageReady: () => void = () => {};
  onRememberDashboardUrl: (url: string) => void = () => {};
  onDashboardLoadedUrlChange: (url: string) => void = () => {};
  onDashboardConnectionError: () => void = () => {};
  onDashboardConnectionLoadStarted: () => void = () => {};
  onWaitDashboardConnection: () => void = () => {};
  onRetryDashboardConnection: () => void = () => {};
  onRetryDashboardSecurity: () => void = () => {};
  onOpenDashboardSecuritySettings: () => void = () => {};
  onChangeDashboardSecurityLevel: () => void = () => {};
  onConfigureDashboardHomeNetwork: () => void = () => {};
  onMessage: (message: string) => void = () => {};

  build() {
    if (this.route === AppRoute.LOGIN) {
      LoginWebPage({
        showLoginWeb: this.showLoginWeb,
        authUrl: this.authUrl,
        loading: this.loading,
        appResolvedDark: this.dark,
        redirectPrefix: AuthRuntimeService.appRedirectUri(UrlService.normalizeBaseUrl(this.baseUrl)),
        controller: this.controller,
        onLoadingChange: this.onLoadingChange,
        onUrlGuard: this.onUrlGuard,
        onLoadUrl: this.onLoadUrl,
        onAuthRedirect: this.onAuthRedirect,
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.dashboardInsecureBlocked) {
      DashboardInsecureBlockPage({
        missingHomeSetup: this.dashboardMissingHomeSetup,
        reason: this.dashboardBlockedReason,
        dark: this.dark,
        onRetry: this.onRetryDashboardSecurity,
        onOpenSettings: this.onOpenDashboardSecuritySettings,
        onChangeSecurityLevel: this.onChangeDashboardSecurityLevel,
        onConfigureHomeNetwork: this.onConfigureDashboardHomeNetwork
      })
    } else {
      Stack() {
        DashboardPage({
          dashboardUrl: this.dashboardUrl,
          loadedDashboardUrl: this.dashboardLoadedUrl,
          isActiveDashboard: this.route === AppRoute.DASHBOARD,
          dashboardAuthProvided: this.dashboardAuthProvided,
          pageZoomLevel: this.pageZoomLevel,
          pinchToZoomEnabled: this.pinchToZoomEnabled,
          autoPlayVideoEnabled: this.autoPlayVideoEnabled,
          appTheme: this.appTheme,
          isDarkTheme: this.dark,
          controller: this.controller,
          externalAppProxy: this.externalAppProxy,
          onBridgeReady: this.onDashboardBridgeReady,
          onPageReady: this.onDashboardPageReady,
          onRememberUrl: this.onRememberDashboardUrl,
          onLoadedUrlChange: this.onDashboardLoadedUrlChange,
          onConnectionError: this.onDashboardConnectionError,
          onConnectionLoadStarted: this.onDashboardConnectionLoadStarted,
          onMessage: this.onMessage,
          onUrlGuard: this.onUrlGuard
        })
        if (this.dashboardConnectionErrorVisible) {
          DashboardConnectionErrorDialog({
            onWait: this.onWaitDashboardConnection,
            onRefreshExternal: this.onRetryDashboardConnection,
            onOpenSettings: this.onOpenDashboardSecuritySettings
          })
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}
