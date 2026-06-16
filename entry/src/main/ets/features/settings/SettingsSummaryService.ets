import { SensorUpdateFrequency } from '../sensors/SensorModels';
import { Localization } from '../../shared/i18n/Localization';

export class SettingsSummaryService {
  static serverDisplayName(serverNameOverride: string, configSummary: string): string {
    if (serverNameOverride.trim().length > 0) {
      return serverNameOverride.trim();
    }
    const name = configSummary === Localization.t('common_not_set')
      ? 'Home Assistant'
      : configSummary.split('|')[0].trim();
    return name.length > 0 ? name : 'Home Assistant';
  }

  static effectiveExternalUrl(serverExternalUrl: string, baseUrl: string): string {
    const externalUrl = serverExternalUrl.trim();
    if (externalUrl.length > 0) {
      return SettingsSummaryService.normalizeBaseUrl(externalUrl);
    }
    return SettingsSummaryService.normalizeBaseUrl(baseUrl);
  }

  static homeNetworkSummary(homeWifiSsids: string[]): string {
    let i = homeWifiSsids.length - 1;
    while (i >= 0) {
      const value = homeWifiSsids[i].trim();
      if (value.length > 0) {
        return value;
      }
      i -= 1;
    }
    return Localization.t('common_not_set');
  }

  static internalConnectionSummary(serverInternalUrl: string): string {
    return serverInternalUrl.trim().length > 0
      ? SettingsSummaryService.normalizeBaseUrl(serverInternalUrl)
      : Localization.t('common_not_set');
  }

  static sessionTimeoutSummary(sessionTimeout: string): string {
    const value = sessionTimeout.trim();
    if (value.length === 0 || value === '0') {
      return Localization.t('common_not_set');
    }
    return Localization.format('common_seconds', 'value', value);
  }

  static websocketSummary(websocketMode: string): string {
    if (websocketMode === 'always') {
      return Localization.t('common_always');
    }
    return Localization.t('server_websocket_system');
  }

  static securityLevelSummary(secureConnectionChoice: string): string {
    if (secureConnectionChoice === 'most') {
      return Localization.t('summary_security_most');
    }
    if (secureConnectionChoice === 'less') {
      return Localization.t('summary_security_less');
    }
    return Localization.t('summary_security_default');
  }

  static sensorUpdateFrequencySummary(sensorUpdateFrequency: string): string {
    if (sensorUpdateFrequency === SensorUpdateFrequency.FAST_WHILE_CHARGING) {
      return Localization.t('summary_sensor_fast_charging');
    }
    if (sensorUpdateFrequency === SensorUpdateFrequency.FAST_ALWAYS) {
      return Localization.t('summary_sensor_fast_always');
    }
    return Localization.t('common_normal');
  }

  private static normalizeBaseUrl(value: string): string {
    return value.trim().replace(/\/+$/, '');
  }
}
