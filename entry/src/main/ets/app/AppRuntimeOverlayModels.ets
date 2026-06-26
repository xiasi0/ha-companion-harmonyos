import { DeviceProfileInfo } from '../shared/device/DeviceProfile';
import { SensorGroup } from '../features/sensors/SensorModels';

export interface AppRuntimeOverlaySnapshot {
  route: number;
  baseUrl: string;
  accessToken: string;
  refreshToken: string;
  assistStartListeningSignal: number;
  assistStartListeningRequested: boolean;
  profile: DeviceProfileInfo;
  sensorGroups: SensorGroup[];
  directSensorIds: string[];
  healthAuthorizationState: string;
  sensorUpdateFrequency: string;
  contentMaxWidth: number;
}

export interface AppRuntimeOverlayActions {
  onRoute: (route: number) => void;
  onBackToNativeTarget: () => void;
  onSwipeBack: () => void;
  onCloseAssist: () => void;
  onSensorHelp: () => void;
  onSensorSearch: () => void;
  onSensorFilter: () => void;
  onToggleSensor: (id: string, enabled: boolean) => void;
  onOpenHealthSensors: (onAuthorized: () => void) => void;
  onSelectSensorFrequency: (value: string) => void;
}
