import common from '@ohos.app.ability.common';
import { AuthRuntimeService } from '../auth/AuthRuntimeService';
import { SensorUpdateFrequency } from '../sensors/SensorModels';
import { AppRoute } from '../../app/AppRoute';
import { Localization } from '../../shared/i18n/Localization';
import { StorageService, StoredServerInfo } from '../../services/StorageService';
import { ServerManager } from '../../services/ServerManager';
import { HarmonySensorService } from '../../services/HarmonySensorService';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { UrlService } from '../../services/UrlService';

export interface ServerAccountRuntimeState {
  haBaseUrl: string;
  haRefreshToken: string;
  deletingServer: boolean;
  showDeleteServerDialog: boolean;
  message: string;
  appLocked: boolean;
  appUnlocking: boolean;
  appLockAuthPending: boolean;
  secureConnectionChoice: string;
  homeWifiSsids: string[];
  homeSsidInput: string;
  prioritizeInternal: boolean;
  configSummary: string;
  dashboardUrl: string;
  dashboardCurrentUrl: string;
  nativeSettingsReturnUrl: string;
  dashboardBackToHomePending: boolean;
  dashboardBridgeReady: boolean;
  dashboardAuthProvided: boolean;
  showLoginWeb: boolean;
  authUrl: string;
  oauthState: string;
  handledAuthCode: string;
  addingServerFromSettings: boolean;
  step: number;
}

export interface ServerDeleteTarget {
  id: string;
  info: StoredServerInfo;
}

export interface ServerAccountRuntimeCallbacks {
  context: () => common.Context;
  clearCardsForServer: (serverInstanceId: string) => Promise<void>;
  stopDiscoveryAnimation: () => void;
  applyServerInfo: (info: StoredServerInfo) => void;
  resetSensorRuntime: () => void;
  resetAddServerSnapshot: () => void;
  refreshSettingsState: () => void;
  restoreAppSettings: () => Promise<void>;
}

export class ServerAccountRuntimeService {
  static async revokeSession(baseUrl: string, refreshToken: string): Promise<void> {
    if (baseUrl.length > 0 && refreshToken.trim().length > 0) {
      await AuthRuntimeService.revokeSession(baseUrl, refreshToken);
    }
  }

  static deleteCurrentServer(
    state: ServerAccountRuntimeState,
    callbacks: ServerAccountRuntimeCallbacks,
    target?: ServerDeleteTarget
  ): void {
    if (state.deletingServer) {
      return;
    }
    state.deletingServer = true;
    state.message = '';
    state.showDeleteServerDialog = false;
    setTimeout((): void => {
      if (state.deletingServer) {
        state.showDeleteServerDialog = true;
      }
    }, 2500);
    ServerAccountRuntimeService.deleteCurrentServerAsync(state, callbacks, target);
  }

  private static async deleteCurrentServerAsync(
    state: ServerAccountRuntimeState,
    callbacks: ServerAccountRuntimeCallbacks,
    target?: ServerDeleteTarget
  ): Promise<void> {
    const deleteInfo = target && target.id.length > 0 ? target.info : StorageService.serverInfo(
      state.haBaseUrl,
      '',
      state.haRefreshToken,
      0,
      '',
      '',
      '',
      '',
      '',
      ''
    );
    const serverId = target && target.id.length > 0 ? target.id : ServerManager.getActiveServerIdSync(callbacks.context());
    const policy = serverId.length > 0 ?
      await HaConnectionPolicyService.resolveServerBaseUrl(callbacks.context(), serverId) :
      undefined;
    if (policy && policy.allowed && policy.baseUrl.length > 0) {
      await HarmonySensorService.clearDeviceTrackerLocation(
        policy.baseUrl,
        deleteInfo.webhookId,
        deleteInfo.cloudhookUrl
      ).catch((): void => {});
      await ServerAccountRuntimeService.revokeSession(policy.baseUrl, deleteInfo.refreshToken);
    }
    if (target && target.id.length > 0) {
      await callbacks.clearCardsForServer(target.id).catch((): void => {});
    }
    const nextServer = target && target.id.length > 0
      ? await ServerManager.removeServer(callbacks.context(), target.id)
      : await ServerManager.removeActiveServer(callbacks.context());

    callbacks.stopDiscoveryAnimation();
    callbacks.applyServerInfo(nextServer);
    if (StorageService.hasLogin(nextServer)) {
      await callbacks.restoreAppSettings();
    } else {
      ServerAccountRuntimeService.resetStoredServerState();
    }
    state.appLocked = false;
    state.appUnlocking = false;
    state.appLockAuthPending = false;
    callbacks.resetSensorRuntime();
    state.homeSsidInput = '';
    if (!StorageService.hasLogin(nextServer)) {
      state.secureConnectionChoice = '';
      state.homeWifiSsids = [];
      state.prioritizeInternal = false;
    }
    state.configSummary = Localization.t('common_not_set');
    state.dashboardUrl = StorageService.hasLogin(nextServer) ? UrlService.buildDashboardUrl(nextServer.baseUrl) : '';
    state.dashboardCurrentUrl = state.dashboardUrl;
    state.nativeSettingsReturnUrl = '';
    state.dashboardBackToHomePending = false;
    state.dashboardBridgeReady = false;
    state.dashboardAuthProvided = false;
    state.showLoginWeb = false;
    state.authUrl = '';
    state.oauthState = '';
    state.handledAuthCode = '';
    state.addingServerFromSettings = false;
    callbacks.resetAddServerSnapshot();
    callbacks.refreshSettingsState();

    setTimeout((): void => {
      state.showDeleteServerDialog = false;
      state.deletingServer = false;
      state.step = StorageService.hasLogin(nextServer) ? AppRoute.DASHBOARD : AppRoute.WELCOME;
      state.message = '';
    }, 300);
  }

  static resetStoredServerState(): void {
    AppStorage.setOrCreate<string>('serverNameOverride', '');
    AppStorage.setOrCreate<string>('serverExternalUrl', '');
    AppStorage.setOrCreate<string>('serverInternalUrl', '');
    AppStorage.setOrCreate<string>('secureConnectionChoice', '');
    AppStorage.setOrCreate<string>('homeNetworkName', '');
    AppStorage.setOrCreate<boolean>('trustServer', false);
    AppStorage.setOrCreate<boolean>('appLockEnabled', false);
    AppStorage.setOrCreate<boolean>('appLockHomeBypass', false);
    AppStorage.setOrCreate<string>('sessionTimeout', '0');
    AppStorage.setOrCreate<string>('websocketMode', 'system');
    AppStorage.setOrCreate<boolean>('sensorBatterySOCEnabled', false);
    AppStorage.setOrCreate<boolean>('sensorChargingStatusEnabled', false);
    AppStorage.setOrCreate<boolean>('sensorPluggedTypeEnabled', false);
    AppStorage.setOrCreate<boolean>('sensorBearerTypesEnabled', false);
    AppStorage.setOrCreate<boolean>('sensorLastUpdateTriggerEnabled', false);
    AppStorage.setOrCreate<boolean>('sensorLocationEnabled', false);
    AppStorage.setOrCreate<boolean>('sensorZoneBackgroundEnabled', false);
    AppStorage.setOrCreate<boolean>('sensorAccurateLocationEnabled', false);
    AppStorage.setOrCreate<string>('sensorDirectEnabledJson', '[]');
    AppStorage.setOrCreate<number>('sensorDefaultMigrationVersion', 4);
    AppStorage.setOrCreate<string>('sensorUpdateFrequency', SensorUpdateFrequency.NORMAL);
    AppStorage.setOrCreate<string>('locationHistoryJson', '[]');
    AppStorage.setOrCreate<string>('locationSentMode', 'never');
    AppStorage.setOrCreate<string>('locationDiagnosticsJson', '');
    AppStorage.setOrCreate<string>('locationGeofenceStatus', 'not_started');
  }
}
