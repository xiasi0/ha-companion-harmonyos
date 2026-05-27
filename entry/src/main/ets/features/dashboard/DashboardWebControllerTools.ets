import web_webview from '@ohos.web.webview';

export class DashboardWebControllerTools {
  static runScript(
    controller: web_webview.WebviewController,
    script: string,
    onResolve?: (raw: Object | string | number | ArrayBuffer) => void
  ): void {
    try {
      const promise = controller.runJavaScript(script);
      if (onResolve) {
        promise.then((raw: Object | string | number | ArrayBuffer): void => {
          onResolve(raw);
        }).catch((): void => {
          onResolve('false');
        });
      } else {
        promise.catch((): void => {});
      }
    } catch (_) {
      // Ignore while the WebView is not attached yet.
      if (onResolve) {
        onResolve('false');
      }
    }
  }

  static zoom(controller: web_webview.WebviewController, scale: number): void {
    try {
      controller.zoom(scale);
    } catch (_) {
      // Ignore while the WebView is not attached yet.
    }
  }

  static refresh(controller: web_webview.WebviewController): void {
    try {
      controller.refresh();
    } catch (_) {
      // Ignore while the WebView is not attached yet.
    }
  }

  static loadUrl(controller: web_webview.WebviewController, url: string): void {
    try {
      controller.loadUrl(url);
    } catch (_) {
      // Ignore while the WebView is not attached yet.
    }
  }

  static applyZoom(controller: web_webview.WebviewController, pageZoomLevel: string): void {
    const zoomLevel = Number(pageZoomLevel);
    if (!Number.isFinite(zoomLevel) || zoomLevel <= 0) {
      return;
    }
    const zoomScale = zoomLevel / 100;
    DashboardWebControllerTools.zoom(controller, zoomScale);
    const zoomScript = `
      (function() {
        try {
          var root = document.documentElement;
          if (!root) {
            return;
          }
          root.style.zoom = '${zoomScale}';
          root.style.setProperty('--ha-companion-page-zoom', '${zoomScale}');
          if (document.body) {
            document.body.style.minHeight = '100%';
          }
        } catch (e) {
        }
      })();
    `;
    DashboardWebControllerTools.runScript(controller, zoomScript);
  }
}
