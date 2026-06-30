import common from '@ohos.app.ability.common';
import { AppRoute } from './AppRoute';
import { HaServerItem } from '../models/HaServerItem';
import { OnboardingRuntimeActions, OnboardingRuntimeSnapshot } from '../features/onboarding/OnboardingRuntimeModels';
import { ConnectionError } from '../features/connection/ConnectionErrorModels';
import { AppSettingsStore } from '../services/AppSettingsStore';
import { NetworkService } from '../services/NetworkService';

export interface AppOnboardingRuntimeTarget {
  step: number;
  discoveredServers: HaServerItem[];
  showDiscoveredSheet: boolean;
  discoverySpinAngle: number;
  discoveryPulseScale: number;
  manualAddress: string;
  deviceName: string;
  haBaseUrl: string;
  secureConnectionChoice: string;
  homeNetworkName: string;
  homeWifiSsids: string[];
  prioritizeInternal: boolean;
  secureConnectionFromSettings: boolean;
  connectionErrorUrl: string;
  connectionErrorCode: number;
  connectionErrorDetail: string;
  connectionError: ConnectionError | undefined;
  message: string;
  context(): common.Context;
  onboardingContentMaxWidth(): number;
  setDiscoverySheetVisible(visible: boolean): void;
  startDiscoveryFlow(): void;
  handleBackNavigation(): boolean;
  selectServer(url: string): void;
  startDiscoveryAnimation(): void;
  stopDiscoveryAnimation(): void;
  connectManualAddress(): void;
  completeDeviceRegistration(): void;
  requestLocationPermissionAndEnable(reason: string, onFinished?: () => void): void;
  openDashboard(): void;
  retryOnboardingConnectionError(): void;
}

export class AppOnboardingRuntimeService {
  static snapshot(target: AppOnboardingRuntimeTarget): OnboardingRuntimeSnapshot {
    return {
      step: target.step,
      contentMaxWidth: target.onboardingContentMaxWidth(),
      discoveredServers: target.discoveredServers,
      showDiscoveredSheet: target.showDiscoveredSheet,
      discoverySpinAngle: target.discoverySpinAngle,
      discoveryPulseScale: target.discoveryPulseScale,
      manualAddress: target.manualAddress,
      deviceName: target.deviceName,
      haBaseUrl: target.haBaseUrl,
      secureConnectionChoice: target.secureConnectionChoice,
      homeNetworkName: target.homeNetworkName,
      secureConnectionFromSettings: target.secureConnectionFromSettings,
      connectionErrorUrl: target.connectionErrorUrl,
      connectionErrorCode: target.connectionErrorCode,
      connectionErrorDetail: target.connectionErrorDetail,
      connectionError: target.connectionError
    };
  }

  static actions(target: AppOnboardingRuntimeTarget): OnboardingRuntimeActions {
    return {
      onSetStep: (route: AppRoute): void => {
        target.step = route;
      },
      onSetMessage: (message: string): void => {
        target.message = message;
      },
      onSetDiscoverySheetVisible: (visible: boolean): void => target.setDiscoverySheetVisible(visible),
      onStartDiscoveryFlow: (): void => target.startDiscoveryFlow(),
      onHandleBackNavigation: (): void => {
        target.handleBackNavigation();
      },
      onSelectServer: (url: string): void => target.selectServer(url),
      onStartDiscoveryAnimation: (): void => target.startDiscoveryAnimation(),
      onStopDiscoveryAnimation: (): void => target.stopDiscoveryAnimation(),
      onManualAddressChange: (value: string): void => {
        target.manualAddress = value;
      },
      onManualConnect: (): void => target.connectManualAddress(),
      onDeviceNameChange: (value: string): void => {
        target.deviceName = value;
      },
      onCompleteDeviceRegistration: (): void => target.completeDeviceRegistration(),
      onRequestLocationAndEnable: (onFinished: () => void): void => {
        target.requestLocationPermissionAndEnable('onboarding_location_enabled', onFinished);
      },
      onSecureChoiceChange: (value: string): void => {
        target.secureConnectionChoice = value;
      },
      onOpenDashboard: (): void => target.openDashboard(),
      onHomeNetworkNameChange: (value: string): void => {
        target.homeNetworkName = value;
        target.homeWifiSsids = NetworkService.normalizeWifiSsids([value]);
        AppSettingsStore.saveHomeNetwork(
          target.context(),
          target.homeWifiSsids,
          target.prioritizeInternal
        ).catch((): void => {});
      },
      onClearSecureConnectionFromSettings: (): void => {
        target.secureConnectionFromSettings = false;
      },
      onRetryConnectionError: (): void => target.retryOnboardingConnectionError()
    };
  }
}
