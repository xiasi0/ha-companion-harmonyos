import { AppRoute } from '../../app/AppRoute';
import { HaServerItem } from '../../models/HaServerItem';
import { ConnectionError } from '../connection/ConnectionErrorModels';

export interface OnboardingRuntimeSnapshot {
  step: number;
  contentMaxWidth: number;
  discoveredServers: HaServerItem[];
  showDiscoveredSheet: boolean;
  discoverySpinAngle: number;
  discoveryPulseScale: number;
  manualAddress: string;
  deviceName: string;
  haBaseUrl: string;
  secureConnectionChoice: string;
  homeNetworkName: string;
  secureConnectionFromSettings: boolean;
  connectionErrorUrl: string;
  connectionErrorCode: number;
  connectionErrorDetail: string;
  connectionError: ConnectionError | undefined;
}

export interface OnboardingRuntimeActions {
  onSetStep: (route: AppRoute) => void;
  onSetMessage: (message: string) => void;
  onSetDiscoverySheetVisible: (visible: boolean) => void;
  onStartDiscoveryFlow: () => void;
  onHandleBackNavigation: () => void;
  onSelectServer: (url: string) => void;
  onStartDiscoveryAnimation: () => void;
  onStopDiscoveryAnimation: () => void;
  onManualAddressChange: (value: string) => void;
  onManualConnect: () => void;
  onDeviceNameChange: (value: string) => void;
  onCompleteDeviceRegistration: () => void;
  onRequestLocationAndEnable: (onFinished: () => void) => void;
  onSecureChoiceChange: (value: string) => void;
  onOpenDashboard: () => void;
  onHomeNetworkNameChange: (value: string) => void;
  onClearSecureConnectionFromSettings: () => void;
  onRetryConnectionError: () => void;
}
