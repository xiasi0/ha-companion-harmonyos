import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pushService } from '@kit.PushKit';

const DOMAIN = 0x0000;
const TAG = 'HAPushKitToken';

export class HarmonyPushTokenService {
  private static cachedToken: string = '';

  static async ensureToken(): Promise<string> {
    if (HarmonyPushTokenService.cachedToken.length > 0) {
      return HarmonyPushTokenService.cachedToken;
    }
    return HarmonyPushTokenService.requestToken();
  }

  private static async requestToken(): Promise<string> {
    try {
      const token = (await pushService.getToken()).trim();
      HarmonyPushTokenService.cachedToken = token;
      return token;
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, 'Push Kit token unavailable: %{public}d %{public}s', err.code, err.message);
      return '';
    }
  }
}
