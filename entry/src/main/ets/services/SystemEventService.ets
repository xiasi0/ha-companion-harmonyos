import commonEventManager from '@ohos.commonEventManager';
import audio from '@ohos.multimedia.audio';
import bluetoothAccess from '@ohos.bluetooth.access';
import display from '@ohos.display';
import motion from '@ohos.multimodalAwareness.motion';
import nfcController from '@ohos.nfc.controller';
import sensor from '@ohos.sensor';
import { NetworkNetConnection, NetworkService } from './NetworkService';

interface HardwareSensorValues {
  light?: number;
  lightColorTemperature?: number;
  lightInfraredLuminance?: number;
  pressure?: number;
  proximity?: number;
  steps?: number;
  stepDetected?: boolean;
  updatedAt?: number;
}

interface MultimodalSensorValues {
  operatingHand?: number;
  holdingHand?: number;
  updatedAt?: number;
}

export class SystemEventService {
  private static readonly POWER_AND_SCREEN_SENSOR_IDS: string[] = [
    'is_interactive',
    'is_idle',
    'power_save',
    'display_state'
  ];
  private batteryEventSubscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;
  private directEventSubscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;
  private directEventSubscriberPending: boolean = false;
  private directEventSubscriberRequestId: number = 0;
  private netConnection: NetworkNetConnection | undefined = undefined;
  private wirelessChanged: (() => void) | undefined = undefined;
  private bluetoothChanged: ((state: bluetoothAccess.BluetoothState) => void) | undefined = undefined;
  private nfcChanged: ((state: nfcController.NfcState) => void) | undefined = undefined;
  private displayChanged: ((displayId: number) => void) | undefined = undefined;
  private displayFoldChanged: ((status: display.FoldStatus) => void) | undefined = undefined;
  private displayFoldModeChanged: ((mode: display.FoldDisplayMode) => void) | undefined = undefined;
  private audioVolumeChanged: ((event: audio.StreamVolumeEvent) => void) | undefined = undefined;
  private audioRingerChanged: ((mode: audio.AudioRingMode) => void) | undefined = undefined;
  private audioDeviceChanged: ((event: audio.DeviceChangeAction) => void) | undefined = undefined;
  private audioSceneChanged: ((scene: audio.AudioScene) => void) | undefined = undefined;
  private lightChanged: ((event: sensor.LightResponse) => void) | undefined = undefined;
  private pressureChanged: ((event: sensor.BarometerResponse) => void) | undefined = undefined;
  private proximityChanged: ((event: sensor.ProximityResponse) => void) | undefined = undefined;
  private stepsChanged: ((event: sensor.PedometerResponse) => void) | undefined = undefined;
  private operatingHandChanged: ((status: motion.OperatingHandStatus) => void) | undefined = undefined;
  private holdingHandChanged: ((status: motion.HoldingHandStatus) => void) | undefined = undefined;
  private directSensorEventHandler: ((reason: string) => void) | undefined = undefined;
  private hardwareSensorEventHandler: ((reason: string) => void) | undefined = undefined;

  subscribeBatteryEvents(onChanged: () => void): void {
    if (this.batteryEventSubscriber) {
      return;
    }
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [
        commonEventManager.Support.COMMON_EVENT_BATTERY_CHANGED,
        commonEventManager.Support.COMMON_EVENT_POWER_CONNECTED,
        commonEventManager.Support.COMMON_EVENT_POWER_DISCONNECTED,
        commonEventManager.Support.COMMON_EVENT_CHARGING,
        commonEventManager.Support.COMMON_EVENT_DISCHARGING
      ]
    };
    commonEventManager.createSubscriber(subscribeInfo)
      .then((subscriber: commonEventManager.CommonEventSubscriber): Promise<void> => {
        this.batteryEventSubscriber = subscriber;
        return commonEventManager.subscribeToEvent(subscriber, (): void => {
          onChanged();
        });
      })
      .catch((): void => {});
  }

  unsubscribeBatteryEvents(): void {
    if (!this.batteryEventSubscriber) {
      return;
    }
    const subscriber = this.batteryEventSubscriber;
    this.batteryEventSubscriber = undefined;
    commonEventManager.unsubscribe(subscriber, () => {});
  }

  subscribeNetworkEvents(onChanged: () => void): void {
    if (this.netConnection || this.wirelessChanged) {
      return;
    }
    this.wirelessChanged = onChanged;
    NetworkService.subscribeWirelessEvents(onChanged);
    try {
      const netConnection = NetworkService.createNetConnection();
      netConnection.on('netAvailable', onChanged);
      netConnection.on('netLost', onChanged);
      netConnection.on('netCapabilitiesChange', onChanged);
      netConnection.register((): void => {});
      this.netConnection = netConnection;
    } catch (_) {
    }
  }

  unsubscribeNetworkEvents(): void {
    if (this.wirelessChanged) {
      NetworkService.unsubscribeWirelessEvents(this.wirelessChanged);
      this.wirelessChanged = undefined;
    }
    if (!this.netConnection) {
      return;
    }
    const netConnection = this.netConnection;
    this.netConnection = undefined;
    try {
      netConnection.unregister((): void => {});
    } catch (_) {
    }
  }

  subscribeDirectSensorEvents(onChanged: (reason: string) => void): void {
    this.directSensorEventHandler = onChanged;
    this.refreshDirectSensorEvents();
  }

  subscribeHardwareSensorEvents(onChanged: (reason: string) => void): void {
    this.hardwareSensorEventHandler = onChanged;
    this.refreshHardwareSensorEvents();
  }

  refreshSensorEventSubscriptions(): void {
    this.refreshDirectSensorEvents();
    this.refreshHardwareSensorEvents();
  }

  unsubscribeDirectSensorEvents(): void {
    this.directSensorEventHandler = undefined;
    this.hardwareSensorEventHandler = undefined;
    this.unsubscribePowerAndScreenEvents();
    this.unsubscribeBluetoothEvents();
    this.unsubscribeNfcEvents();
    this.unsubscribeDisplayEvents();
    this.unsubscribeAudioEvents();
    this.unsubscribeMultimodalEvents();
    this.unsubscribeHardwareSensorEvents();
  }

  unsubscribeAll(): void {
    this.unsubscribeBatteryEvents();
    this.unsubscribeNetworkEvents();
    this.unsubscribeDirectSensorEvents();
  }

  private unsubscribeHardwareSensorEvents(): void {
    this.unsubscribeLightSensor();
    this.unsubscribePressureSensor();
    this.unsubscribeProximitySensor();
    this.unsubscribeStepsSensor();
  }

  private refreshDirectSensorEvents(): void {
    const onChanged = this.directSensorEventHandler;
    if (!onChanged) {
      return;
    }
    if (this.anyDirectSensorEnabled(SystemEventService.POWER_AND_SCREEN_SENSOR_IDS)) {
      this.subscribePowerAndScreenEvents(onChanged);
    } else {
      this.unsubscribePowerAndScreenEvents();
    }
    if (this.anyDirectSensorEnabled(['bluetooth_state'])) {
      this.subscribeBluetoothEvents(onChanged);
    } else {
      this.unsubscribeBluetoothEvents();
    }
    if (this.anyDirectSensorEnabled(['nfc_state'])) {
      this.subscribeNfcEvents(onChanged);
    } else {
      this.unsubscribeNfcEvents();
    }
    if (this.anyDirectSensorEnabled([
      'screen_orientation',
      'screen_rotation',
      'screen_resolution',
      'display_refresh_rate',
      'display_density',
      'screen_brightness',
      'display_brightness_headroom',
      'harmony_screen_shape',
      'harmony_display_hdr_formats',
      'harmony_foldable',
      'harmony_fold_status',
      'harmony_fold_display_mode'
    ])) {
      this.subscribeDisplayEvents(onChanged);
    } else {
      this.unsubscribeDisplayEvents();
    }
    if (this.anyDirectSensorEnabled([
      'audio_sensor',
      'audio_mode',
      'headphone_state',
      'speakerphone_state',
      'volume_alarm',
      'volume_call',
      'volume_music',
      'volume_ring',
      'volume_notification',
      'volume_accessibility'
    ])) {
      this.subscribeAudioEvents(onChanged);
    } else {
      this.unsubscribeAudioEvents();
    }
    if (this.anyDirectSensorEnabled(['harmony_operating_hand', 'harmony_holding_hand'])) {
      this.subscribeMultimodalEvents(onChanged);
    } else {
      this.unsubscribeMultimodalEvents();
    }
  }

  private refreshHardwareSensorEvents(): void {
    const onChanged = this.hardwareSensorEventHandler;
    if (!onChanged) {
      return;
    }
    if (this.isDirectSensorEnabled('light_sensor')) {
      this.subscribeLightSensor(onChanged);
    } else {
      this.unsubscribeLightSensor();
    }
    if (this.isDirectSensorEnabled('pressure_sensor')) {
      this.subscribePressureSensor(onChanged);
    } else {
      this.unsubscribePressureSensor();
    }
    if (this.isDirectSensorEnabled('proximity_sensor')) {
      this.subscribeProximitySensor(onChanged);
    } else {
      this.unsubscribeProximitySensor();
    }
    if (this.isDirectSensorEnabled('steps_sensor')) {
      this.subscribeStepsSensor(onChanged);
    } else {
      this.unsubscribeStepsSensor();
    }
  }

  private unsubscribeLightSensor(): void {
    if (!this.lightChanged) {
      return;
    }
    const callback = this.lightChanged;
    this.lightChanged = undefined;
    try {
      sensor.off(sensor.SensorId.AMBIENT_LIGHT, callback);
    } catch (_) {
    }
  }

  private unsubscribePressureSensor(): void {
    if (!this.pressureChanged) {
      return;
    }
    const callback = this.pressureChanged;
    this.pressureChanged = undefined;
    try {
      sensor.off(sensor.SensorId.BAROMETER, callback);
    } catch (_) {
    }
  }

  private unsubscribeProximitySensor(): void {
    if (!this.proximityChanged) {
      return;
    }
    const callback = this.proximityChanged;
    this.proximityChanged = undefined;
    try {
      sensor.off(sensor.SensorId.PROXIMITY, callback);
    } catch (_) {
    }
  }

  private unsubscribeStepsSensor(): void {
    if (!this.stepsChanged) {
      return;
    }
    const callback = this.stepsChanged;
    this.stepsChanged = undefined;
    try {
      sensor.off(sensor.SensorId.PEDOMETER, callback);
    } catch (_) {
    }
  }

  private anyDirectSensorEnabled(sensorIds: string[]): boolean {
    for (let i = 0; i < sensorIds.length; i++) {
      if (this.isDirectSensorEnabled(sensorIds[i])) {
        return true;
      }
    }
    return false;
  }

  private isDirectSensorEnabled(sensorId: string): boolean {
    try {
      const values = JSON.parse(AppStorage.get<string>('sensorDirectEnabledJson') ?? '[]') as string[];
      if (!Array.isArray(values)) {
        return false;
      }
      for (let i = 0; i < values.length; i++) {
        if (values[i] === sensorId) {
          return true;
        }
      }
    } catch (_) {
    }
    return false;
  }

  private subscribeLightSensor(onChanged: (reason: string) => void): void {
    if (this.lightChanged) {
      return;
    }
    const callback = (event: sensor.LightResponse): void => {
      const changed = this.updateHardwareSensorValues({
        light: event.intensity,
        lightColorTemperature: event.colorTemperature,
        lightInfraredLuminance: event.infraredLuminance
      });
      if (changed) {
        onChanged('hardware_sensor_event');
      }
    };
    try {
      sensor.on(sensor.SensorId.AMBIENT_LIGHT, callback, { interval: 'normal' });
      this.lightChanged = callback;
    } catch (_) {
    }
  }

  private subscribePressureSensor(onChanged: (reason: string) => void): void {
    if (this.pressureChanged) {
      return;
    }
    const callback = (event: sensor.BarometerResponse): void => {
      if (this.updateHardwareSensorValues({ pressure: event.pressure })) {
        onChanged('hardware_sensor_event');
      }
    };
    try {
      sensor.on(sensor.SensorId.BAROMETER, callback, { interval: 'normal' });
      this.pressureChanged = callback;
    } catch (_) {
    }
  }

  private subscribeProximitySensor(onChanged: (reason: string) => void): void {
    if (this.proximityChanged) {
      return;
    }
    const callback = (event: sensor.ProximityResponse): void => {
      if (this.updateHardwareSensorValues({ proximity: event.distance })) {
        onChanged('hardware_sensor_event');
      }
    };
    try {
      sensor.on(sensor.SensorId.PROXIMITY, callback, { interval: 'normal' });
      this.proximityChanged = callback;
    } catch (_) {
    }
  }

  private subscribeStepsSensor(onChanged: (reason: string) => void): void {
    if (this.stepsChanged) {
      return;
    }
    const callback = (event: sensor.PedometerResponse): void => {
      if (this.updateHardwareSensorValues({ steps: event.steps })) {
        onChanged('hardware_sensor_event');
      }
    };
    try {
      sensor.on(sensor.SensorId.PEDOMETER, callback, { interval: 'normal' });
      this.stepsChanged = callback;
    } catch (_) {
    }
  }

  private updateHardwareSensorValues(next: HardwareSensorValues): boolean {
    const current = SystemEventService.hardwareSensorValues();
    const now = Date.now();
    if (!SystemEventService.hasHardwareSensorChange(current, next)) {
      return false;
    }
    const merged: HardwareSensorValues = {
      light: next.light ?? current.light,
      lightColorTemperature: next.lightColorTemperature ?? current.lightColorTemperature,
      lightInfraredLuminance: next.lightInfraredLuminance ?? current.lightInfraredLuminance,
      pressure: next.pressure ?? current.pressure,
      proximity: next.proximity ?? current.proximity,
      steps: next.steps ?? current.steps,
      stepDetected: next.stepDetected ?? current.stepDetected,
      updatedAt: now
    };
    const value = JSON.stringify(merged);
    if (AppStorage.get<string>('sensorHardwareValuesJson') !== value) {
      if (!AppStorage.set<string>('sensorHardwareValuesJson', value)) {
        AppStorage.setOrCreate<string>('sensorHardwareValuesJson', value);
      }
    }
    return true;
  }

  private static hasHardwareSensorChange(current: HardwareSensorValues, next: HardwareSensorValues): boolean {
    if (SystemEventService.hasNumberChange(current.light, next.light, 1)) {
      return true;
    }
    if (SystemEventService.hasNumberChange(current.lightColorTemperature, next.lightColorTemperature, 10)) {
      return true;
    }
    if (SystemEventService.hasNumberChange(current.lightInfraredLuminance, next.lightInfraredLuminance, 1)) {
      return true;
    }
    if (SystemEventService.hasNumberChange(current.pressure, next.pressure, 0.5)) {
      return true;
    }
    if (SystemEventService.hasNumberChange(current.proximity, next.proximity, 0.1)) {
      return true;
    }
    if (next.steps !== undefined && next.steps !== current.steps) {
      return true;
    }
    return next.stepDetected !== undefined && next.stepDetected !== current.stepDetected;
  }

  private static hasNumberChange(current: number | undefined, next: number | undefined, threshold: number): boolean {
    if (next === undefined) {
      return false;
    }
    if (current === undefined) {
      return true;
    }
    return Math.abs(next - current) >= threshold;
  }

  private static hardwareSensorValues(): HardwareSensorValues {
    try {
      const parsed = JSON.parse(AppStorage.get<string>('sensorHardwareValuesJson') ?? '{}') as HardwareSensorValues;
      if (!parsed || typeof parsed !== 'object') {
        return {};
      }
      return parsed;
    } catch (_) {
      return {};
    }
  }

  private subscribeMultimodalEvents(onChanged: (reason: string) => void): void {
    if (this.isDirectSensorEnabled('harmony_operating_hand')) {
      this.subscribeOperatingHandEvent(onChanged);
    } else {
      this.unsubscribeOperatingHandEvent();
    }
    if (this.isDirectSensorEnabled('harmony_holding_hand')) {
      this.subscribeHoldingHandEvent(onChanged);
    } else {
      this.unsubscribeHoldingHandEvent();
    }
  }

  private unsubscribeMultimodalEvents(): void {
    this.unsubscribeOperatingHandEvent();
    this.unsubscribeHoldingHandEvent();
  }

  private unsubscribeOperatingHandEvent(): void {
    if (this.operatingHandChanged) {
      const callback = this.operatingHandChanged;
      this.operatingHandChanged = undefined;
      try {
        motion.off('operatingHandChanged', callback);
      } catch (_) {
      }
    }
  }

  private unsubscribeHoldingHandEvent(): void {
    if (this.holdingHandChanged) {
      const callback = this.holdingHandChanged;
      this.holdingHandChanged = undefined;
      try {
        motion.off('holdingHandChanged', callback);
      } catch (_) {
      }
    }
  }

  private subscribeOperatingHandEvent(onChanged: (reason: string) => void): void {
    if (this.operatingHandChanged) {
      return;
    }
    const callback = (status: motion.OperatingHandStatus): void => {
      if (this.updateMultimodalSensorValues({ operatingHand: status })) {
        onChanged('multimodal_motion_event');
      }
    };
    try {
      this.updateMultimodalSensorValues({ operatingHand: motion.getRecentOperatingHandStatus() });
    } catch (_) {
    }
    try {
      motion.on('operatingHandChanged', callback);
      this.operatingHandChanged = callback;
    } catch (_) {
    }
  }

  private subscribeHoldingHandEvent(onChanged: (reason: string) => void): void {
    if (this.holdingHandChanged) {
      return;
    }
    const callback = (status: motion.HoldingHandStatus): void => {
      if (this.updateMultimodalSensorValues({ holdingHand: status })) {
        onChanged('multimodal_motion_event');
      }
    };
    try {
      motion.on('holdingHandChanged', callback);
      this.holdingHandChanged = callback;
    } catch (_) {
    }
  }

  private updateMultimodalSensorValues(next: MultimodalSensorValues): boolean {
    const current = SystemEventService.multimodalSensorValues();
    const now = Date.now();
    if (!SystemEventService.hasMultimodalSensorChange(current, next)) {
      return false;
    }
    const merged: MultimodalSensorValues = {
      operatingHand: next.operatingHand ?? current.operatingHand,
      holdingHand: next.holdingHand ?? current.holdingHand,
      updatedAt: now
    };
    const value = JSON.stringify(merged);
    if (AppStorage.get<string>('sensorMultimodalValuesJson') !== value) {
      if (!AppStorage.set<string>('sensorMultimodalValuesJson', value)) {
        AppStorage.setOrCreate<string>('sensorMultimodalValuesJson', value);
      }
    }
    return true;
  }

  private static hasMultimodalSensorChange(current: MultimodalSensorValues, next: MultimodalSensorValues): boolean {
    if (next.operatingHand !== undefined && next.operatingHand !== current.operatingHand) {
      return true;
    }
    if (next.holdingHand !== undefined && next.holdingHand !== current.holdingHand) {
      return true;
    }
    return false;
  }

  private static multimodalSensorValues(): MultimodalSensorValues {
    try {
      const parsed = JSON.parse(AppStorage.get<string>('sensorMultimodalValuesJson') ?? '{}') as MultimodalSensorValues;
      if (!parsed || typeof parsed !== 'object') {
        return {};
      }
      return parsed;
    } catch (_) {
      return {};
    }
  }

  private subscribePowerAndScreenEvents(onChanged: (reason: string) => void): void {
    if (this.directEventSubscriber || this.directEventSubscriberPending) {
      return;
    }
    this.directEventSubscriberPending = true;
    const requestId = this.directEventSubscriberRequestId + 1;
    this.directEventSubscriberRequestId = requestId;
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [
        commonEventManager.Support.COMMON_EVENT_SCREEN_ON,
        commonEventManager.Support.COMMON_EVENT_SCREEN_OFF,
        commonEventManager.Support.COMMON_EVENT_SCREEN_LOCKED,
        commonEventManager.Support.COMMON_EVENT_SCREEN_UNLOCKED,
        commonEventManager.Support.COMMON_EVENT_POWER_SAVE_MODE_CHANGED,
        commonEventManager.Support.COMMON_EVENT_DEVICE_IDLE_MODE_CHANGED,
        commonEventManager.Support.COMMON_EVENT_CHARGE_IDLE_MODE_CHANGED
      ]
    };
    commonEventManager.createSubscriber(subscribeInfo)
      .then((subscriber: commonEventManager.CommonEventSubscriber): Promise<void> => {
        if (this.directEventSubscriberRequestId !== requestId ||
          !this.directSensorEventHandler ||
          !this.anyDirectSensorEnabled(SystemEventService.POWER_AND_SCREEN_SENSOR_IDS)) {
          try {
            commonEventManager.unsubscribe(subscriber, () => {});
          } catch (_) {
          }
          if (this.directEventSubscriberRequestId === requestId) {
            this.directEventSubscriberPending = false;
          }
          return Promise.resolve();
        }
        this.directEventSubscriberPending = false;
        this.directEventSubscriber = subscriber;
        return commonEventManager.subscribeToEvent(subscriber, (): void => {
          onChanged('power_display_event');
        });
      })
      .catch((): void => {
        if (this.directEventSubscriberRequestId === requestId) {
          this.directEventSubscriberPending = false;
          this.directEventSubscriber = undefined;
        }
      });
  }

  private unsubscribePowerAndScreenEvents(): void {
    this.directEventSubscriberRequestId += 1;
    this.directEventSubscriberPending = false;
    if (!this.directEventSubscriber) {
      return;
    }
    const subscriber = this.directEventSubscriber;
    this.directEventSubscriber = undefined;
    commonEventManager.unsubscribe(subscriber, () => {});
  }

  private subscribeBluetoothEvents(onChanged: (reason: string) => void): void {
    if (this.bluetoothChanged) {
      return;
    }
    const callback = (_state: bluetoothAccess.BluetoothState): void => {
      onChanged('bluetooth_event');
    };
    try {
      bluetoothAccess.on('stateChange', callback);
      this.bluetoothChanged = callback;
    } catch (_) {
    }
  }

  private unsubscribeBluetoothEvents(): void {
    if (!this.bluetoothChanged) {
      return;
    }
    const callback = this.bluetoothChanged;
    this.bluetoothChanged = undefined;
    try {
      bluetoothAccess.off('stateChange', callback);
    } catch (_) {
    }
  }

  private subscribeNfcEvents(onChanged: (reason: string) => void): void {
    if (this.nfcChanged) {
      return;
    }
    const callback = (_state: nfcController.NfcState): void => {
      onChanged('nfc_event');
    };
    try {
      nfcController.on('nfcStateChange', callback);
      this.nfcChanged = callback;
    } catch (_) {
    }
  }

  private unsubscribeNfcEvents(): void {
    if (!this.nfcChanged) {
      return;
    }
    const callback = this.nfcChanged;
    this.nfcChanged = undefined;
    try {
      nfcController.off('nfcStateChange', callback);
    } catch (_) {
    }
  }

  private subscribeDisplayEvents(onChanged: (reason: string) => void): void {
    if (this.displayChanged || this.displayFoldChanged || this.displayFoldModeChanged) {
      return;
    }
    const displayCallback = (_displayId: number): void => {
      onChanged('display_event');
    };
    const foldCallback = (_status: display.FoldStatus): void => {
      onChanged('display_fold_event');
    };
    const foldModeCallback = (_mode: display.FoldDisplayMode): void => {
      onChanged('display_fold_event');
    };
    try {
      display.on('change', displayCallback);
      this.displayChanged = displayCallback;
    } catch (_) {
    }
    try {
      display.on('foldStatusChange', foldCallback);
      this.displayFoldChanged = foldCallback;
    } catch (_) {
    }
    try {
      display.on('foldDisplayModeChange', foldModeCallback);
      this.displayFoldModeChanged = foldModeCallback;
    } catch (_) {
    }
  }

  private unsubscribeDisplayEvents(): void {
    if (this.displayChanged) {
      const callback = this.displayChanged;
      this.displayChanged = undefined;
      try {
        display.off('change', callback);
      } catch (_) {
      }
    }
    if (this.displayFoldChanged) {
      const callback = this.displayFoldChanged;
      this.displayFoldChanged = undefined;
      try {
        display.off('foldStatusChange', callback);
      } catch (_) {
      }
    }
    if (this.displayFoldModeChanged) {
      const callback = this.displayFoldModeChanged;
      this.displayFoldModeChanged = undefined;
      try {
        display.off('foldDisplayModeChange', callback);
      } catch (_) {
      }
    }
  }

  private subscribeAudioEvents(onChanged: (reason: string) => void): void {
    if (this.audioVolumeChanged || this.audioRingerChanged ||
      this.audioDeviceChanged || this.audioSceneChanged) {
      return;
    }
    const volumeCallback = (_event: audio.StreamVolumeEvent): void => {
      onChanged('audio_event');
    };
    const ringerCallback = (_mode: audio.AudioRingMode): void => {
      onChanged('audio_event');
    };
    const deviceCallback = (_event: audio.DeviceChangeAction): void => {
      onChanged('audio_route_event');
    };
    const sceneCallback = (_scene: audio.AudioScene): void => {
      onChanged('audio_scene_event');
    };
    try {
      const manager = audio.getAudioManager().getVolumeManager();
      const usages: audio.StreamUsage[] = [
        audio.StreamUsage.STREAM_USAGE_ALARM,
        audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION,
        audio.StreamUsage.STREAM_USAGE_MUSIC,
        audio.StreamUsage.STREAM_USAGE_RINGTONE,
        audio.StreamUsage.STREAM_USAGE_NOTIFICATION,
        audio.StreamUsage.STREAM_USAGE_ACCESSIBILITY
      ];
      let subscribed = false;
      for (let i = 0; i < usages.length; i++) {
        try {
          manager.on('streamVolumeChange', usages[i], volumeCallback);
          subscribed = true;
        } catch (_) {
        }
      }
      if (subscribed) {
        this.audioVolumeChanged = volumeCallback;
      }
    } catch (_) {
    }
    try {
      audio.getAudioManager().getVolumeManager()
        .getVolumeGroupManagerSync(audio.DEFAULT_VOLUME_GROUP_ID)
        .on('ringerModeChange', ringerCallback);
      this.audioRingerChanged = ringerCallback;
    } catch (_) {
    }
    try {
      audio.getAudioManager().getRoutingManager()
        .on('deviceChange', audio.DeviceFlag.OUTPUT_DEVICES_FLAG, deviceCallback);
      this.audioDeviceChanged = deviceCallback;
    } catch (_) {
    }
    try {
      audio.getAudioManager().on('audioSceneChange', sceneCallback);
      this.audioSceneChanged = sceneCallback;
    } catch (_) {
    }
  }

  private unsubscribeAudioEvents(): void {
    if (this.audioVolumeChanged) {
      const callback = this.audioVolumeChanged;
      this.audioVolumeChanged = undefined;
      try {
        audio.getAudioManager().getVolumeManager().off('streamVolumeChange', callback);
      } catch (_) {
      }
    }
    if (this.audioRingerChanged) {
      const callback = this.audioRingerChanged;
      this.audioRingerChanged = undefined;
      try {
        audio.getAudioManager().getVolumeManager()
          .getVolumeGroupManagerSync(audio.DEFAULT_VOLUME_GROUP_ID)
          .off('ringerModeChange', callback);
      } catch (_) {
      }
    }
    if (this.audioDeviceChanged) {
      const callback = this.audioDeviceChanged;
      this.audioDeviceChanged = undefined;
      try {
        audio.getAudioManager().getRoutingManager().off('deviceChange', callback);
      } catch (_) {
      }
    }
    if (this.audioSceneChanged) {
      const callback = this.audioSceneChanged;
      this.audioSceneChanged = undefined;
      try {
        audio.getAudioManager().off('audioSceneChange', callback);
      } catch (_) {
      }
    }
  }
}
