// Main HarmonyOS ability entry for the phone application.
// It prepares the window and loads the ArkUI app shell.
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { HaBackgroundConnectionService } from '../features/background/HaBackgroundConnectionService';
import { LongRunningTaskService } from '../features/background/LongRunningTaskService';
import { HaLocationRuntimeService } from '../features/location/HaLocationRuntimeService';
import { AppStorageDefaults } from '../app/AppStorageDefaults';
import { AppSettingsStore } from '../services/AppSettingsStore';
import { DiscoveryCacheService } from '../services/DiscoveryCacheService';
import { HARMONY_GEOFENCE_ACTION } from '../services/HarmonyLocationService';
import { ServerManager } from '../services/ServerManager';
import { CardEntityDetailLaunchService } from '../features/cards/CardEntityDetailLaunchService';

const DOMAIN = 0x0000;
const TAG = 'HACompanion';

export default class EntryAbility extends UIAbility {
  private appStorageRestored: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorageDefaults.register();
    this.handleLocationWant(want);
    this.handleEntityDetailWant(want);
    LongRunningTaskService.setRecoveryHandler((context): void => {
      if ((AppStorage.get<string>('websocketMode') ?? 'system') !== 'always') {
        return;
      }
      HaBackgroundConnectionService.ensureRunning(context, true).catch((err: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Failed to recover background websocket. Cause: %{public}s', err.message);
      });
    });
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.handleLocationWant(want);
    this.handleEntityDetailWant(want);
  }

  onDestroy(): void {
    this.saveCurrentAppStorageIfRestored();
    if (!this.shouldKeepAnyLongRunningTask()) {
      HaBackgroundConnectionService.stop();
      HaLocationRuntimeService.stop();
      LongRunningTaskService.stop(this.context).catch((): void => {});
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.enableLayoutImmersive(windowStage);
    DiscoveryCacheService.warm(this.context);
    ServerManager.restoreActiveToAppStorage(this.context)
      .then((): Promise<void> => AppSettingsStore.restoreToAppStorage(this.context))
      .then((): void => {
        this.appStorageRestored = true;
      })
      .catch((err: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Failed to restore app state. Cause: %{public}s', err.message);
      })
      .finally((): void => {
        this.applyLongRunningTaskPreference(true);
        windowStage.loadContent('pages/Index', (err) => {
          if (err.code) {
            hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
            return;
          }
        });
      });
  }

  onWindowStageDestroy(): void {
  }

  private enableLayoutImmersive(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true).catch((): void => {});
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#172126',
        navigationBarContentColor: '#172126',
        isStatusBarLightIcon: false,
        isNavigationBarLightIcon: false
      }).catch((): void => {});
    } catch (_) {
    }
  }

  onForeground(): void {
    AppStorage.setOrCreate<number>('appForegroundTick', Date.now());
    this.applyLongRunningTaskPreference(true);
  }

  onConfigurationUpdate(_newConfig: Configuration): void {
    AppStorage.setOrCreate<number>('appConfigTick', Date.now());
  }

  onBackground(): void {
    this.saveCurrentAppStorageIfRestored();
    AppStorage.setOrCreate<number>('appBackgroundTick', Date.now());
    this.applyLongRunningTaskPreference(false);
  }

  private applyLongRunningTaskPreference(isForeground: boolean): void {
    if (!this.hasStoredLogin()) {
      HaBackgroundConnectionService.stop();
      HaLocationRuntimeService.stop();
      LongRunningTaskService.stop(this.context).catch((): void => {});
      return;
    }
    const websocketAlways = (AppStorage.get<string>('websocketMode') ?? 'system') === 'always';
    if (websocketAlways) {
      LongRunningTaskService.ensureActive(this.context)
        .then((): void => {
          HaBackgroundConnectionService.ensureRunning(this.context, true).catch((): void => {});
        })
        .catch((err: Error): void => {
          hilog.warn(DOMAIN, TAG, 'Failed to start long running task. Cause: %{public}s', err.message);
        });
      return;
    }
    LongRunningTaskService.stopDataTransfer(this.context).catch((): void => {});
    if (isForeground) {
      HaBackgroundConnectionService.ensureRunning(this.context, false).catch((err: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Failed to start foreground websocket. Cause: %{public}s', err.message);
      });
      return;
    }
    HaBackgroundConnectionService.stop();
  }

  private shouldKeepAnyLongRunningTask(): boolean {
    if (!this.hasStoredLogin()) {
      return false;
    }
    return (AppStorage.get<string>('websocketMode') ?? 'system') === 'always' ||
      ((AppStorage.get<boolean>('sensorLocationEnabled') ?? false) &&
        (AppStorage.get<boolean>('sensorAccurateLocationEnabled') ?? false));
  }

  private hasStoredLogin(): boolean {
    const baseUrl = AppStorage.get<string>('haBaseUrl') ?? '';
    const token = AppStorage.get<string>('haAccessToken') ?? '';
    return baseUrl.trim().length > 0 && token.trim().length > 0;
  }

  private handleLocationWant(want: Want): void {
    if (want.action !== HARMONY_GEOFENCE_ACTION) {
      return;
    }
    ServerManager.restoreActiveToAppStorage(this.context)
      .then((): Promise<void> => AppSettingsStore.restoreToAppStorage(this.context))
      .then((): void => {
        HaLocationRuntimeService.handleGeofenceWant(this.context);
      })
      .catch((err: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Failed to handle geofence want. Cause: %{public}s', err.message);
      });
  }

  private handleEntityDetailWant(want: Want): void {
    const request = CardEntityDetailLaunchService.requestFromWant(want);
    if (!request) {
      return;
    }
    CardEntityDetailLaunchService.publishPending(request);
    AppStorage.setOrCreate<number>('appForegroundTick', Date.now());
  }

  private saveCurrentAppStorageIfRestored(): void {
    if (!this.appStorageRestored) {
      return;
    }
    AppSettingsStore.saveCurrentAppStorage(this.context).catch((): void => {});
  }
}
