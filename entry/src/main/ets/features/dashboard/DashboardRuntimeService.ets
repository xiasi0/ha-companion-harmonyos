// Runtime actions for the embedded Home Assistant dashboard WebView.
// Navigation, reload, external auth, and dashboard lifecycle behavior should flow through this layer.
import web_webview from '@ohos.web.webview';
import { AppRoute } from '../../app/AppRoute';
import { AppNavigator } from '../../app/AppNavigator';
import { UrlService } from '../../services/UrlService';
import { DashboardWebControllerTools } from './DashboardWebControllerTools';

export interface DashboardRuntimeState {
  showLoginWeb: boolean;
  authUrl: string;
  dashboardUrl: string;
  dashboardCurrentUrl: string;
  dashboardClearHistoryPending: boolean;
  dashboardAuthProvided: boolean;
  pageZoomLevel: string;
  alwaysShowFirstViewOnAppStartEnabled: boolean;
  haBaseUrl: string;
  addingServerFromSettings: boolean;
  onboardingBackTarget: number;
  dashboardBridgeReady: boolean;
  step: AppRoute;
  message: string;
}

export interface DashboardRuntimeCallbacks {
  applyActiveTheme: () => void;
  applyWindowPreferences: () => void;
  applyDashboardPreferences: () => void;
}

export class DashboardRuntimeService {
  static openDashboard(state: DashboardRuntimeState, callbacks: DashboardRuntimeCallbacks): void {
    const baseUrl = UrlService.normalizeBaseUrl(state.haBaseUrl);
    state.dashboardUrl = UrlService.buildDashboardUrl(baseUrl);
    state.dashboardCurrentUrl = state.dashboardUrl;
    state.dashboardClearHistoryPending = true;
    state.addingServerFromSettings = false;
    state.onboardingBackTarget = AppRoute.WELCOME;
    state.step = AppRoute.DASHBOARD;
    state.authUrl = '';
    state.showLoginWeb = false;
    state.dashboardBridgeReady = false;
    state.dashboardAuthProvided = false;
    callbacks.applyActiveTheme();
    callbacks.applyWindowPreferences();
    callbacks.applyDashboardPreferences();
    state.message = '';
  }

  static isWebControllerMounted(state: DashboardRuntimeState): boolean {
    if (state.showLoginWeb && state.authUrl.trim().length > 0) {
      return true;
    }
    return DashboardRuntimeService.isDashboardWebMounted(state);
  }

  static isDashboardWebMounted(state: DashboardRuntimeState): boolean {
    if (state.dashboardUrl.trim().length === 0) {
      return false;
    }
    return state.step === AppRoute.DASHBOARD || AppNavigator.isNativeOverlay(state.step);
  }

  static runScript(
    controller: web_webview.WebviewController,
    script: string,
    onResolve?: (raw: Object | string | number | ArrayBuffer) => void
  ): void {
    DashboardWebControllerTools.runScript(controller, script, onResolve);
  }

  static refresh(controller: web_webview.WebviewController): void {
    DashboardWebControllerTools.refresh(controller);
  }

  static loadUrl(controller: web_webview.WebviewController, url: string): void {
    DashboardWebControllerTools.loadUrl(controller, url);
  }

  static applyDashboardPreferences(controller: web_webview.WebviewController, state: DashboardRuntimeState): void {
    if (!DashboardRuntimeService.isDashboardWebMounted(state)) {
      return;
    }
    DashboardWebControllerTools.applyZoom(controller, state.pageZoomLevel);
  }

  static refreshDashboardTheme(controller: web_webview.WebviewController, state: DashboardRuntimeState): void {
    if (!DashboardRuntimeService.isDashboardWebMounted(state)) {
      return;
    }
    DashboardRuntimeService.refresh(controller);
  }

  static installFrontendUrlObserver(controller: web_webview.WebviewController, state: DashboardRuntimeState): void {
    if (!DashboardRuntimeService.isDashboardWebMounted(state)) {
      return;
    }
    DashboardRuntimeService.runScript(controller, DashboardRuntimeService.frontendUrlObserverScript());
  }

  private static frontendUrlObserverScript(): string {
    return `(function(){` +
      `if(window.__haHarmonyUrlObserverInstalled){return;}` +
      `window.__haHarmonyUrlObserverInstalled=true;` +
      `window.__haHarmonyLastUrl='';` +
      `function notify(){` +
      `var url=String(location.href||'');` +
      `if(!url||url===window.__haHarmonyLastUrl){return;}` +
      `window.__haHarmonyLastUrl=url;` +
      `try{externalApp.externalBus(JSON.stringify({type:'harmony_url_changed',payload:{url:url}}));}catch(e){}` +
      `}` +
      `function wrap(name){` +
      `var original=history[name];` +
      `if(typeof original!=='function'||original.__haHarmonyWrapped){return;}` +
      `history[name]=function(){var result=original.apply(this,arguments);setTimeout(notify,0);return result;};` +
      `history[name].__haHarmonyWrapped=true;` +
      `}` +
      `wrap('pushState');wrap('replaceState');` +
      `window.addEventListener('popstate',notify,true);` +
      `window.addEventListener('hashchange',notify,true);` +
      `setInterval(notify,1000);` +
      `notify();` +
      `})();`;
  }

  static shouldKeepCurrentDashboardPage(currentUrl: string): boolean {
    const path = UrlService.urlPathOnly(currentUrl);
    if (path.startsWith('/config/') && !path.startsWith('/config/dashboard')) {
      return true;
    }
    return path.startsWith('/hassio');
  }

  static maybeResetDashboardToFirstView(
    controller: web_webview.WebviewController,
    state: DashboardRuntimeState
  ): void {
    if (!state.alwaysShowFirstViewOnAppStartEnabled || state.haBaseUrl.trim().length === 0) {
      return;
    }
    if (DashboardRuntimeService.shouldKeepCurrentDashboardPage(state.dashboardCurrentUrl)) {
      return;
    }
    const url = UrlService.buildDashboardUrl(UrlService.normalizeBaseUrl(state.haBaseUrl));
    state.dashboardUrl = url;
    state.dashboardCurrentUrl = url;
    state.dashboardClearHistoryPending = true;
    DashboardRuntimeService.loadUrl(controller, url);
  }
}
