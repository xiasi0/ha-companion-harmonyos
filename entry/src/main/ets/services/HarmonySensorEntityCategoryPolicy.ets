import { SensorDescriptor } from './HarmonySensorModels';

const DIAGNOSTIC_SENSOR_IDS: string[] = [
  'battery_level',
  'battery_state',
  'is_charging',
  'charger_type',
  'battery_health',
  'battery_temperature',
  'battery_voltage',
  'battery_current',
  'battery_power',
  'battery_technology',
  'battery_capacity_level',
  'battery_present',
  'wifi_state',
  'wifi_connection',
  'wifi_bssid',
  'wifi_ip_address',
  'wifi_frequency',
  'wifi_signal_strength',
  'wifi_link_speed',
  'hotspot_state',
  'network_type',
  'current_version',
  'harmony_os_version',
  'harmony_os_security_patch',
  'harmony_device_type',
  'harmony_product_model',
  'harmony_performance_class',
  'harmony_boot_count',
  'harmony_thermal_level',
  'harmony_vibrator_effect_support',
  'harmony_operating_hand',
  'harmony_holding_hand',
  'active',
  'app_memory',
  'storage_sensor',
  'is_interactive',
  'is_idle',
  'power_save',
  'current_time_zone',
  'bluetooth_state',
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
  'nfc_state',
  'display_density',
  'display_refresh_rate',
  'display_brightness_headroom',
  'harmony_screen_shape',
  'harmony_display_hdr_formats',
  'harmony_foldable',
  'harmony_fold_status',
  'harmony_fold_display_mode',
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
