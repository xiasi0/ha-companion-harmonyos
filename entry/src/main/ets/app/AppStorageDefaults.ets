import { SensorUpdateFrequency } from '../features/sensors/SensorModels';

export class AppStorageDefaults {
  private static registered: boolean = false;

  static register(): void {
    if (AppStorageDefaults.registered) {
      return;
    }
    AppStorageDefaults.registered = true;
    AppStorage.setOrCreate<string>('haBaseUrl', AppStorage.get<string>('haBaseUrl') ?? '');
    AppStorage.setOrCreate<string>('haAccessToken', AppStorage.get<string>('haAccessToken') ?? '');
    AppStorage.setOrCreate<string>('haRefreshToken', AppStorage.get<string>('haRefreshToken') ?? '');
    AppStorage.setOrCreate<string>('haWebhookId', AppStorage.get<string>('haWebhookId') ?? '');
    AppStorage.setOrCreate<string>('haWebhookSecret', AppStorage.get<string>('haWebhookSecret') ?? '');
    AppStorage.setOrCreate<string>('haCloudhookUrl', AppStorage.get<string>('haCloudhookUrl') ?? '');
    AppStorage.setOrCreate<string>('haRemoteUiUrl', AppStorage.get<string>('haRemoteUiUrl') ?? '');
    AppStorage.setOrCreate<string>('haMobileAppDeviceId', AppStorage.get<string>('haMobileAppDeviceId') ?? '');
    AppStorage.setOrCreate<string>('serverNameOverride', AppStorage.get<string>('serverNameOverride') ?? '');
    AppStorage.setOrCreate<string>('serverExternalUrl', AppStorage.get<string>('serverExternalUrl') ?? '');
    AppStorage.setOrCreate<string>('serverInternalUrl', AppStorage.get<string>('serverInternalUrl') ?? '');
    AppStorage.setOrCreate<string>('secureConnectionChoice', AppStorage.get<string>('secureConnectionChoice') ?? '');
    AppStorage.setOrCreate<string>('homeNetworkName', AppStorage.get<string>('homeNetworkName') ?? '');
    AppStorage.setOrCreate<boolean>('trustServer', AppStorage.get<boolean>('trustServer') ?? false);
    AppStorage.setOrCreate<boolean>('appLockEnabled', AppStorage.get<boolean>('appLockEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('appLockHomeBypass', AppStorage.get<boolean>('appLockHomeBypass') ?? false);
    AppStorage.setOrCreate<string>('sessionTimeout', AppStorage.get<string>('sessionTimeout') ?? '0');
    AppStorage.setOrCreate<string>('websocketMode', AppStorage.get<string>('websocketMode') ?? 'system');
    AppStorage.setOrCreate<boolean>('sensorBatterySOCEnabled', AppStorage.get<boolean>('sensorBatterySOCEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('sensorChargingStatusEnabled', AppStorage.get<boolean>('sensorChargingStatusEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('sensorPluggedTypeEnabled', AppStorage.get<boolean>('sensorPluggedTypeEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('sensorBearerTypesEnabled', AppStorage.get<boolean>('sensorBearerTypesEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('sensorLastUpdateTriggerEnabled', AppStorage.get<boolean>('sensorLastUpdateTriggerEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('sensorLocationEnabled', AppStorage.get<boolean>('sensorLocationEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('sensorZoneBackgroundEnabled', AppStorage.get<boolean>('sensorZoneBackgroundEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('sensorAccurateLocationEnabled', AppStorage.get<boolean>('sensorAccurateLocationEnabled') ?? false);
    AppStorage.setOrCreate<string>('sensorDirectEnabledJson', AppStorage.get<string>('sensorDirectEnabledJson') ?? '[]');
    AppStorage.setOrCreate<number>('healthAuthorizationCheckedAt', AppStorage.get<number>('healthAuthorizationCheckedAt') ?? 0);
    AppStorage.setOrCreate<string>('healthLastError', AppStorage.get<string>('healthLastError') ?? '');
    AppStorage.setOrCreate<number>('healthLastSyncAt', AppStorage.get<number>('healthLastSyncAt') ?? 0);
    AppStorage.setOrCreate<string>('locationHistoryJson', AppStorage.get<string>('locationHistoryJson') ?? '[]');
    AppStorage.setOrCreate<string>('locationSentMode', AppStorage.get<string>('locationSentMode') ?? 'never');
    AppStorage.setOrCreate<string>('locationDiagnosticsJson', AppStorage.get<string>('locationDiagnosticsJson') ?? '');
    AppStorage.setOrCreate<string>('locationGeofenceStatus', AppStorage.get<string>('locationGeofenceStatus') ?? 'not_started');
    AppStorage.setOrCreate<string>('lastUpdateTrigger', AppStorage.get<string>('lastUpdateTrigger') ?? 'unknown');
    AppStorage.setOrCreate<boolean>('appActive', AppStorage.get<boolean>('appActive') ?? false);
    AppStorage.setOrCreate<number>('sensorDefaultMigrationVersion', AppStorage.get<number>('sensorDefaultMigrationVersion') ?? 0);
    AppStorage.setOrCreate<string>('sensorUpdateFrequency', AppStorage.get<string>('sensorUpdateFrequency') ?? SensorUpdateFrequency.NORMAL);
    AppStorage.setOrCreate<boolean>('fullScreenEnabled', AppStorage.get<boolean>('fullScreenEnabled') ?? false);
    AppStorage.setOrCreate<string>('screenOrientation', AppStorage.get<string>('screenOrientation') ?? 'system');
    AppStorage.setOrCreate<boolean>('keepScreenOnEnabled', AppStorage.get<boolean>('keepScreenOnEnabled') ?? false);
    AppStorage.setOrCreate<string>('pageZoomLevel', AppStorage.get<string>('pageZoomLevel') ?? '100');
    AppStorage.setOrCreate<boolean>('pinchToZoomEnabled', AppStorage.get<boolean>('pinchToZoomEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('autoPlayVideoEnabled', AppStorage.get<boolean>('autoPlayVideoEnabled') ?? false);
    AppStorage.setOrCreate<boolean>('alwaysShowFirstViewOnAppStartEnabled', AppStorage.get<boolean>('alwaysShowFirstViewOnAppStartEnabled') ?? false);
    AppStorage.setOrCreate<string>('appLanguage', AppStorage.get<string>('appLanguage') ?? 'default');
    AppStorage.setOrCreate<string>('appTheme', AppStorage.get<string>('appTheme') ?? 'system');
    AppStorage.setOrCreate<string>('serviceCardUpdateFrequency', AppStorage.get<string>('serviceCardUpdateFrequency') ?? 'default');
    AppStorage.setOrCreate<boolean>('assistWakeDetectionEnabled', AppStorage.get<boolean>('assistWakeDetectionEnabled') ?? true);
    AppStorage.setOrCreate<string>('assistWakeWord', AppStorage.get<string>('assistWakeWord') ?? 'wake_word_1');
    AppStorage.setOrCreate<string>('assistProbabilityCutoff', AppStorage.get<string>('assistProbabilityCutoff') ?? '');
    AppStorage.setOrCreate<boolean>('appResolvedDark', AppStorage.get<boolean>('appResolvedDark') ?? false);
    AppStorage.setOrCreate<number>('appConfigTick', AppStorage.get<number>('appConfigTick') ?? 0);
    AppStorage.setOrCreate<number>('notificationUnreadCount', AppStorage.get<number>('notificationUnreadCount') ?? 0);
    AppStorage.setOrCreate<number>('notificationHistoryRevision', AppStorage.get<number>('notificationHistoryRevision') ?? 0);
    AppStorage.setOrCreate<string>('gestureSwipeLeftTwoAction', AppStorage.get<string>('gestureSwipeLeftTwoAction') ?? 'none');
    AppStorage.setOrCreate<string>('gestureSwipeLeftThreeAction', AppStorage.get<string>('gestureSwipeLeftThreeAction') ?? 'none');
    AppStorage.setOrCreate<string>('gestureSwipeRightTwoAction', AppStorage.get<string>('gestureSwipeRightTwoAction') ?? 'none');
    AppStorage.setOrCreate<string>('gestureSwipeRightThreeAction', AppStorage.get<string>('gestureSwipeRightThreeAction') ?? 'none');
    AppStorage.setOrCreate<string>('gestureSwipeUpTwoAction', AppStorage.get<string>('gestureSwipeUpTwoAction') ?? 'none');
    AppStorage.setOrCreate<string>('gestureSwipeUpThreeAction', AppStorage.get<string>('gestureSwipeUpThreeAction') ?? 'none');
    AppStorage.setOrCreate<string>('gestureSwipeDownTwoAction', AppStorage.get<string>('gestureSwipeDownTwoAction') ?? 'none');
    AppStorage.setOrCreate<string>('gestureSwipeDownThreeAction', AppStorage.get<string>('gestureSwipeDownThreeAction') ?? 'none');
    AppStorage.setOrCreate<string>('assistAgentId', AppStorage.get<string>('assistAgentId') ?? '');
    AppStorage.setOrCreate<string>('cardEditCardType', AppStorage.get<string>('cardEditCardType') ?? '');
    AppStorage.setOrCreate<string>('cardPendingEntityDetailEntityId', AppStorage.get<string>('cardPendingEntityDetailEntityId') ?? '');
    AppStorage.setOrCreate<string>('cardPendingEntityDetailServerInstanceId', AppStorage.get<string>('cardPendingEntityDetailServerInstanceId') ?? '');
    AppStorage.setOrCreate<number>('cardPendingEntityDetailTick', AppStorage.get<number>('cardPendingEntityDetailTick') ?? 0);
  }
}
