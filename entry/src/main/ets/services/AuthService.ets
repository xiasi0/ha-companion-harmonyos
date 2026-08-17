// Home Assistant OAuth helper for authorization URL and token exchange.
// Keep OAuth request construction and response validation in this service.
import { Localization } from '../shared/i18n/Localization';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { NetworkHttpMethod, NetworkService } from './NetworkService';

const DOMAIN = 0x0000;
const TAG = 'HAAuth';

export interface AuthTokenResult {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface RefreshTokenResult {
  success: boolean;
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export class AuthService {
  static getClientId(baseUrl: string): string {
    return NetworkService.ANDROID_CLIENT_ID;
  }

  static getAppRedirectUri(baseUrl: string): string {
    return 'homeassistant://auth-callback';
  }

  static buildAuthorizeUrl(baseUrl: string, state: string): string {
    const clientId = AuthService.getClientId(baseUrl);
    const redirectUri = AuthService.getAppRedirectUri(baseUrl);
    return `${baseUrl}/auth/authorize?response_type=code&client_id=${encodeURIComponent(clientId)}&redirect_uri=${encodeURIComponent(redirectUri)}&state=${encodeURIComponent(state)}`;
  }

  static async exchangeCodeForToken(baseUrl: string, code: string): Promise<AuthTokenResult> {
    const body = [
      'grant_type=authorization_code',
      `code=${encodeURIComponent(code)}`,
      `client_id=${encodeURIComponent(AuthService.getClientId(baseUrl))}`
    ].join('&');

    const resp = await NetworkService.requestText(`${baseUrl}/auth/token`, {
      method: NetworkHttpMethod.POST,
      header: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      extraData: body,
      connectTimeout: 20000,
      readTimeout: 20000
    });

    if (resp.responseCode < 200 || resp.responseCode >= 300) {
      throw new Error(Localization.format2(
        'auth_token_http_failed',
        'code',
        resp.responseCode,
        'body',
        NetworkService.shortText(resp.body)
      ));
    }

    const parsed = JSON.parse(resp.body) as Record<string, string>;
    const accessToken = parsed['access_token'];
    if (!accessToken) {
      throw new Error(Localization.format('auth_missing_access_token', 'body', NetworkService.shortText(resp.body)));
    }

    return {
      accessToken,
      refreshToken: parsed['refresh_token'] ?? '',
      expiresIn: AuthService.expiresIn(parsed)
    };
  }

  static async refreshAccessToken(baseUrl: string, refreshToken: string): Promise<RefreshTokenResult> {
    const refresh = refreshToken.trim();
    if (!refresh) {
      return {
        success: false,
        accessToken: '',
        refreshToken: '',
        expiresIn: 0
      };
    }

    try {
      const body = [
        'grant_type=refresh_token',
        `refresh_token=${encodeURIComponent(refresh)}`,
        `client_id=${encodeURIComponent(AuthService.getClientId(baseUrl))}`
      ].join('&');

      const resp = await NetworkService.requestText(`${baseUrl}/auth/token`, {
        method: NetworkHttpMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        extraData: body,
        connectTimeout: 20000,
        readTimeout: 20000
      });

      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        hilog.warn(DOMAIN, TAG, 'refresh token request rejected. status=%{public}d', resp.responseCode);
        return {
          success: false,
          accessToken: '',
          refreshToken: '',
          expiresIn: 0
        };
      }

      const parsed = JSON.parse(resp.body) as Record<string, string>;
      const accessToken = parsed['access_token'];
      if (!accessToken) {
        hilog.warn(DOMAIN, TAG, 'refresh token response missing access token');
        return {
          success: false,
          accessToken: '',
          refreshToken: '',
          expiresIn: 0
        };
      }

      return {
        success: true,
        accessToken,
        refreshToken: parsed['refresh_token'] ?? '',
        expiresIn: AuthService.expiresIn(parsed)
      };
    } catch (_) {
      hilog.warn(DOMAIN, TAG, 'refresh token request failed');
      return {
        success: false,
        accessToken: '',
        refreshToken: '',
        expiresIn: 0
      };
    }
  }

  static async revokeSession(baseUrl: string, refreshToken: string): Promise<boolean> {
    const refresh = refreshToken.trim();
    if (!baseUrl || !refresh) {
      return false;
    }

    try {
      const modernBody = `token=${encodeURIComponent(refresh)}`;
      const modernResp = await NetworkService.requestText(`${baseUrl}/auth/revoke`, {
        method: NetworkHttpMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        extraData: modernBody,
        connectTimeout: 10000,
        readTimeout: 10000
      });
      if (modernResp.responseCode >= 200 && modernResp.responseCode < 300) {
        return true;
      }

      const legacyBody = [
        `token=${encodeURIComponent(refresh)}`,
        'action=revoke'
      ].join('&');
      const legacyResp = await NetworkService.requestText(`${baseUrl}/auth/token`, {
        method: NetworkHttpMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        extraData: legacyBody,
        connectTimeout: 10000,
        readTimeout: 10000
      });
      return legacyResp.responseCode >= 200 && legacyResp.responseCode < 300;
    } catch (_) {
      return false;
    }
  }

  private static expiresIn(parsed: Record<string, string>): number {
    const raw = parsed['expires_in'];
    if (typeof raw !== 'string') {
      return 0;
    }
    const value = Number.parseInt(raw, 10);
    return Number.isFinite(value) && value > 0 ? value : 0;
  }

}
