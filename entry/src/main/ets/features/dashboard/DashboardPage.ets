import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import web_webview from '@ohos.web.webview';
import { window } from '@kit.ArkUI';
import { UrlGuardResult } from '../../models/UrlGuardResult';
import { ExternalAppProxy } from './ExternalAppProxy';
import { DashboardWebBridge } from './DashboardWebBridge';
import { Localization } from '../../shared/i18n/Localization';
import { NetworkService } from '../../services/NetworkService';
import { UrlService } from '../../services/UrlService';
import { HaTheme } from '../../shared/theme/HaTheme';

@Component
export struct DashboardPage {
  @Prop @Watch('onDashboardUrlChanged')
  dashboardUrl: string = '';
  @Prop
  loadedDashboardUrl: string = '';
  @Prop @Watch('onDashboardActiveChanged')
  isActiveDashboard: boolean = false;
  @Prop
  dashboardAuthProvided: boolean = false;
  @Prop
  pageZoomLevel: string = '100';
  @Prop
  pinchToZoomEnabled: boolean = false;
  @Prop
  autoPlayVideoEnabled: boolean = false;
  @Prop
  appTheme: string = 'system';
  @Prop @Watch('onDashboardChromeChanged')
  isDarkTheme: boolean = false;
  @State private currentDashboardUrl: string = '';
  @State private dashboardTopChromeDark: boolean = false;
  @State private topSafeAreaPadding: number = 0;
  controller: web_webview.WebviewController = new web_webview.WebviewController();
  externalAppProxy: ExternalAppProxy = new ExternalAppProxy(
    () => {},
    () => {},
    () => {}
  );
  private dashboardExternalAppProxy: ExternalAppProxy = new ExternalAppProxy(
    (payload: Object | string): void => {
      this.externalAppProxy.getExternalAuth(payload);
    },
    (payload: Object | string): void => {
      this.externalAppProxy.revokeExternalAuth(payload);
    },
    (payload: Object | string): void => {
      this.handleExternalBus(payload);
    }
  );
  onBridgeReady: () => void = () => {};
  onPageReady: () => void = () => {};
  onRememberUrl: (url: string) => void = () => {};
  onLoadedUrlChange: (url: string) => void = () => {};
  onConnectionError: () => void = () => {};
  onConnectionLoadStarted: () => void = () => {};
  onMessage: (message: string) => void = () => {};
  onUrlGuard: (url: string) => UrlGuardResult = () => {
    return {
      intercept: false,
      rewrittenUrl: ''
    };
  };
  private controllerAttached: boolean = false;
  private resumeReloadGuardExpiresAt: number = 0;
  private clearedAuthStorageOrigin: string = '';
  private dashboardWindow: window.Window | undefined = undefined;
  private avoidAreaChangeCallback: ((data: window.AvoidAreaOptions) => void) | undefined = undefined;
  private isDashboardVisible: boolean = false;

  aboutToAppear(): void {
    this.isDashboardVisible = true;
    try {
      this.controller.setCustomUserAgent(NetworkService.ANDROID_COMPATIBLE_USER_AGENT);
    } catch (_) {
    }
    this.currentDashboardUrl = this.dashboardUrl;
    this.dashboardTopChromeDark = this.isDarkTheme;
    this.clearStoredAuthForDashboardOrigin();
    this.attachSystemAvoidAreaListener();
    this.refreshDashboardSystemBars();
  }

  aboutToDisappear(): void {
    this.isDashboardVisible = false;
    if (this.dashboardWindow && this.avoidAreaChangeCallback) {
      try {
        this.dashboardWindow.off('avoidAreaChange', this.avoidAreaChangeCallback);
      } catch (_) {
      }
    }
    this.dashboardWindow = undefined;
    this.avoidAreaChangeCallback = undefined;
    this.restoreDefaultSystemBars();
  }

  private onDashboardUrlChanged(): void {
    this.loadDashboardUrlIfNeeded();
  }

  private onDashboardChromeChanged(): void {
    if (!this.isDashboardVisible) {
      return;
    }
    this.dashboardTopChromeDark = this.isDarkTheme;
    this.refreshDashboardSystemBars();
  }

  private onDashboardActiveChanged(): void {
    if (!this.isDashboardVisible) {
      return;
    }
    if (!this.isActiveDashboard) {
      this.restoreDefaultSystemBars();
      return;
    }
    this.runDashboardStartupScript();
    this.refreshDashboardSystemBars();
  }

  private shouldExpandTopSafeArea(): boolean {
    const url = this.currentDashboardUrl.trim().length > 0 ? this.currentDashboardUrl : this.dashboardUrl;
    const path = UrlService.urlPathOnly(url).toLowerCase();
    return path !== '/hacs' && !path.startsWith('/hacs/');
  }

  private topPadding(): number {
    return this.shouldExpandTopSafeArea() ? 0 : this.topSafeAreaPadding;
  }

  private loadDashboardUrlIfNeeded(): void {
    const targetUrl = this.dashboardUrl.trim();
    if (!this.controllerAttached || targetUrl.length === 0) {
      return;
    }
    let currentUrl = '';
    try {
      currentUrl = this.controller.getUrl();
      if (
        UrlService.isHttpLikeUrl(currentUrl) &&
        UrlService.endpointKey(currentUrl) === UrlService.endpointKey(targetUrl)
      ) {
        this.onLoadedUrlChange(targetUrl);
        return;
      }
    } catch (_) {
    }
    if (targetUrl === this.loadedDashboardUrl && currentUrl.trim().length > 0 && currentUrl !== 'about:blank') {
      return;
    }
    try {
      this.controller.loadUrl(targetUrl);
    } catch (_) {
    }
  }

  private rememberLoadedDashboardUrl(url: string): void {
    const targetUrl = this.dashboardUrl.trim();
    if (
      UrlService.isHttpLikeUrl(url) &&
      UrlService.isHttpLikeUrl(targetUrl) &&
      UrlService.endpointKey(url) === UrlService.endpointKey(targetUrl)
    ) {
      this.onLoadedUrlChange(targetUrl);
    }
  }

  private originOf(url: string): string {
    const schemeEnd = url.indexOf('://');
    if (schemeEnd < 0) {
      return '';
    }
    const pathStart = url.indexOf('/', schemeEnd + 3);
    return (pathStart < 0 ? url : url.substring(0, pathStart)).toLowerCase();
  }

  private clearStoredAuthForDashboardOrigin(): void {
    const origin = this.originOf(this.dashboardUrl);
    if (origin.length === 0 || origin === this.clearedAuthStorageOrigin) {
      return;
    }
    try {
      web_webview.WebStorage.deleteOrigin(origin);
      this.clearedAuthStorageOrigin = origin;
    } catch (_) {
    }
  }

  private shouldSuppressResumeReload(url: string, isMainFrame: boolean, method: string, userGesture: boolean): boolean {
    const backgroundTick = AppStorage.get<number>('appBackgroundTick') ?? 0;
    const guardExpiresAt = Math.max(this.resumeReloadGuardExpiresAt, backgroundTick + 30 * 60 * 1000);
    if (!isMainFrame || userGesture || method.toUpperCase() !== 'GET' || Date.now() > guardExpiresAt) {
      return false;
    }
    const loadedUrl = this.loadedDashboardUrl.trim();
    if (
      !UrlService.isHttpLikeUrl(loadedUrl) ||
      UrlService.endpointKey(url) !== UrlService.endpointKey(loadedUrl)
    ) {
      return false;
    }
    if (this.originOf(url) !== this.originOf(this.dashboardUrl)) {
      return false;
    }
    this.resumeReloadGuardExpiresAt = Date.now() + 3000;
    return true;
  }

  private webDarkMode(): WebDarkMode {
    if (this.appTheme === 'system') {
      return WebDarkMode.Auto;
    }
    if (this.isDarkTheme) {
      return WebDarkMode.On;
    }
    return WebDarkMode.Off;
  }

  private initialWebSource(): string {
    const targetUrl = this.dashboardUrl.trim();
    return targetUrl.length > 0 ? targetUrl : 'about:blank';
  }

  private handleWebError(event: OnErrorReceiveEvent): void {
    if (!event) {
      return;
    }
    let requestUrl = '';
    let isMainFrame = true;
    try {
      requestUrl = event.request.getRequestUrl();
    } catch (_) {
      requestUrl = this.dashboardUrl;
    }
    try {
      isMainFrame = event.request.isMainFrame();
    } catch (_) {
      isMainFrame = true;
    }
    if (isMainFrame && (this.dashboardUrl.trim().length > 0 || requestUrl.trim().length > 0)) {
      this.onConnectionError();
    }
  }

  private rememberDashboardUrl(url: string): void {
    if (url.trim().length > 0 && url !== this.currentDashboardUrl) {
      this.currentDashboardUrl = url;
      this.refreshDashboardSystemBars();
    }
    this.onRememberUrl(url);
  }

  private handleExternalBus(payload: Object | string): void {
    const type = DashboardWebBridge.externalBusType(payload);
    if (type === 'harmony_url_changed') {
      const url = DashboardWebBridge.externalBusStringPayload(payload, 'url');
      if (url.length > 0 && url !== this.currentDashboardUrl) {
        this.currentDashboardUrl = url;
        this.refreshDashboardSystemBars();
      }
    } else if (type === 'harmony_dashboard_chrome_changed') {
      const dark = DashboardWebBridge.externalBusBooleanPayload(payload, 'dark', this.dashboardTopChromeDark);
      if (dark !== this.dashboardTopChromeDark) {
        this.dashboardTopChromeDark = dark;
      }
      this.refreshDashboardSystemBars();
    } else if (type === 'theme-update' || type === 'onHomeAssistantSetTheme') {
      this.runDashboardStartupScript();
    }
    this.externalAppProxy.externalBus(payload);
  }

  private dashboardChromeObserverScript(): string {
    return `(function(){` +
      `if(window.__haCompanionDashboardChromeObserverInstalled){` +
      `window.__haCompanionDashboardLastChrome='';` +
      `if(typeof window.__haCompanionDashboardNotifyChrome==='function'){window.__haCompanionDashboardNotifyChrome();}` +
      `return;` +
      `}` +
      `window.__haCompanionDashboardChromeObserverInstalled=true;` +
      `window.__haCompanionDashboardLastChrome='';` +
      `function emit(type,payload){try{externalApp.externalBus(JSON.stringify({type:type,payload:payload}));}catch(e){}}` +
      `function colorDark(color){` +
      `var raw=String(color||'').trim();` +
      `var hex=raw.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i);` +
      `var r=NaN;var g=NaN;var b=NaN;` +
      `if(hex){` +
      `var h=hex[1];` +
      `if(h.length===3){r=parseInt(h.charAt(0)+h.charAt(0),16);g=parseInt(h.charAt(1)+h.charAt(1),16);b=parseInt(h.charAt(2)+h.charAt(2),16);}` +
      `else{r=parseInt(h.substring(0,2),16);g=parseInt(h.substring(2,4),16);b=parseInt(h.substring(4,6),16);}` +
      `}else{` +
      `var m=raw.match(/rgba?\\(\\s*([0-9.]+)(?:,|\\s+)\\s*([0-9.]+)(?:,|\\s+)\\s*([0-9.]+)(?:\\s*[,/]\\s*([0-9.]+))?\\s*\\)/);` +
      `if(!m){return null;}` +
      `var a=m[4]!==undefined?parseFloat(m[4]):1;` +
      `if(!isNaN(a)&&a<=0.05){return null;}` +
      `r=parseFloat(m[1]);g=parseFloat(m[2]);b=parseFloat(m[3]);` +
      `}` +
      `if(isNaN(r)||isNaN(g)||isNaN(b)){return null;}` +
      `return (r*0.299+g*0.587+b*0.114)<140;` +
      `}` +
      `function tokenDark(name){` +
      `var root=document.documentElement;` +
      `if(!root){return null;}` +
      `var value=getComputedStyle(root).getPropertyValue(name);` +
      `return colorDark(value);` +
      `}` +
      `function chromeDark(){` +
      `var headerDark=tokenDark('--app-header-background-color');` +
      `if(headerDark!==null){return headerDark;}` +
      `var primaryDark=tokenDark('--primary-background-color');` +
      `if(primaryDark!==null){return primaryDark;}` +
      `return !!(window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches);` +
      `}` +
      `function notifyChrome(){` +
      `var dark=chromeDark();` +
      `var key=dark?'dark':'light';` +
      `if(key===window.__haCompanionDashboardLastChrome){return;}` +
      `window.__haCompanionDashboardLastChrome=key;` +
      `emit('harmony_dashboard_chrome_changed',{dark:dark});` +
      `}` +
      `window.__haCompanionDashboardNotifyChrome=notifyChrome;` +
      `notifyChrome();` +
      `})();`;
  }

  private applyTopSafeAreaPadding(topRectHeightPx: number): void {
    const topSafeAreaPadding = this.getUIContext().px2vp(topRectHeightPx);
    this.topSafeAreaPadding = Number.isFinite(topSafeAreaPadding) && topSafeAreaPadding > 0
      ? topSafeAreaPadding
      : 0;
  }

  private attachSystemAvoidAreaListener(): void {
    const appContext = this.getUIContext().getHostContext() as common.Context;
    window.getLastWindow(appContext)
      .then((mainWindow: window.Window): void => {
        if (!this.isDashboardVisible) {
          return;
        }
        this.dashboardWindow = mainWindow;
        try {
          this.applyTopSafeAreaPadding(mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height);
        } catch (_) {
          this.topSafeAreaPadding = 0;
        }
        if (this.avoidAreaChangeCallback) {
          return;
        }
        this.avoidAreaChangeCallback = (data: window.AvoidAreaOptions): void => {
          if (!this.isDashboardVisible) {
            return;
          }
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            this.applyTopSafeAreaPadding(data.area.topRect.height);
          }
        };
        mainWindow.on('avoidAreaChange', this.avoidAreaChangeCallback);
      })
      .catch((): void => {
        if (!this.isDashboardVisible) {
          return;
        }
        this.topSafeAreaPadding = 0;
      });
  }

  private applyDashboardSystemBars(): void {
    const appContext = this.getUIContext().getHostContext() as common.Context;
    window.getLastWindow(appContext)
      .then((mainWindow: window.Window): void => {
        if (!this.isDashboardVisible || !this.isActiveDashboard) {
          return;
        }
        const useLightIcon = this.shouldExpandTopSafeArea() ? this.dashboardTopChromeDark : this.isDarkTheme;
        mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: useLightIcon ? '#F5F7F8' : '#172126',
          navigationBarContentColor: this.isDarkTheme ? '#F5F7F8' : '#172126',
          isStatusBarLightIcon: useLightIcon,
          isNavigationBarLightIcon: this.isDarkTheme
        }).catch((): void => {});
      })
      .catch((): void => {});
  }

  private refreshDashboardSystemBars(): void {
    this.applyDashboardSystemBars();
    setTimeout((): void => {
      this.applyDashboardSystemBars();
    }, 120);
  }

  private restoreDefaultSystemBars(): void {
    const appContext = this.getUIContext().getHostContext() as common.Context;
    window.getLastWindow(appContext)
      .then((mainWindow: window.Window): void => {
        mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: '#172126',
          navigationBarContentColor: '#172126',
          isStatusBarLightIcon: false,
          isNavigationBarLightIcon: false
        }).catch((): void => {});
      })
      .catch((): void => {});
  }

  private haSafeAreaPatchScript(): string {
    return `(function(){` +
      `if(window.__haCompanionSafeAreaPatchInstalled){return;}` +
      `window.__haCompanionSafeAreaPatchInstalled=true;` +
      `var css=':host{--app-safe-area-inset-left:0px!important;--app-safe-area-inset-right:0px!important;}';` +
      `function styleRoot(root,id){` +
      `if(!root){return;}` +
      `var style=root.getElementById(id);` +
      `if(!style){style=document.createElement('style');style.id=id;root.appendChild(style);}` +
      `style.id=id;` +
      `style.textContent=css;` +
      `}` +
      `function patch(){` +
      `document.documentElement.style.setProperty('--app-safe-area-inset-left','0px');` +
      `document.documentElement.style.setProperty('--app-safe-area-inset-right','0px');` +
      `if(document.body){` +
      `document.body.style.setProperty('--app-safe-area-inset-left','0px');` +
      `document.body.style.setProperty('--app-safe-area-inset-right','0px');` +
      `}` +
      `var ha=document.querySelector('home-assistant');` +
      `if(!ha||!ha.shadowRoot){return;}` +
      `styleRoot(ha.shadowRoot,'ha-companion-safe-area-root');` +
      `var main=ha.shadowRoot.querySelector('home-assistant-main');` +
      `if(main&&main.shadowRoot){styleRoot(main.shadowRoot,'ha-companion-safe-area-main');}` +
      `}` +
      `patch();` +
      `var attempts=0;` +
      `var timer=setInterval(function(){attempts++;patch();if(attempts>=40){clearInterval(timer);}},250);` +
      `new MutationObserver(patch).observe(document.documentElement,{childList:true,subtree:true});` +
      `})();`;
  }

  private runDashboardStartupScript(): void {
    try {
      this.controller.runJavaScript(this.dashboardChromeObserverScript() + this.haSafeAreaPatchScript()).catch((): void => {});
    } catch (_) {
    }
  }

  private isAudioCaptureRequest(resources: Array<string>): boolean {
    if (resources.length === 0) {
      return false;
    }
    for (let i = 0; i < resources.length; i++) {
      if (resources[i] !== 'TYPE_AUDIO_CAPTURE') {
        return false;
      }
    }
    return true;
  }

  private handleWebPermissionRequest(request: PermissionRequest): void {
    const resources = request.getAccessibleResource();
    if (!this.isAudioCaptureRequest(resources)) {
      request.deny();
      return;
    }

    const appContext = this.getUIContext().getHostContext() as common.Context;
    abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(appContext, ['ohos.permission.MICROPHONE'])
      .then((result): void => {
        const granted = result.authResults.length > 0 && result.authResults[0] === 0;
        if (granted) {
          request.grant(resources);
        } else {
          request.deny();
        }
      })
      .catch((): void => {
        request.deny();
      });
  }

  build() {
    Column() {
      if (this.dashboardUrl) {
        Web({ src: this.initialWebSource(), controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .databaseAccess(true)
          .mixedMode(MixedMode.All)
          .darkMode(this.webDarkMode())
          .zoomAccess(this.pinchToZoomEnabled)
          .forceEnableZoom(this.pinchToZoomEnabled)
          .pinchSmooth(this.pinchToZoomEnabled)
          .mediaPlayGestureAccess(!this.autoPlayVideoEnabled)
          .forceDarkAccess(this.isDarkTheme)
          .runJavaScriptOnHeadEnd([{ script: this.dashboardChromeObserverScript() + this.haSafeAreaPatchScript(), scriptRules: ['*'] }])
          .overScrollMode(OverScrollMode.ALWAYS)
          .onPermissionRequest((event) => {
            if (event) {
              this.handleWebPermissionRequest(event.request);
            }
          })
          .onConsole((event) => {
            return false;
          })
          .javaScriptProxy({
            object: this.dashboardExternalAppProxy,
            name: 'externalApp',
            methodList: ['getExternalAuth', 'revokeExternalAuth', 'externalBus'],
            controller: this.controller
          })
          .onControllerAttached(() => {
            this.controllerAttached = true;
            this.onBridgeReady();
          })
          .onPageBegin((event) => {
            this.rememberDashboardUrl(event.url);
            this.rememberLoadedDashboardUrl(event.url);
            if (!this.dashboardAuthProvided) {
              this.onConnectionLoadStarted();
            }
          })
          .onPageEnd((event) => {
            this.rememberDashboardUrl(event.url);
            this.rememberLoadedDashboardUrl(event.url);
            const zoomLevel = Number(this.pageZoomLevel);
            if (Number.isFinite(zoomLevel) && zoomLevel > 0) {
              try {
                this.controller.zoom(zoomLevel / 100);
              } catch (_) {
                // Keep the page usable if the controller rejects the zoom request.
              }
            }
            this.runDashboardStartupScript();
            this.refreshDashboardSystemBars();
            this.onPageReady();
          })
          .onErrorReceive((event) => {
            this.handleWebError(event);
          })
          .onLoadIntercept((event) => {
            if (!event) {
              return false;
            }

            const data = event.data;
            let currentUrl = '';
            let isMainFrame = true;
            let requestMethod = 'GET';
            let userGesture = false;
            if (typeof data === 'string') {
              currentUrl = data;
            } else {
              currentUrl = data.getRequestUrl();
              try {
                isMainFrame = data.isMainFrame();
              } catch (_) {
                isMainFrame = true;
              }
              try {
                requestMethod = data.getRequestMethod();
              } catch (_) {
                requestMethod = 'GET';
              }
              try {
                userGesture = data.isRequestGesture();
              } catch (_) {
                userGesture = false;
              }
            }

            if (isMainFrame && requestMethod === 'GET') {
              if (this.shouldSuppressResumeReload(currentUrl, isMainFrame, requestMethod, userGesture)) {
                return true;
              }
              this.rememberDashboardUrl(currentUrl);
              const guard = this.onUrlGuard(currentUrl);
              if (guard.intercept) {
                this.controller.loadUrl(guard.rewrittenUrl);
                return true;
              }
            }

            return false;
          })
          .width('100%')
          .height('100%')
          .layoutWeight(1)
      } else {
        Column()
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea(
      [SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
      this.shouldExpandTopSafeArea() ? [SafeAreaEdge.TOP] : []
    )
    .padding({ top: this.topPadding() })
    .backgroundColor(HaTheme.background(this.isDarkTheme))
  }
}
