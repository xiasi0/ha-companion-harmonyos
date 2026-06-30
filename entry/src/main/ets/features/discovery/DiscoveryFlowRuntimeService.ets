import common from '@ohos.app.ability.common';
import { AppRoute } from '../../app/AppRoute';
import { HaServerItem } from '../../models/HaServerItem';
import { StorageService, StoredServerInfo } from '../../services/StorageService';
import { UrlService } from '../../services/UrlService';
import { DiscoveryService, HaServerProbeResult } from '../../services/DiscoveryService';
import { Localization } from '../../shared/i18n/Localization';
import { ConnectionErrorMapper } from '../connection/ConnectionErrorMapper';
import { ConnectionError } from '../connection/ConnectionErrorModels';
import { DiscoveryRuntimeService } from './DiscoveryRuntimeService';

export interface DiscoveryFlowRuntimeState {
  discovering: boolean;
  message: string;
  discoveredServers: HaServerItem[];
  discoverySheetPresented: boolean;
  addingServerFromSettings: boolean;
  addServerSnapshot: StoredServerInfo;
  haBaseUrl: string;
  manualAddress: string;
  step: number;
  onboardingBackTarget: number;
  showLoginWeb: boolean;
  loading: boolean;
  authUrl: string;
  oauthState: string;
  handledAuthCode: string;
  connectionErrorUrl: string;
  connectionErrorCode: number;
  connectionErrorDetail: string;
  connectionError: ConnectionError | undefined;
  connectionErrorBackTarget: number;
  connectionProbeToken: number;
  dashboardBridgeReady: boolean;
  dashboardAuthProvided: boolean;
  discoveryAnimationRunning: boolean;
  discoveryAnimationToken: number;
  discoverySpinAngle: number;
  discoveryPulseScale: number;
}

export interface DiscoveryFlowRuntimeCallbacks {
  context: () => common.Context;
  setDiscoverySheetVisible: (visible: boolean) => void;
  currentServerInfo: () => StoredServerInfo;
  applyServerInfo: (info: StoredServerInfo) => void;
  startOfficialLogin: () => void;
}

export class DiscoveryFlowRuntimeService {
  static async discover(state: DiscoveryFlowRuntimeState, callbacks: DiscoveryFlowRuntimeCallbacks): Promise<void> {
    state.discovering = true;
    state.message = '';
    state.discoveredServers = [];
    state.discoverySheetPresented = false;
    callbacks.setDiscoverySheetVisible(false);
    await DiscoveryRuntimeService.discover({
      context: callbacks.context(),
      addingServerFromSettings: state.addingServerFromSettings,
      addServerSnapshot: state.addServerSnapshot,
      baseUrl: state.haBaseUrl,
      manualAddress: state.manualAddress
    }, {
      onServerFound: (server: HaServerItem): void => {
        state.discoveredServers.push(server);
        if (state.step === AppRoute.DISCOVERY && !state.discoverySheetPresented) {
          state.discoverySheetPresented = true;
          callbacks.setDiscoverySheetVisible(true);
        }
      },
      onServerStatus: (server: HaServerItem): void => {
        const next: HaServerItem[] = [];
        for (let i = 0; i < state.discoveredServers.length; i++) {
          next.push(state.discoveredServers[i].key === server.key ? server : state.discoveredServers[i]);
        }
        state.discoveredServers = next;
      }
    });
    state.discovering = false;
    state.message = '';
  }

  static selectServer(state: DiscoveryFlowRuntimeState, callbacks: DiscoveryFlowRuntimeCallbacks, url: string): void {
    DiscoveryFlowRuntimeService.connectServerAddress(state, callbacks, url, AppRoute.DISCOVERY);
  }

  private static activateServer(state: DiscoveryFlowRuntimeState, callbacks: DiscoveryFlowRuntimeCallbacks, url: string): void {
    callbacks.setDiscoverySheetVisible(false);
    DiscoveryFlowRuntimeService.stopAnimation(state);
    callbacks.applyServerInfo(
      StorageService.applyServer(callbacks.currentServerInfo(), UrlService.normalizeBaseUrl(url))
    );
    state.step = AppRoute.LOGIN;
    callbacks.startOfficialLogin();
  }

  static connectManualAddress(state: DiscoveryFlowRuntimeState, callbacks: DiscoveryFlowRuntimeCallbacks): void {
    const normalized = UrlService.normalizeBaseUrl(state.manualAddress);
    if (!normalized) {
      state.message = Localization.t('manual_server_enter_address');
      return;
    }
    DiscoveryFlowRuntimeService.connectServerAddress(state, callbacks, normalized, AppRoute.MANUAL_SERVER);
  }

  static retryConnectionError(state: DiscoveryFlowRuntimeState, callbacks: DiscoveryFlowRuntimeCallbacks): void {
    const target = UrlService.normalizeBaseUrl(state.connectionErrorUrl);
    if (!target) {
      state.step = state.connectionErrorBackTarget > 0 ? state.connectionErrorBackTarget : AppRoute.MANUAL_SERVER;
      return;
    }
    DiscoveryFlowRuntimeService.connectServerAddress(state, callbacks, target, state.connectionErrorBackTarget);
  }

  private static connectServerAddress(
    state: DiscoveryFlowRuntimeState,
    callbacks: DiscoveryFlowRuntimeCallbacks,
    url: string,
    backTarget: AppRoute
  ): void {
    const normalized = UrlService.normalizeBaseUrl(url);
    if (!normalized) {
      state.message = Localization.t('manual_server_enter_address');
      return;
    }
    state.loading = true;
    state.message = '';
    state.connectionErrorUrl = normalized;
    state.connectionErrorCode = 0;
    state.connectionErrorDetail = '';
    state.connectionError = undefined;
    state.connectionErrorBackTarget = backTarget;
    const token = state.connectionProbeToken + 1;
    state.connectionProbeToken = token;
    DiscoveryService.probeHaServerResult(normalized)
      .then((result: HaServerProbeResult): void => {
        if (state.connectionProbeToken !== token) {
          return;
        }
        state.loading = false;
        if (result.reachable) {
          state.connectionErrorUrl = '';
          state.connectionErrorCode = 0;
          state.connectionErrorDetail = '';
          state.connectionError = undefined;
          DiscoveryFlowRuntimeService.activateServer(state, callbacks, result.baseUrl);
          return;
        }
        DiscoveryFlowRuntimeService.showConnectionError(state, result.baseUrl, result, backTarget);
      })
      .catch((error: Error | string | number | boolean | Object | ArrayBuffer): void => {
        if (state.connectionProbeToken !== token) {
          return;
        }
        state.loading = false;
        DiscoveryFlowRuntimeService.showConnectionError(state, normalized, {
          reachable: false,
          baseUrl: normalized,
          responseCode: -2,
          detail: error instanceof Error ? error.message : Localization.t('connection_error_unknown_detail')
        }, backTarget);
      });
  }

  private static showConnectionError(
    state: DiscoveryFlowRuntimeState,
    url: string,
    result: HaServerProbeResult,
    backTarget: AppRoute
  ): void {
    state.connectionErrorUrl = url;
    state.connectionErrorCode = result.responseCode;
    state.connectionErrorDetail = result.detail;
    state.connectionError = ConnectionErrorMapper.fromProbeResult(url, result);
    state.connectionErrorBackTarget = backTarget;
    state.showLoginWeb = false;
    state.authUrl = '';
    state.step = AppRoute.CONNECTION_ERROR;
  }

  static startFlow(
    state: DiscoveryFlowRuntimeState,
    callbacks: DiscoveryFlowRuntimeCallbacks,
    backTarget: AppRoute = AppRoute.WELCOME
  ): void {
    state.step = AppRoute.DISCOVERY;
    state.onboardingBackTarget = backTarget;
    state.discoveredServers = [];
    state.discoverySheetPresented = false;
    state.connectionErrorUrl = '';
    state.connectionErrorCode = 0;
    state.connectionErrorDetail = '';
    state.connectionError = undefined;
    state.connectionErrorBackTarget = AppRoute.MANUAL_SERVER;
    state.connectionProbeToken += 1;
    state.loading = false;
    callbacks.setDiscoverySheetVisible(false);
    DiscoveryFlowRuntimeService.discover(state, callbacks).catch((): void => {
      state.message = '';
      state.discovering = false;
    });
  }

  static startAnimation(state: DiscoveryFlowRuntimeState): void {
    if (state.discoveryAnimationRunning) {
      return;
    }
    state.discoveryAnimationRunning = true;
    const token = state.discoveryAnimationToken + 1;
    state.discoveryAnimationToken = token;
    state.discoverySpinAngle = 0;
    state.discoveryPulseScale = 1;
    setTimeout((): void => {
      if (state.discoveryAnimationToken === token && state.step === AppRoute.DISCOVERY) {
        state.discoverySpinAngle = 360;
        state.discoveryPulseScale = 1.15;
      }
    }, 16);
  }

  static stopAnimation(state: DiscoveryFlowRuntimeState): void {
    state.discoveryAnimationRunning = false;
    state.discoveryAnimationToken += 1;
    state.discoverySpinAngle = 0;
    state.discoveryPulseScale = 1;
  }

  static startAddServerFromSettings(state: DiscoveryFlowRuntimeState, callbacks: DiscoveryFlowRuntimeCallbacks): void {
    state.addServerSnapshot = callbacks.currentServerInfo();
    state.addingServerFromSettings = true;
    state.onboardingBackTarget = AppRoute.COMPANION_SETTINGS;
    state.manualAddress = '';
    state.message = '';
    state.authUrl = '';
    state.showLoginWeb = false;
    state.dashboardBridgeReady = false;
    state.dashboardAuthProvided = false;
    DiscoveryFlowRuntimeService.startFlow(state, callbacks, AppRoute.COMPANION_SETTINGS);
  }

  static cancelAddServerFromSettings(state: DiscoveryFlowRuntimeState, callbacks: DiscoveryFlowRuntimeCallbacks): void {
    DiscoveryFlowRuntimeService.stopAnimation(state);
    callbacks.setDiscoverySheetVisible(false);
    callbacks.applyServerInfo(state.addServerSnapshot);
    state.addingServerFromSettings = false;
    state.onboardingBackTarget = AppRoute.WELCOME;
    state.authUrl = '';
    state.oauthState = '';
    state.handledAuthCode = '';
    state.manualAddress = '';
    state.connectionErrorUrl = '';
    state.connectionErrorCode = 0;
    state.connectionErrorDetail = '';
    state.connectionError = undefined;
    state.connectionErrorBackTarget = AppRoute.MANUAL_SERVER;
    state.connectionProbeToken += 1;
    state.showLoginWeb = false;
    state.loading = false;
    state.message = '';
    state.step = AppRoute.COMPANION_SETTINGS;
  }
}
