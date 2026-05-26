import { UrlGuardResult } from '../models/UrlGuardResult';
import { AppWebRuntimeActions, AppWebRuntimeSnapshot } from './AppWebRuntimeModels';

export interface AppWebRuntimeState {
  step: number;
  haBaseUrl: string;
  showLoginWeb: boolean;
  authUrl: string;
  loading: boolean;
  dashboardUrl: string;
  dashboardLoadedUrl: string;
  dashboardInsecureBlocked: boolean;
  dashboardMissingHomeSetup: boolean;
  dashboardBlockedReason: string;
  dashboardAuthProvided: boolean;
  pageZoomLevel: string;
  pinchToZoomEnabled: boolean;
  autoPlayVideoEnabled: boolean;
  appTheme: string;
  appResolvedDark: boolean;
}

export interface AppWebRuntimeActionTarget {
  loading: boolean;
  dashboardBridgeReady: boolean;
  message: string;
  guardAndRewriteUrl(url: string): UrlGuardResult;
  tryLoadWebUrl(url: string): void;
  handleAuthRedirect(url: string): void;
  handleBackNavigation(): boolean;
  applyDashboardPreferences(): void;
  installFrontendUrlObserver(): void;
  clearPendingDashboardHistory(): void;
  rememberDashboardUrl(url: string): void;
  rememberDashboardLoadedUrl(url: string): void;
  retryDashboardSecurity(): void;
  openDashboardSecuritySettings(): void;
  changeDashboardSecurityLevel(): void;
  configureDashboardHomeNetwork(): void;
}

export class AppWebRuntimeService {
  static snapshot(state: AppWebRuntimeState): AppWebRuntimeSnapshot {
    return {
      route: state.step,
      baseUrl: state.haBaseUrl,
      showLoginWeb: state.showLoginWeb,
      authUrl: state.authUrl,
      loading: state.loading,
      dashboardUrl: state.dashboardUrl,
      dashboardLoadedUrl: state.dashboardLoadedUrl,
      dashboardInsecureBlocked: state.dashboardInsecureBlocked,
      dashboardMissingHomeSetup: state.dashboardMissingHomeSetup,
      dashboardBlockedReason: state.dashboardBlockedReason,
      dashboardAuthProvided: state.dashboardAuthProvided,
      pageZoomLevel: state.pageZoomLevel,
      pinchToZoomEnabled: state.pinchToZoomEnabled,
      autoPlayVideoEnabled: state.autoPlayVideoEnabled,
      appTheme: state.appTheme,
      dark: state.appResolvedDark
    };
  }

  static actions(target: AppWebRuntimeActionTarget): AppWebRuntimeActions {
    return {
      onLoadingChange: (loading: boolean): void => {
        target.loading = loading;
      },
      onUrlGuard: (url: string): UrlGuardResult => target.guardAndRewriteUrl(url),
      onLoadUrl: (url: string): void => target.tryLoadWebUrl(url),
      onAuthRedirect: (url: string): void => target.handleAuthRedirect(url),
      onSwipeBack: (): void => {
        target.handleBackNavigation();
      },
      onDashboardBridgeReady: (): void => {
        target.dashboardBridgeReady = true;
      },
      onDashboardPageReady: (): void => {
        target.applyDashboardPreferences();
        target.installFrontendUrlObserver();
        target.clearPendingDashboardHistory();
      },
      onRememberDashboardUrl: (url: string): void => target.rememberDashboardUrl(url),
      onDashboardLoadedUrlChange: (url: string): void => target.rememberDashboardLoadedUrl(url),
      onRetryDashboardSecurity: (): void => target.retryDashboardSecurity(),
      onOpenDashboardSecuritySettings: (): void => target.openDashboardSecuritySettings(),
      onChangeDashboardSecurityLevel: (): void => target.changeDashboardSecurityLevel(),
      onConfigureDashboardHomeNetwork: (): void => target.configureDashboardHomeNetwork(),
      onMessage: (message: string): void => {
        target.message = message;
      }
    };
  }
}
