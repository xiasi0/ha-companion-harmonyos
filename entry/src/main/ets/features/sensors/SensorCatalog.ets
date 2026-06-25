import { Localization } from '../../shared/i18n/Localization';
import { AppIconSpec, materialIcon } from '../../shared/icons/AppIconModels';
import { SensorEntry, SensorGroup } from './SensorModels';

export class SensorCatalog {
  static groups(): SensorGroup[] {
    return [
      {
        title: Localization.t('sensor_group_battery'),
        sensors: [
          SensorCatalog.sensor('charger_type', Localization.t('sensor_charger_type')),
          SensorCatalog.sensor('is_charging', Localization.t('sensor_is_charging')),
          SensorCatalog.sensor('battery_health', Localization.t('sensor_battery_health')),
          SensorCatalog.sensor('battery_power', Localization.t('sensor_battery_power')),
          SensorCatalog.sensor('battery_temperature', Localization.t('sensor_battery_temperature')),
          SensorCatalog.sensor('battery_state', Localization.t('sensor_battery_state')),
          SensorCatalog.sensor('battery_level', Localization.t('sensor_battery_level'))
        ]
      },
      {
        title: Localization.t('sensor_group_network'),
        sensors: [
          SensorCatalog.sensor('ipv6_address', Localization.t('sensor_ipv6_address')),
          SensorCatalog.sensor('public_ip_address', Localization.t('sensor_public_ip_address')),
          SensorCatalog.sensor('wifi_bssid', Localization.t('sensor_wifi_bssid')),
          SensorCatalog.sensor('wifi_signal_strength', Localization.t('sensor_wifi_signal_strength')),
          SensorCatalog.sensor('wifi_ip_address', Localization.t('sensor_wifi_ip_address')),
          SensorCatalog.sensor('wifi_state', Localization.t('sensor_wifi_state')),
          SensorCatalog.sensor('wifi_connection', Localization.t('sensor_wifi_connection')),
          SensorCatalog.sensor('wifi_link_speed', Localization.t('sensor_wifi_link_speed')),
          SensorCatalog.sensor('wifi_frequency', Localization.t('sensor_wifi_frequency')),
          SensorCatalog.sensor('hotspot_state', Localization.t('sensor_hotspot_state')),
          SensorCatalog.sensor('network_type', Localization.t('sensor_network_type'))
        ]
      },
      {
        title: Localization.t('sensor_group_phone'),
        sensors: [
          SensorCatalog.sensor('phone_state', Localization.t('sensor_phone_state')),
          SensorCatalog.sensor('has_call', Localization.t('sensor_has_call')),
          SensorCatalog.sensor('voice_capability', Localization.t('sensor_voice_capability')),
          SensorCatalog.sensor('sim_1', Localization.t('sensor_sim_1')),
          SensorCatalog.sensor('sim_2', Localization.t('sensor_sim_2'))
        ]
      },
      {
        title: Localization.t('sensor_group_traffic_stats'),
        sensors: [
          SensorCatalog.sensor('total_tx_traffic', Localization.t('sensor_total_tx_traffic')),
          SensorCatalog.sensor('total_rx_traffic', Localization.t('sensor_total_rx_traffic')),
          SensorCatalog.sensor('cellular_tx_traffic', Localization.t('sensor_cellular_tx_traffic')),
          SensorCatalog.sensor('cellular_rx_traffic', Localization.t('sensor_cellular_rx_traffic'))
        ]
      },
      {
        title: Localization.t('sensor_group_mobile_data'),
        sensors: [
          SensorCatalog.sensor('mobile_data', Localization.t('sensor_mobile_data')),
          SensorCatalog.sensor('mobile_data_roaming', Localization.t('sensor_mobile_data_roaming'))
        ]
      },
      {
        title: Localization.t('sensor_group_bluetooth'),
        sensors: [
          SensorCatalog.sensor('bluetooth_state', Localization.t('sensor_bluetooth_state')),
          SensorCatalog.sensor('bluetooth_connection', Localization.t('sensor_bluetooth_connection'))
        ]
      },
      {
        title: Localization.t('sensor_group_nfc'),
        sensors: [
          SensorCatalog.sensor('nfc_state', Localization.t('sensor_nfc_state'))
        ]
      },
      {
        title: Localization.t('sensor_group_security'),
        sensors: [
          SensorCatalog.sensor('device_security', Localization.t('sensor_device_security')),
          SensorCatalog.sensor('device_locked', Localization.t('sensor_device_locked'))
        ]
      },
      {
        title: Localization.t('sensor_group_audio'),
        sensors: [
          SensorCatalog.sensor('audio_sensor', Localization.t('sensor_audio_sensor')),
          SensorCatalog.sensor('audio_mode', Localization.t('sensor_audio_mode')),
          SensorCatalog.sensor('headphone_state', Localization.t('sensor_headphone_state')),
          SensorCatalog.sensor('speakerphone_state', Localization.t('sensor_speakerphone_state')),
          SensorCatalog.sensor('volume_alarm', Localization.t('sensor_volume_alarm')),
          SensorCatalog.sensor('volume_call', Localization.t('sensor_volume_call')),
          SensorCatalog.sensor('volume_music', Localization.t('sensor_volume_music')),
          SensorCatalog.sensor('volume_ring', Localization.t('sensor_volume_ring')),
          SensorCatalog.sensor('volume_notification', Localization.t('sensor_volume_notification')),
          SensorCatalog.sensor('volume_accessibility', Localization.t('sensor_volume_accessibility'))
        ]
      },
      {
        title: Localization.t('sensor_group_location'),
        sensors: [
          SensorCatalog.sensor('accurate_location', Localization.t('sensor_accurate_location')),
          SensorCatalog.sensor('zone_background', Localization.t('sensor_zone_background')),
          SensorCatalog.sensor('location_background', Localization.t('sensor_location_background')),
          SensorCatalog.sensor('location_permission', Localization.t('sensor_location_permission'))
        ]
      },
      {
        title: Localization.t('sensor_group_geocoded_location'),
        sensors: [
          SensorCatalog.sensor('geocoded_location', Localization.t('sensor_geocoded_location'))
        ]
      },
      {
        title: Localization.t('sensor_group_last_update'),
        sensors: [
          SensorCatalog.sensor('last_update_trigger', Localization.t('sensor_last_update_trigger'))
        ]
      },
      {
        title: Localization.t('sensor_group_last_reboot'),
        sensors: [
          SensorCatalog.sensor('last_reboot_time', Localization.t('sensor_last_reboot_time'))
        ]
      },
      {
        title: Localization.t('sensor_group_do_not_disturb'),
        sensors: [
          SensorCatalog.sensor('do_not_disturb_sensor', Localization.t('sensor_do_not_disturb_sensor'))
        ]
      },
      {
        title: Localization.t('sensor_group_application'),
        sensors: [
          SensorCatalog.sensor('app_memory', Localization.t('sensor_app_memory')),
          SensorCatalog.sensor('app_process_state', Localization.t('sensor_app_process_state')),
          SensorCatalog.sensor('current_version', Localization.t('sensor_current_version')),
          SensorCatalog.sensor('active', Localization.t('sensor_active'))
        ]
      },
      {
        title: Localization.t('sensor_group_time_zone'),
        sensors: [
          SensorCatalog.sensor('current_time_zone', Localization.t('sensor_current_time_zone'))
        ]
      },
      {
        title: Localization.t('sensor_group_device_system'),
        sensors: [
          SensorCatalog.sensor('harmony_os_security_patch', Localization.t('sensor_harmony_os_security_patch')),
          SensorCatalog.sensor('harmony_os_version', Localization.t('sensor_harmony_os_version')),
          SensorCatalog.sensor('harmony_operating_hand', Localization.t('sensor_harmony_operating_hand')),
          SensorCatalog.sensor('harmony_holding_hand', Localization.t('sensor_harmony_holding_hand'))
        ]
      },
      {
        title: Localization.t('sensor_group_display'),
        sensors: [
          SensorCatalog.sensor('screen_brightness', Localization.t('sensor_screen_brightness')),
          SensorCatalog.sensor('screen_off_timeout', Localization.t('sensor_screen_off_timeout')),
          SensorCatalog.sensor('screen_orientation', Localization.t('sensor_screen_orientation')),
          SensorCatalog.sensor('screen_rotation', Localization.t('sensor_screen_rotation'))
        ]
      },
      {
        title: Localization.t('sensor_group_hardware'),
        sensors: [
          SensorCatalog.sensor('light_sensor', Localization.t('sensor_light_sensor'))
        ]
      },
      {
        title: Localization.t('sensor_group_proximity'),
        sensors: [
          SensorCatalog.sensor('proximity_sensor', Localization.t('sensor_proximity_sensor'))
        ]
      },
      {
        title: Localization.t('sensor_group_storage'),
        sensors: [
          SensorCatalog.sensor('storage_sensor', Localization.t('sensor_storage_sensor'))
        ]
      },
      {
        title: Localization.t('sensor_group_power'),
        sensors: [
          SensorCatalog.sensor('is_interactive', Localization.t('sensor_is_interactive')),
          SensorCatalog.sensor('power_save', Localization.t('sensor_power_save')),
          SensorCatalog.sensor('is_idle', Localization.t('sensor_is_idle'))
        ]
      }
    ];
  }

  private static sensor(id: string, title: string): SensorEntry {
    return {
      id,
      title,
      icon: SensorCatalog.icon(id),
      enabled: false,
      summary: ''
    };
  }

  private static icon(id: string): AppIconSpec {
    switch (id) {
      case 'charger_type':
        return materialIcon('battery_charging_full');
      case 'is_charging':
        return materialIcon('power');
      case 'battery_health':
        return materialIcon('battery_health');
      case 'battery_power':
        return materialIcon('battery_plus');
      case 'battery_temperature':
        return materialIcon('battery_charging_full');
      case 'battery_state':
        return materialIcon('battery_plus');
      case 'battery_level':
        return materialIcon('battery_charging_80');
      case 'ipv6_address':
        return materialIcon('bring_your_own_ip');
      case 'public_ip_address':
        return materialIcon('bring_your_own_ip');
      case 'wifi_bssid':
        return materialIcon('wifi');
      case 'wifi_signal_strength':
        return materialIcon('network_wifi');
      case 'wifi_ip_address':
        return materialIcon('bring_your_own_ip');
      case 'wifi_state':
        return materialIcon('wifi');
      case 'wifi_connection':
        return materialIcon('wifi');
      case 'wifi_link_speed':
        return materialIcon('network_wifi');
      case 'wifi_frequency':
        return materialIcon('wifi');
      case 'hotspot_state':
        return materialIcon('wifi_tethering');
      case 'network_type':
        return materialIcon('wifi');
      case 'phone_state':
        return materialIcon('phone_enabled');
      case 'has_call':
        return materialIcon('phone_in_talk');
      case 'voice_capability':
        return materialIcon('phone_enabled');
      case 'sim_1':
        return materialIcon('sim_card');
      case 'sim_2':
        return materialIcon('sim_card');
      case 'total_tx_traffic':
        return materialIcon('arrow_upward');
      case 'total_rx_traffic':
        return materialIcon('arrow_downward');
      case 'cellular_tx_traffic':
        return materialIcon('arrow_upward');
      case 'cellular_rx_traffic':
        return materialIcon('arrow_downward');
      case 'mobile_data':
        return materialIcon('mobiledata_arrows');
      case 'mobile_data_roaming':
        return materialIcon('mobile_data_roaming');
      case 'nfc_state':
        return materialIcon('nfc');
      case 'bluetooth_state':
        return materialIcon('bluetooth');
      case 'bluetooth_connection':
        return materialIcon('bluetooth');
      case 'device_security':
        return materialIcon('security');
      case 'device_locked':
        return materialIcon('mobile_lock_portrait');
      case 'audio_sensor':
        return materialIcon('mobile_speaker');
      case 'audio_mode':
        return materialIcon('mobile_speaker');
      case 'headphone_state':
        return materialIcon('headphones');
      case 'speakerphone_state':
        return materialIcon('mobile_speaker');
      case 'volume_alarm':
        return materialIcon('notification_sound');
      case 'volume_call':
        return materialIcon('volume_up');
      case 'volume_music':
        return materialIcon('volume_up');
      case 'volume_ring':
        return materialIcon('volume_up');
      case 'volume_notification':
        return materialIcon('notification_sound');
      case 'volume_accessibility':
        return materialIcon('volume_up');
      case 'accurate_location':
        return materialIcon('my_location');
      case 'zone_background':
        return materialIcon('distance');
      case 'location_background':
        return materialIcon('update');
      case 'location_permission':
        return materialIcon('location_permission');
      case 'geocoded_location':
        return materialIcon('map_search');
      case 'last_update_trigger':
        return materialIcon('last_update_trigger');
      case 'last_reboot_time':
        return materialIcon('last_reboot_time');
      case 'do_not_disturb_sensor':
        return materialIcon('do_not_disturb_sensor');
      case 'app_memory':
        return materialIcon('memory');
      case 'app_process_state':
        return materialIcon('account_tree');
      case 'current_version':
        return materialIcon('circle');
      case 'active':
        return materialIcon('circle');
      case 'current_time_zone':
        return materialIcon('map_search');
      case 'harmony_os_security_patch':
        return materialIcon('security');
      case 'harmony_os_version':
        return materialIcon('circle');
      case 'harmony_operating_hand':
        return materialIcon('trackpad_input');
      case 'harmony_holding_hand':
        return materialIcon('mobile_hand');
      case 'screen_brightness':
        return materialIcon('brightness_6');
      case 'screen_off_timeout':
        return materialIcon('mobile_off');
      case 'screen_orientation':
        return materialIcon('screen_rotation');
      case 'screen_rotation':
        return materialIcon('screen_rotation');
      case 'light_sensor':
        return materialIcon('sunny');
      case 'proximity_sensor':
        return materialIcon('leak_add');
      case 'storage_sensor':
        return materialIcon('hard_disk');
      case 'is_interactive':
        return materialIcon('touch_app');
      case 'power_save':
        return materialIcon('battery_charging_full');
      case 'is_idle':
        return materialIcon('mode_night');
      default:
        return materialIcon('settings');
    }
  }
}
