import { HaTheme } from '../shared/theme/HaTheme';
import { AppRootLayoutSafeArea } from '../shared/ui/AppRootLayoutSafeArea';
import { AppNavigator } from './AppNavigator';
import { AppRoute } from './AppRoute';

@Builder
function emptyRuntimeLayer(): void {
}

function isSettingsNavigationRoute(route: number): boolean {
  return route === AppRoute.COMPANION_SETTINGS ||
    route === AppRoute.SETTINGS_DETAIL ||
    route === AppRoute.SERVER_SETTINGS;
}

function isSettingsNativeFeatureRoute(route: number): boolean {
  return route === AppRoute.NOTIFICATION_SETTINGS ||
    route === AppRoute.SENSOR_SETTINGS ||
    route === AppRoute.SENSOR_UPDATE_FREQUENCY;
}

@Component
export struct AppRuntimeScaffold {
  @Prop appLocked: boolean = false;
  @Prop wearableProfile: boolean = false;
  @Prop @Watch('onSettingsFlowChanged') route: number = AppRoute.WELCOME;
  @Prop @Watch('onSettingsFlowChanged') companionSettingsFlowVisible: boolean = false;
  @Prop secureConnectionFromSettings: boolean = false;
  @Prop dark: boolean = false;
  @State private settingsLayerMounted: boolean = false;
  @State private settingsLayerOffset: string = '100%';
  private settingsLayerVisible: boolean = false;

  onViewportAreaChange: (width: Length, height: Length) => void = () => {};
  onBackGesture: () => void = () => {};
  isNativeOnboardingStep: () => boolean = () => false;

  @BuilderParam renderAppLock: () => void = emptyRuntimeLayer;
  @BuilderParam renderWearHome: () => void = emptyRuntimeLayer;
  @BuilderParam renderLoggedIn: () => void = emptyRuntimeLayer;
  @BuilderParam renderOnboardingFlow: () => void = emptyRuntimeLayer;
  @BuilderParam renderLoginWeb: () => void = emptyRuntimeLayer;
  @BuilderParam renderCompanionSettings: () => void = emptyRuntimeLayer;
  @BuilderParam renderSettingsDetail: () => void = emptyRuntimeLayer;
  @BuilderParam renderServerSettings: () => void = emptyRuntimeLayer;
  @BuilderParam renderSettingsSecureConnection: () => void = emptyRuntimeLayer;
  @BuilderParam renderRuntimeOverlays: () => void = emptyRuntimeLayer;

  aboutToAppear(): void {
    this.settingsLayerVisible = this.isSettingsFlowVisible();
    this.settingsLayerMounted = this.settingsLayerVisible;
    this.settingsLayerOffset = this.settingsLayerVisible ? '0%' : '100%';
  }

  private isSettingsFlowVisible(): boolean {
    if (this.settingsLayerVisible && isSettingsNativeFeatureRoute(this.route)) {
      return true;
    }
    return this.companionSettingsFlowVisible || isSettingsNavigationRoute(this.route);
  }

  private isSettingsSecureConnectionRoute(): boolean {
    return this.secureConnectionFromSettings;
  }

  private onSettingsFlowChanged(): void {
    const visible = this.isSettingsFlowVisible();
    if (visible === this.settingsLayerVisible) {
      return;
    }
    this.settingsLayerVisible = visible;
    if (visible) {
      this.settingsLayerMounted = true;
      this.settingsLayerOffset = '100%';
      setTimeout((): void => {
        animateTo({ duration: 260, curve: Curve.Friction }, (): void => {
          this.settingsLayerOffset = '0%';
        });
      }, 0);
    } else {
      animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
        this.settingsLayerOffset = '100%';
      });
      setTimeout((): void => {
        if (!this.settingsLayerVisible) {
          this.settingsLayerMounted = false;
        }
      }, 230);
    }
  }

  build() {
    Stack() {
      if (this.appLocked) {
        this.renderAppLock();
      } else if (this.wearableProfile) {
        this.renderWearHome();
      } else if (this.route === AppRoute.DASHBOARD ||
        AppNavigator.isNativeOverlay(this.route as AppRoute) ||
        this.isSettingsSecureConnectionRoute()) {
        this.renderLoggedIn();
      } else if (this.isNativeOnboardingStep()) {
        this.renderOnboardingFlow();
      } else if (this.route === AppRoute.LOGIN) {
        this.renderLoginWeb();
      } else {
        this.renderLoggedIn();
      }

      if (this.settingsLayerMounted && !this.isSettingsSecureConnectionRoute()) {
        Column() {
          this.renderCompanionSettings();
        }
        .width('100%')
        .height('100%')
        .translate({ x: this.settingsLayerOffset })
      }

      if (this.isSettingsSecureConnectionRoute()) {
        Column() {
          this.renderSettingsSecureConnection();
        }
        .width('100%')
        .height('100%')
      }

      if (!this.settingsLayerMounted && !this.isSettingsSecureConnectionRoute()) {
        this.renderRuntimeOverlays();
      }

    }
    .width('100%')
    .height('100%')
    .ignoreLayoutSafeArea(AppRootLayoutSafeArea.nonSafeAreaTypes(), AppRootLayoutSafeArea.ignoredImmersiveEdges())
    .backgroundColor(HaTheme.background(this.dark))
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.onViewportAreaChange(newArea.width, newArea.height);
    })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetX > 60 || event.offsetX < -60) {
            this.onBackGesture();
          }
        })
    )
  }
}
