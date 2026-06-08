export interface SensorPreferenceSnapshot {
  batterySOCEnabled: boolean;
  chargingStatusEnabled: boolean;
  pluggedTypeEnabled: boolean;
  bearerTypesEnabled: boolean;
  lastUpdateTriggerEnabled: boolean;
  locationBackgroundEnabled: boolean;
  zoneBackgroundEnabled: boolean;
  accurateLocationEnabled: boolean;
  directSensorIds: string[];
}

export interface HarmonySensorSyncResult {
  registeredCount: number;
  updatedCount: number;
  locationUpdated: boolean;
  locationSummary: string;
}

export type HarmonyLocationSentMode = 'exact' | 'zone' | 'never';

export type SensorStateValue = string | number | boolean | null;

export interface SensorAttributes {
  latitude?: number | null;
  longitude?: number | null;
  accuracy?: number | null;
  timeStamp?: number | null;
  options?: string[];
  metered?: boolean;
  last_update_trigger?: string;
  location_sent?: string;
  gps_accuracy?: number | null;
  bssid?: string;
  hidden?: boolean;
  signal_level?: number;
  frequency?: number;
  link_speed?: number;
  ip_address?: string;
  version_code?: number;
  os_full_name?: string;
  sdk_api_version?: number;
  display_version?: string;
  security_patch?: string;
  manufacturer?: string;
  brand?: string;
  market_name?: string;
  product_model?: string;
  total_size?: number;
  free_size?: number;
  used_size?: number;
  used_percent?: number;
  power_mode?: string;
  min_volume?: number;
  max_volume?: number;
  volume_percent?: number;
  approximate_location?: boolean;
  precise_location?: boolean;
  background_location?: boolean;
  nfc_state?: string;
  display_state?: string;
  display_width?: number;
  display_height?: number;
  display_available_width?: number;
  display_available_height?: number;
  display_rotation?: number;
  display_density_pixels?: number;
  display_scaled_density?: number;
  display_x_dpi?: number;
  display_y_dpi?: number;
  sdr_nits?: number;
  max_headroom?: number;
  current_headroom?: number;
  hdr_formats?: string[];
  source_mode?: string;
  foldable?: boolean;
  fold_status?: string;
  fold_display_mode?: string;
  battery_voltage?: number;
  battery_current?: number;
  app_active?: boolean;
  app_memory_vss?: number;
  app_memory_native_heap_size?: number;
  app_memory_native_heap_allocated_size?: number;
  app_memory_native_heap_free_size?: number;
  app_memory_shared_dirty?: number;
  app_memory_private_dirty?: number;
  vibrator_count?: number;
  local_vibrator_count?: number;
  hd_haptic_supported?: boolean;
  supported_effects?: string[];
  color_temperature?: number;
  infrared_luminance?: number;
  sensor_updated_at?: number;
  step_detected?: boolean;
  geocoder_available?: boolean;
  place_name?: string;
  country_code?: string;
  country_name?: string;
  administrative_area?: string;
  sub_administrative_area?: string;
  locality?: string;
  sub_locality?: string;
  road_name?: string;
  sub_road_name?: string;
  premises?: string;
  postal_code?: string;
  audio_scene?: string;
  output_device_types?: string[];
  output_device_count?: number;
}

export interface SensorDescriptor {
  id: string;
  name: string;
  type: string;
  icon: string;
  state: SensorStateValue;
  attributes: SensorAttributes;
  enabled: boolean;
  deviceClass?: string;
  unitOfMeasurement?: string;
  stateClass?: string;
  entityCategory?: string;
}

export interface NetSnapshot {
  networkType: string;
  metered: boolean;
}

export interface SensorRegistrationWebhookData {
  unique_id: string;
  state: SensorStateValue;
  type: string;
  icon: string;
  attributes: SensorAttributes;
  name: string;
  disabled: boolean;
  device_class?: string;
  unit_of_measurement?: string;
  state_class?: string;
  entity_category?: string;
}

export interface RegisterSensorWebhookBody {
  type: string;
  data: SensorRegistrationWebhookData;
}

export interface SensorUpdateWebhookData {
  unique_id: string;
  state: SensorStateValue;
  type: string;
  icon: string;
  attributes: SensorAttributes;
}

export interface UpdateSensorStatesWebhookBody {
  type: string;
  data: SensorUpdateWebhookData[];
}

export interface UpdateLocationWebhookData {
  gps?: number[];
  gps_accuracy?: number;
  location_name?: string;
  battery?: number;
  speed?: number;
  altitude?: number;
  course?: number;
  vertical_accuracy?: number;
}

export interface UpdateLocationWebhookBody {
  type: string;
  data: UpdateLocationWebhookData;
}

export interface GetZonesWebhookBody {
  type: string;
}

export interface HttpTextResult {
  responseCode: number;
  body: string;
  failureSummary: string;
}

export interface WebhookResult {
  responseCode: number;
  body: string;
  failureSummary: string;
}
