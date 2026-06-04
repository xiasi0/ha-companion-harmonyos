// Legacy single-server storage helpers kept for migration and compatibility paths.
// New multi-server persistence should use ServerInstanceStore and related repositories.
import { Localization } from '../shared/i18n/Localization';

export interface StoredServerInfo {
  baseUrl: string;
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: number;
  deviceName: string;
  mobileAppDeviceId: string;
  webhookId: string;
  webhookSecret: string;
  cloudhookUrl: string;
  remoteUiUrl: string;
}

export class StorageService {
  static emptyServerInfo(): StoredServerInfo {
    return {
      baseUrl: '',
      accessToken: '',
      refreshToken: '',
      accessTokenExpiresAt: 0,
      deviceName: '',
      mobileAppDeviceId: '',
      webhookId: '',
      webhookSecret: '',
      cloudhookUrl: '',
      remoteUiUrl: ''
    };
  }

  static serverInfo(
    baseUrl: string,
    accessToken: string,
    refreshToken: string,
    accessTokenExpiresAt: number,
    deviceName: string,
    mobileAppDeviceId: string,
    webhookId: string,
    webhookSecret: string,
    cloudhookUrl: string,
    remoteUiUrl: string
  ): StoredServerInfo {
    return {
      baseUrl,
      accessToken,
      refreshToken,
      accessTokenExpiresAt,
      deviceName,
      mobileAppDeviceId,
      webhookId,
      webhookSecret,
      cloudhookUrl,
      remoteUiUrl
    };
  }

  static hasLogin(info: StoredServerInfo): boolean {
    return info.baseUrl.trim().length > 0 && info.accessToken.trim().length > 0;
  }

  static hasCredentials(info: StoredServerInfo): boolean {
    return info.baseUrl.trim().length > 0 &&
      (info.accessToken.trim().length > 0 || info.refreshToken.trim().length > 0);
  }

  static storageStatus(info: StoredServerInfo): string {
    if (StorageService.hasLogin(info)) {
      return Localization.t('storage_saved');
    }
    return Localization.t('storage_not_saved');
  }

  static accessTokenExpiresAt(expiresInSeconds: number): number {
    return expiresInSeconds > 0 ? Date.now() + expiresInSeconds * 1000 : 0;
  }

  static applyLogin(target: StoredServerInfo, baseUrl: string, accessToken: string, refreshToken: string, accessTokenExpiresAt: number = 0): StoredServerInfo {
    return {
      baseUrl,
      accessToken,
      refreshToken,
      accessTokenExpiresAt,
      deviceName: target.deviceName,
      mobileAppDeviceId: target.mobileAppDeviceId,
      webhookId: '',
      webhookSecret: '',
      cloudhookUrl: '',
      remoteUiUrl: ''
    };
  }

  static applyRefresh(target: StoredServerInfo, accessToken: string, refreshToken: string, accessTokenExpiresAt: number = 0): StoredServerInfo {
    return {
      baseUrl: target.baseUrl,
      accessToken,
      refreshToken: refreshToken.length > 0 ? refreshToken : target.refreshToken,
      accessTokenExpiresAt,
      deviceName: target.deviceName,
      mobileAppDeviceId: target.mobileAppDeviceId,
      webhookId: target.webhookId,
      webhookSecret: target.webhookSecret,
      cloudhookUrl: target.cloudhookUrl,
      remoteUiUrl: target.remoteUiUrl
    };
  }

  static applyServer(target: StoredServerInfo, baseUrl: string): StoredServerInfo {
    return {
      baseUrl,
      accessToken: target.accessToken,
      refreshToken: target.refreshToken,
      accessTokenExpiresAt: target.accessTokenExpiresAt,
      deviceName: target.deviceName,
      mobileAppDeviceId: target.mobileAppDeviceId,
      webhookId: target.webhookId,
      webhookSecret: target.webhookSecret,
      cloudhookUrl: target.cloudhookUrl,
      remoteUiUrl: target.remoteUiUrl
    };
  }

  static applyDeviceName(target: StoredServerInfo, deviceName: string): StoredServerInfo {
    return {
      baseUrl: target.baseUrl,
      accessToken: target.accessToken,
      refreshToken: target.refreshToken,
      accessTokenExpiresAt: target.accessTokenExpiresAt,
      deviceName,
      mobileAppDeviceId: target.mobileAppDeviceId,
      webhookId: target.webhookId,
      webhookSecret: target.webhookSecret,
      cloudhookUrl: target.cloudhookUrl,
      remoteUiUrl: target.remoteUiUrl
    };
  }

  static applyRegistration(
    target: StoredServerInfo,
    webhookId: string,
    webhookSecret: string,
    cloudhookUrl: string,
    remoteUiUrl: string
  ): StoredServerInfo {
    return {
      baseUrl: target.baseUrl,
      accessToken: target.accessToken,
      refreshToken: target.refreshToken,
      accessTokenExpiresAt: target.accessTokenExpiresAt,
      deviceName: target.deviceName,
      mobileAppDeviceId: target.mobileAppDeviceId,
      webhookId,
      webhookSecret,
      cloudhookUrl,
      remoteUiUrl
    };
  }

  static clearLogin(target: StoredServerInfo): StoredServerInfo {
    return {
      baseUrl: '',
      accessToken: '',
      refreshToken: '',
      accessTokenExpiresAt: 0,
      deviceName: target.deviceName,
      mobileAppDeviceId: target.mobileAppDeviceId,
      webhookId: '',
      webhookSecret: '',
      cloudhookUrl: '',
      remoteUiUrl: ''
    };
  }
}
