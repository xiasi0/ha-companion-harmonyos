import { Localization } from '../../shared/i18n/Localization';
import { SensorEntry, SensorGroup } from './SensorModels';

export class SensorCatalog {
  static groups(): SensorGroup[] {
    return [
      {
        title: Localization.t('sensor_group_battery'),
        sensors: [
          SensorCatalog.sensor('battery_level', Localization.t('sensor_battery_level'), 'battery'),
          SensorCatalog.sensor('battery_state', Localization.t('sensor_battery_state'), 'battery'),
          SensorCatalog.sensor('is_charging', Localization.t('sensor_is_charging'), 'sensor'),
          SensorCatalog.sensor('charger_type', Localization.t('sensor_charger_type'), 'battery'),
          SensorCatalog.sensor('battery_health', Localization.t('sensor_battery_health'), 'sensor'),
          SensorCatalog.sensor('battery_temperature', Localization.t('sensor_battery_temperature'), 'sensor'),
          SensorCatalog.sensor('battery_voltage', Localization.t('sensor_battery_voltage'), 'sensor'),
          SensorCatalog.sensor('battery_current', Localization.t('sensor_battery_current'), 'sensor'),
          SensorCatalog.sensor('battery_power', Localization.t('sensor_battery_power'), 'sensor'),
          SensorCatalog.sensor('battery_technology', Localization.t('sensor_battery_technology'), 'sensor'),
          SensorCatalog.sensor('battery_capacity_level', Localization.t('sensor_battery_capacity_level'), 'sensor'),
          SensorCatalog.sensor('battery_present', Localization.t('sensor_battery_present'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_network'),
        sensors: [
          SensorCatalog.sensor('network_type', Localization.t('sensor_network_type'), 'wifi'),
          SensorCatalog.sensor('wifi_state', Localization.t('sensor_wifi_state'), 'sensor'),
          SensorCatalog.sensor('wifi_connection', Localization.t('sensor_wifi_connection'), 'sensor'),
          SensorCatalog.sensor('wifi_bssid', Localization.t('sensor_wifi_bssid'), 'sensor'),
          SensorCatalog.sensor('wifi_ip_address', Localization.t('sensor_wifi_ip_address'), 'sensor'),
          SensorCatalog.sensor('wifi_frequency', Localization.t('sensor_wifi_frequency'), 'sensor'),
          SensorCatalog.sensor('wifi_signal_strength', Localization.t('sensor_wifi_signal_strength'), 'sensor'),
          SensorCatalog.sensor('wifi_link_speed', Localization.t('sensor_wifi_link_speed'), 'sensor'),
          SensorCatalog.sensor('hotspot_state', Localization.t('sensor_hotspot_state'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_bluetooth'),
        sensors: [
          SensorCatalog.sensor('bluetooth_state', Localization.t('sensor_bluetooth_state'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_nfc'),
        sensors: [
          SensorCatalog.sensor('nfc_state', Localization.t('sensor_nfc_state'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_audio'),
        sensors: [
          SensorCatalog.sensor('audio_sensor', Localization.t('sensor_audio_sensor'), 'sensor'),
          SensorCatalog.sensor('audio_mode', Localization.t('sensor_audio_mode'), 'sensor'),
          SensorCatalog.sensor('headphone_state', Localization.t('sensor_headphone_state'), 'sensor'),
          SensorCatalog.sensor('speakerphone_state', Localization.t('sensor_speakerphone_state'), 'sensor'),
          SensorCatalog.sensor('volume_alarm', Localization.t('sensor_volume_alarm'), 'sensor'),
          SensorCatalog.sensor('volume_call', Localization.t('sensor_volume_call'), 'sensor'),
          SensorCatalog.sensor('volume_music', Localization.t('sensor_volume_music'), 'sensor'),
          SensorCatalog.sensor('volume_ring', Localization.t('sensor_volume_ring'), 'sensor'),
          SensorCatalog.sensor('volume_notification', Localization.t('sensor_volume_notification'), 'sensor'),
          SensorCatalog.sensor('volume_accessibility', Localization.t('sensor_volume_accessibility'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_location'),
        sensors: [
          SensorCatalog.sensor('accurate_location', Localization.t('sensor_accurate_location'), 'sensor'),
          SensorCatalog.sensor('geocoded_location', Localization.t('sensor_geocoded_location'), 'sensor'),
          SensorCatalog.sensor('zone_background', Localization.t('sensor_zone_background'), 'sensor'),
          SensorCatalog.sensor('location_background', Localization.t('sensor_location_background'), 'sensor'),
          SensorCatalog.sensor('location_permission', Localization.t('sensor_location_permission'), 'sensor'),
          SensorCatalog.sensor('last_update_trigger', Localization.t('sensor_last_update_trigger'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_device_system'),
        sensors: [
          SensorCatalog.sensor('current_version', Localization.t('sensor_current_version'), 'sensor'),
          SensorCatalog.sensor('harmony_os_version', Localization.t('sensor_harmony_os_version'), 'sensor'),
          SensorCatalog.sensor('harmony_os_security_patch', Localization.t('sensor_harmony_os_security_patch'), 'sensor'),
          SensorCatalog.sensor('harmony_device_type', Localization.t('sensor_harmony_device_type'), 'sensor'),
          SensorCatalog.sensor('harmony_product_model', Localization.t('sensor_harmony_product_model'), 'sensor'),
          SensorCatalog.sensor('harmony_performance_class', Localization.t('sensor_harmony_performance_class'), 'sensor'),
          SensorCatalog.sensor('harmony_boot_count', Localization.t('sensor_harmony_boot_count'), 'sensor'),
          SensorCatalog.sensor('harmony_thermal_level', Localization.t('sensor_harmony_thermal_level'), 'sensor'),
          SensorCatalog.sensor('harmony_vibrator_effect_support', Localization.t('sensor_harmony_vibrator_effect_support'), 'sensor'),
          SensorCatalog.sensor('harmony_operating_hand', Localization.t('sensor_harmony_operating_hand'), 'sensor'),
          SensorCatalog.sensor('harmony_holding_hand', Localization.t('sensor_harmony_holding_hand'), 'sensor'),
          SensorCatalog.sensor('active', Localization.t('sensor_active'), 'sensor'),
          SensorCatalog.sensor('app_memory', Localization.t('sensor_app_memory'), 'sensor'),
          SensorCatalog.sensor('current_time_zone', Localization.t('sensor_current_time_zone'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_display'),
        sensors: [
          SensorCatalog.sensor('display_state', Localization.t('sensor_display_state'), 'sensor'),
          SensorCatalog.sensor('screen_orientation', Localization.t('sensor_screen_orientation'), 'sensor'),
          SensorCatalog.sensor('screen_rotation', Localization.t('sensor_screen_rotation'), 'sensor'),
          SensorCatalog.sensor('screen_resolution', Localization.t('sensor_screen_resolution'), 'sensor'),
          SensorCatalog.sensor('display_refresh_rate', Localization.t('sensor_display_refresh_rate'), 'sensor'),
          SensorCatalog.sensor('display_density', Localization.t('sensor_display_density'), 'sensor'),
          SensorCatalog.sensor('screen_brightness', Localization.t('sensor_screen_brightness'), 'sensor'),
          SensorCatalog.sensor('display_brightness_headroom', Localization.t('sensor_display_brightness_headroom'), 'sensor'),
          SensorCatalog.sensor('harmony_screen_shape', Localization.t('sensor_harmony_screen_shape'), 'sensor'),
          SensorCatalog.sensor('harmony_display_hdr_formats', Localization.t('sensor_harmony_display_hdr_formats'), 'sensor'),
          SensorCatalog.sensor('harmony_foldable', Localization.t('sensor_harmony_foldable'), 'sensor'),
          SensorCatalog.sensor('harmony_fold_status', Localization.t('sensor_harmony_fold_status'), 'sensor'),
          SensorCatalog.sensor('harmony_fold_display_mode', Localization.t('sensor_harmony_fold_display_mode'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_hardware'),
        sensors: [
          SensorCatalog.sensor('light_sensor', Localization.t('sensor_light_sensor'), 'sensor'),
          SensorCatalog.sensor('pressure_sensor', Localization.t('sensor_pressure_sensor'), 'sensor'),
          SensorCatalog.sensor('proximity_sensor', Localization.t('sensor_proximity_sensor'), 'sensor'),
          SensorCatalog.sensor('steps_sensor', Localization.t('sensor_steps_sensor'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_storage'),
        sensors: [
          SensorCatalog.sensor('storage_sensor', Localization.t('sensor_storage_sensor'), 'sensor')
        ]
      },
      {
        title: Localization.t('sensor_group_power'),
        sensors: [
          SensorCatalog.sensor('is_interactive', Localization.t('sensor_is_interactive'), 'sensor'),
          SensorCatalog.sensor('is_idle', Localization.t('sensor_is_idle'), 'sensor'),
          SensorCatalog.sensor('power_save', Localization.t('sensor_power_save'), 'sensor')
        ]
      }
    ];
  }

  private static sensor(id: string, title: string, icon: string): SensorEntry {
    return {
      id,
      title,
      icon,
      enabled: false,
      summary: ''
    };
  }
}
