import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import web_webview from '@ohos.web.webview';
import { UrlGuardResult } from '../../models/UrlGuardResult';
import { ExternalAppProxy } from './ExternalAppProxy';
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
  @Prop
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
  appTheme: string = 'light';
  @Prop
  isDarkTheme: boolean = false;
  controller: web_webview.WebviewController = new web_webview.WebviewController();
  externalAppProxy: ExternalAppProxy = new ExternalAppProxy(
    () => {},
    () => {},
    () => {}
  );
  onBridgeReady: () => void = () => {};
  onPageReady: () => void = () => {};
  onRememberUrl: (url: string) => void = () => {};
  onLoadedUrlChange: (url: string) => void = () => {};
  onMessage: (message: string) => void = () => {};
  onUrlGuard: (url: string) => UrlGuardResult = () => {
    return {
      intercept: false,
      rewrittenUrl: ''
    };
  };
  private controllerAttached: boolean = false;
  private resumeReloadGuardExpiresAt: number = 0;

  aboutToAppear(): void {
    try {
      this.controller.setCustomUserAgent(NetworkService.ANDROID_COMPATIBLE_USER_AGENT);
    } catch (_) {
    }
  }

  private onDashboardUrlChanged(): void {
    this.loadDashboardUrlIfNeeded();
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

  private viewportFitCoverScript(): string {
    return `(function(){` +
      `var content='width=device-width,initial-scale=1,viewport-fit=cover';` +
      `var metas=document.getElementsByTagName('meta');` +
      `var viewport=null;` +
      `for(var i=0;i<metas.length;i++){if((metas[i].getAttribute('name')||'').toLowerCase()==='viewport'){viewport=metas[i];break;}}` +
      `if(!viewport){viewport=document.createElement('meta');viewport.setAttribute('name','viewport');document.head.appendChild(viewport);}` +
      `var current=viewport.getAttribute('content')||'';` +
      `if(current.indexOf('viewport-fit=')>=0){current=current.replace(/viewport-fit\\s*=\\s*[^,]+/,'viewport-fit=cover');}` +
      `else{current=(current.trim().length>0?current+',':'')+'viewport-fit=cover';}` +
      `viewport.setAttribute('content',current||content);` +
      `})();`;
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

  private runHaSafeAreaPatch(): void {
    try {
      this.controller.runJavaScript(this.haSafeAreaPatchScript()).catch((): void => {});
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
          .runJavaScriptOnHeadEnd([{ script: this.viewportFitCoverScript() + this.haSafeAreaPatchScript(), scriptRules: ['*'] }])
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
            object: this.externalAppProxy,
            name: 'externalApp',
            methodList: ['getExternalAuth', 'revokeExternalAuth', 'externalBus'],
            controller: this.controller
          })
          .onControllerAttached(() => {
            this.controllerAttached = true;
            this.onBridgeReady();
          })
          .onPageBegin((event) => {
            this.onRememberUrl(event.url);
            this.rememberLoadedDashboardUrl(event.url);
          })
          .onPageEnd((event) => {
            this.onRememberUrl(event.url);
            this.rememberLoadedDashboardUrl(event.url);
            const zoomLevel = Number(this.pageZoomLevel);
            if (Number.isFinite(zoomLevel) && zoomLevel > 0) {
              try {
                this.controller.zoom(zoomLevel / 100);
              } catch (_) {
                // Keep the page usable if the controller rejects the zoom request.
              }
            }
            this.runHaSafeAreaPatch();
            this.onPageReady();
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
              this.onRememberUrl(currentUrl);
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
          .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.START, SafeAreaEdge.END])
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
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.START, SafeAreaEdge.END])
    .backgroundColor(HaTheme.background(this.isDarkTheme))
  }
}
