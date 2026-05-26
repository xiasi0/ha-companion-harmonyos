// Builds and submits the Home Assistant mobile_app registration payload.
// Device identity, app version, webhook IDs, and registration errors are normalized here.
import deviceInfo from '@ohos.deviceInfo';
import {
  HaApiService,
  HaMobileAppRegistrationInfo,
  HaMobileAppRegistrationRequest,
  HaMobileAppRegistrationResult
} from '../../services/HaApiService';
import { AppVersionService } from '../../services/AppVersionService';
import { Localization } from '../../shared/i18n/Localization';

export class MobileAppRegistrationService {
  static readonly APP_ID: string = 'io.homeassistant.companion';

  static defaultDeviceName(): string {
    const marketName: string = deviceInfo.marketName ? deviceInfo.marketName.trim() : '';
    const productAlias: string = deviceInfo.productModelAlias ? deviceInfo.productModelAlias.trim() : '';
    const productModel: string = deviceInfo.productModel ? deviceInfo.productModel.trim() : '';
    const candidate: string = marketName.length > 0 ? marketName : (productAlias.length > 0 ? productAlias : productModel);
    return candidate.length > 0 ? candidate : 'HarmonyOS Device';
  }

  static buildRequest(deviceName: string, deviceId: string): HaMobileAppRegistrationRequest {
    return {
      appId: MobileAppRegistrationService.APP_ID,
      appName: 'Home Assistant',
      appVersion: AppVersionService.versionLabel(),
      deviceName: deviceName.trim(),
      manufacturer: MobileAppRegistrationService.deviceManufacturer(),
      model: MobileAppRegistrationService.deviceModelName(deviceName),
      osName: 'HarmonyOS',
      osVersion: MobileAppRegistrationService.osVersionLabel(),
      supportsEncryption: false,
      appData: {
        'push_websocket_channel': true
      },
      deviceId
    };
  }

  static async registerDevice(
    baseUrl: string,
    accessToken: string,
    request: HaMobileAppRegistrationRequest,
    refreshAccessToken: () => Promise<string>
  ): Promise<HaMobileAppRegistrationInfo> {
    let result: HaMobileAppRegistrationResult = await HaApiService.registerMobileAppDevice(
      baseUrl,
      accessToken,
      request
    );
    if (result.responseCode === 401) {
      const refreshedToken = await refreshAccessToken();
      if (refreshedToken.length > 0) {
        result = await HaApiService.registerMobileAppDevice(baseUrl, refreshedToken, request);
      }
    }

    if (result.responseCode < 200 || result.responseCode >= 300 || result.registration.webhookId.trim().length === 0) {
      throw new Error(MobileAppRegistrationService.failureMessage(result.failureSummary));
    }
    return result.registration;
  }

  static failureMessage(summary: string): string {
    if (summary.includes('HTTP 404')) {
      return Localization.t('registration_mobile_app_missing');
    }
    if (summary.includes('HTTP 401')) {
      return Localization.t('registration_login_expired');
    }
    return Localization.format('registration_failed', 'error', summary);
  }

  private static deviceManufacturer(): string {
    const manufacture = deviceInfo.manufacture ? deviceInfo.manufacture.trim() : '';
    const brand = deviceInfo.brand ? deviceInfo.brand.trim() : '';
    if (manufacture.length > 0) {
      return manufacture;
    }
    if (brand.length > 0) {
      return brand;
    }
    return 'HarmonyOS';
  }

  private static deviceModelName(deviceName: string): string {
    const productAlias = deviceInfo.productModelAlias ? deviceInfo.productModelAlias.trim() : '';
    const productModel = deviceInfo.productModel ? deviceInfo.productModel.trim() : '';
    const marketName = deviceInfo.marketName ? deviceInfo.marketName.trim() : '';
    if (productAlias.length > 0) {
      return productAlias;
    }
    if (productModel.length > 0) {
      return productModel;
    }
    if (marketName.length > 0) {
      return marketName;
    }
    return deviceName.trim().length > 0 ? deviceName.trim() : 'HarmonyOS Device';
  }

  private static osVersionLabel(): string {
    const distributionVersion = deviceInfo.distributionOSVersion ? deviceInfo.distributionOSVersion.trim() : '';
    const fullName = deviceInfo.osFullName ? deviceInfo.osFullName.trim() : '';
    const displayVersion = deviceInfo.displayVersion ? deviceInfo.displayVersion.trim() : '';
    if (distributionVersion.length > 0) {
      return distributionVersion;
    }
    if (fullName.length > 0) {
      return fullName;
    }
    if (displayVersion.length > 0) {
      return displayVersion;
    }
    return 'HarmonyOS NEXT';
  }
}
