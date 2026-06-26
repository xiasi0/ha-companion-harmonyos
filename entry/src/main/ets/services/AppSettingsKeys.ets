export interface AppSettingsKeySet {
  PREFERENCES_NAME: string;
  WEBSOCKET_MODE: string;
  SERVER_NAME_OVERRIDE: string;
  SERVER_EXTERNAL_URL: string;
  SERVER_INTERNAL_URL: string;
  SECURE_CONNECTION_CHOICE: string;
  HOME_NETWORK_NAME: string;
  HOME_WIFI_SSIDS_JSON: string;
  PRIORITIZE_INTERNAL: string;
  TRUST_SERVER: string;
  APP_LOCK_ENABLED: string;
  APP_LOCK_HOME_BYPASS: string;
  SESSION_TIMEOUT: string;
  SENSOR_BATTERY_SOC: string;
  SENSOR_CHARGING_STATUS: string;
  SENSOR_PLUGGED_TYPE: string;
  SENSOR_BEARER_TYPES: string;
  SENSOR_LAST_UPDATE_TRIGGER: string;
  SENSOR_LOCATION_BACKGROUND: string;
  SENSOR_ZONE_BACKGROUND: string;
  SENSOR_ACCURATE_LOCATION: string;
  SENSOR_DIRECT_ENABLED_JSON: string;
  HEALTH_AUTHORIZATION_CHECKED_AT: string;
  HEALTH_LAST_ERROR: string;
  HEALTH_LAST_SYNC_AT: string;
  LOCATION_HISTORY_JSON: string;
  LOCATION_SENT_MODE: string;
  LOCATION_DIAGNOSTICS_JSON: string;
  LOCATION_GEOFENCE_STATUS: string;
  SENSOR_DEFAULT_MIGRATION_VERSION: string;
  SENSOR_UPDATE_FREQUENCY: string;
  FULL_SCREEN_ENABLED: string;
  SCREEN_ORIENTATION: string;
  KEEP_SCREEN_ON_ENABLED: string;
  PAGE_ZOOM_LEVEL: string;
  PINCH_TO_ZOOM_ENABLED: string;
  AUTO_PLAY_VIDEO_ENABLED: string;
  ALWAYS_SHOW_FIRST_VIEW: string;
  APP_LANGUAGE: string;
  APP_THEME: string;
  SERVICE_CARD_UPDATE_FREQUENCY: string;
  ASSIST_WAKE_DETECTION_ENABLED: string;
  ASSIST_WAKE_WORD: string;
  ASSIST_PROBABILITY_CUTOFF: string;
  GESTURE_SWIPE_LEFT_TWO: string;
  GESTURE_SWIPE_LEFT_THREE: string;
  GESTURE_SWIPE_RIGHT_TWO: string;
  GESTURE_SWIPE_RIGHT_THREE: string;
  GESTURE_SWIPE_UP_TWO: string;
  GESTURE_SWIPE_UP_THREE: string;
  GESTURE_SWIPE_DOWN_TWO: string;
  GESTURE_SWIPE_DOWN_THREE: string;
}

export const AppSettingsKeys: AppSettingsKeySet = {
  PREFERENCES_NAME: 'ha_app_settings',
  WEBSOCKET_MODE: 'websocket_mode',
  SERVER_NAME_OVERRIDE: 'server_name_override',
  SERVER_EXTERNAL_URL: 'server_external_url',
  SERVER_INTERNAL_URL: 'server_internal_url',
  SECURE_CONNECTION_CHOICE: 'secure_connection_choice',
  HOME_NETWORK_NAME: 'home_network_name',
  HOME_WIFI_SSIDS_JSON: 'home_wifi_ssids_json',
  PRIORITIZE_INTERNAL: 'prioritize_internal',
  TRUST_SERVER: 'trust_server',
  APP_LOCK_ENABLED: 'app_lock_enabled',
  APP_LOCK_HOME_BYPASS: 'app_lock_home_bypass',
  SESSION_TIMEOUT: 'session_timeout',
  SENSOR_BATTERY_SOC: 'sensor_battery_soc_enabled',
  SENSOR_CHARGING_STATUS: 'sensor_charging_status_enabled',
  SENSOR_PLUGGED_TYPE: 'sensor_plugged_type_enabled',
  SENSOR_BEARER_TYPES: 'sensor_bearer_types_enabled',
  SENSOR_LAST_UPDATE_TRIGGER: 'sensor_last_update_trigger_enabled',
  SENSOR_LOCATION_BACKGROUND: 'sensor_location_background_enabled',
  SENSOR_ZONE_BACKGROUND: 'sensor_zone_background_enabled',
  SENSOR_ACCURATE_LOCATION: 'sensor_accurate_location_enabled',
  SENSOR_DIRECT_ENABLED_JSON: 'sensor_direct_enabled_json',
  HEALTH_AUTHORIZATION_CHECKED_AT: 'health_authorization_checked_at',
  HEALTH_LAST_ERROR: 'health_last_error',
  HEALTH_LAST_SYNC_AT: 'health_last_sync_at',
  LOCATION_HISTORY_JSON: 'location_history_json',
  LOCATION_SENT_MODE: 'location_sent_mode',
  LOCATION_DIAGNOSTICS_JSON: 'location_diagnostics_json',
  LOCATION_GEOFENCE_STATUS: 'location_geofence_status',
  SENSOR_DEFAULT_MIGRATION_VERSION: 'sensor_default_migration_version',
  SENSOR_UPDATE_FREQUENCY: 'sensor_update_frequency',
  FULL_SCREEN_ENABLED: 'full_screen_enabled',
  SCREEN_ORIENTATION: 'screen_orientation',
  KEEP_SCREEN_ON_ENABLED: 'keep_screen_on_enabled',
  PAGE_ZOOM_LEVEL: 'page_zoom_level',
  PINCH_TO_ZOOM_ENABLED: 'pinch_to_zoom_enabled',
  AUTO_PLAY_VIDEO_ENABLED: 'auto_play_video_enabled',
  ALWAYS_SHOW_FIRST_VIEW: 'always_show_first_view_enabled',
  APP_LANGUAGE: 'app_language',
  APP_THEME: 'app_theme',
  SERVICE_CARD_UPDATE_FREQUENCY: 'service_card_update_frequency',
  ASSIST_WAKE_DETECTION_ENABLED: 'assist_wake_detection_enabled',
  ASSIST_WAKE_WORD: 'assist_wake_word',
  ASSIST_PROBABILITY_CUTOFF: 'assist_probability_cutoff',
  GESTURE_SWIPE_LEFT_TWO: 'gesture_swipe_left_two',
  GESTURE_SWIPE_LEFT_THREE: 'gesture_swipe_left_three',
  GESTURE_SWIPE_RIGHT_TWO: 'gesture_swipe_right_two',
  GESTURE_SWIPE_RIGHT_THREE: 'gesture_swipe_right_three',
  GESTURE_SWIPE_UP_TWO: 'gesture_swipe_up_two',
  GESTURE_SWIPE_UP_THREE: 'gesture_swipe_up_three',
  GESTURE_SWIPE_DOWN_TWO: 'gesture_swipe_down_two',
  GESTURE_SWIPE_DOWN_THREE: 'gesture_swipe_down_three'
};

export const AppSettingsScopedKeys: string[] = [
  AppSettingsKeys.WEBSOCKET_MODE,
  AppSettingsKeys.SERVER_NAME_OVERRIDE,
  AppSettingsKeys.SERVER_EXTERNAL_URL,
  AppSettingsKeys.SERVER_INTERNAL_URL,
  AppSettingsKeys.SECURE_CONNECTION_CHOICE,
  AppSettingsKeys.HOME_NETWORK_NAME,
  AppSettingsKeys.HOME_WIFI_SSIDS_JSON,
  AppSettingsKeys.PRIORITIZE_INTERNAL,
  AppSettingsKeys.TRUST_SERVER,
  AppSettingsKeys.APP_LOCK_ENABLED,
  AppSettingsKeys.APP_LOCK_HOME_BYPASS,
  AppSettingsKeys.SESSION_TIMEOUT,
  AppSettingsKeys.SENSOR_BATTERY_SOC,
  AppSettingsKeys.SENSOR_CHARGING_STATUS,
  AppSettingsKeys.SENSOR_PLUGGED_TYPE,
  AppSettingsKeys.SENSOR_BEARER_TYPES,
  AppSettingsKeys.SENSOR_LAST_UPDATE_TRIGGER,
  AppSettingsKeys.SENSOR_LOCATION_BACKGROUND,
  AppSettingsKeys.SENSOR_ZONE_BACKGROUND,
  AppSettingsKeys.SENSOR_ACCURATE_LOCATION,
  AppSettingsKeys.SENSOR_DIRECT_ENABLED_JSON,
  AppSettingsKeys.HEALTH_LAST_SYNC_AT,
  AppSettingsKeys.LOCATION_HISTORY_JSON,
  AppSettingsKeys.LOCATION_SENT_MODE,
  AppSettingsKeys.LOCATION_DIAGNOSTICS_JSON,
  AppSettingsKeys.LOCATION_GEOFENCE_STATUS,
  AppSettingsKeys.SENSOR_DEFAULT_MIGRATION_VERSION,
  AppSettingsKeys.SENSOR_UPDATE_FREQUENCY,
  AppSettingsKeys.FULL_SCREEN_ENABLED,
  AppSettingsKeys.SCREEN_ORIENTATION,
  AppSettingsKeys.KEEP_SCREEN_ON_ENABLED,
  AppSettingsKeys.PAGE_ZOOM_LEVEL,
  AppSettingsKeys.PINCH_TO_ZOOM_ENABLED,
  AppSettingsKeys.AUTO_PLAY_VIDEO_ENABLED,
  AppSettingsKeys.ALWAYS_SHOW_FIRST_VIEW,
  AppSettingsKeys.APP_LANGUAGE,
  AppSettingsKeys.APP_THEME,
  AppSettingsKeys.SERVICE_CARD_UPDATE_FREQUENCY,
  AppSettingsKeys.ASSIST_WAKE_DETECTION_ENABLED,
  AppSettingsKeys.ASSIST_WAKE_WORD,
  AppSettingsKeys.ASSIST_PROBABILITY_CUTOFF,
  AppSettingsKeys.GESTURE_SWIPE_LEFT_TWO,
  AppSettingsKeys.GESTURE_SWIPE_LEFT_THREE,
  AppSettingsKeys.GESTURE_SWIPE_RIGHT_TWO,
  AppSettingsKeys.GESTURE_SWIPE_RIGHT_THREE,
  AppSettingsKeys.GESTURE_SWIPE_UP_TWO,
  AppSettingsKeys.GESTURE_SWIPE_UP_THREE,
  AppSettingsKeys.GESTURE_SWIPE_DOWN_TWO,
  AppSettingsKeys.GESTURE_SWIPE_DOWN_THREE
];
