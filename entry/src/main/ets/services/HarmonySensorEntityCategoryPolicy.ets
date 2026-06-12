import { SensorDescriptor } from './HarmonySensorModels';

const DIAGNOSTIC_SENSOR_IDS: string[] = [
  'battery_level',
  'battery_state',
  'is_charging',
  'charger_type',
  'battery_health',
  'battery_temperature',
  'battery_power',
  'ipv6_address',
  'public_ip_address',
  'wifi_state',
  'wifi_connection',
  'wifi_bssid',
  'wifi_ip_address',
  'wifi_frequency',
  'wifi_signal_strength',
  'wifi_link_speed',
  'hotspot_state',
  'network_type',
  'voice_capability',
  'sim_1',
  'sim_2',
  'mobile_data',
  'mobile_data_roaming',
  'total_tx_traffic',
  'total_rx_traffic',
  'cellular_tx_traffic',
  'cellular_rx_traffic',
  'harmony_os_version',
  'harmony_os_security_patch',
  'harmony_operating_hand',
  'harmony_holding_hand',
  'app_memory',
  'app_process_state',
  'current_version',
  'active',
  'current_time_zone',
  'storage_sensor',
  'is_interactive',
  'is_idle',
  'power_save',
  'bluetooth_state',
  'bluetooth_connection',
  'device_security',
  'device_locked',
  'audio_sensor',
  'audio_mode',
  'headphone_state',
  'speakerphone_state',
  'volume_alarm',
  'volume_call',
  'volume_music',
  'volume_ring',
  'volume_notification',
  'volume_accessibility',
  'location_permission',
  'last_update_trigger',
  'last_reboot_time',
  'do_not_disturb_sensor',
  'nfc_state',
  'screen_brightness',
  'screen_off_timeout',
  'screen_orientation',
  'screen_rotation',
  'proximity_sensor'
];

export class HarmonySensorEntityCategoryPolicy {
  static apply(descriptors: SensorDescriptor[]): SensorDescriptor[] {
    return descriptors.map((descriptor: SensorDescriptor): SensorDescriptor => {
      const category = HarmonySensorEntityCategoryPolicy.categoryFor(descriptor.id);
      const next: SensorDescriptor = {
        id: descriptor.id,
        name: descriptor.name,
        type: descriptor.type,
        icon: descriptor.icon,
        state: descriptor.state,
        attributes: descriptor.attributes,
        enabled: descriptor.enabled,
        deviceClass: descriptor.deviceClass,
        unitOfMeasurement: descriptor.unitOfMeasurement,
        stateClass: descriptor.stateClass
      };
      if (category.length > 0) {
        next.entityCategory = category;
      }
      return next;
    });
  }

  static categoryFor(sensorId: string): string {
    return HarmonySensorEntityCategoryPolicy.contains(DIAGNOSTIC_SENSOR_IDS, sensorId) ? 'diagnostic' : '';
  }

  private static contains(values: string[], target: string): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true;
      }
    }
    return false;
  }
}
