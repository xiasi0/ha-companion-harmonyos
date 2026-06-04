// Chooses the best Home Assistant URL for the current network and trust policy.
// Dashboard, background, and sensor flows should reuse this logic before making requests.
import common from '@ohos.app.ability.common';
import { AppSettingsStore } from './AppSettingsStore';
import { HomeNetworkService } from './HomeNetworkService';
import { NetworkService } from './NetworkService';
import { ServerManager } from './ServerManager';
import { StorageService } from './StorageService';

export interface HaConnectionPolicyResult {
  allowed: boolean;
  baseUrl: string;
  reason: string;
  missingHomeSetup: boolean;
}

class HaConnectionPolicyPayload implements HaConnectionPolicyResult {
  allowed: boolean = false;
  baseUrl: string = '';
  reason: string = '';
  missingHomeSetup: boolean = false;
}

export class HaConnectionPolicyService {
  static async resolveServerBaseUrl(
    context: common.Context,
    serverInstanceId: string
  ): Promise<HaConnectionPolicyResult> {
    const id = serverInstanceId.trim();
    if (id.length === 0) {
      return HaConnectionPolicyService.blocked('missing_server', false);
    }
    const info = await ServerManager.getServerInfo(context, id);
    if (!StorageService.hasCredentials(info)) {
      return HaConnectionPolicyService.blocked('missing_login', false);
    }
    const settings = await AppSettingsStore.loadServerConnectionPolicySettings(context, id);
    const snapshot = await NetworkService.wirelessSnapshot().catch(() => HomeNetworkService.emptyWirelessSnapshot());
    const resolution = HomeNetworkService.resolveBaseUrl({
      externalUrl: settings.externalUrl.length > 0 ? settings.externalUrl : info.baseUrl,
      internalUrl: settings.internalUrl,
      secureConnectionChoice: settings.secureConnectionChoice,
      settings: settings.homeNetwork,
      snapshot: snapshot
    });
    if (resolution.kind !== 'success' || resolution.url.length === 0) {
      return HaConnectionPolicyService.blocked(resolution.reason, resolution.missingHomeSetup);
    }
    const result = new HaConnectionPolicyPayload();
    result.allowed = true;
    result.baseUrl = resolution.url;
    result.reason = resolution.reason;
    result.missingHomeSetup = resolution.missingHomeSetup;
    return result;
  }

  private static blocked(reason: string, missingHomeSetup: boolean): HaConnectionPolicyResult {
    const result = new HaConnectionPolicyPayload();
    result.allowed = false;
    result.reason = reason;
    result.missingHomeSetup = missingHomeSetup;
    return result;
  }
}
