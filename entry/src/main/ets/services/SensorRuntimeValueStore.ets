export interface HardwareSensorValues {
  light?: number;
  lightColorTemperature?: number;
  lightInfraredLuminance?: number;
  proximityDistance?: number;
  updatedAt?: number;
}

export interface MultimodalSensorValues {
  operatingHand?: number;
  holdingHand?: number;
  updatedAt?: number;
}

export interface GeocodedLocationValue {
  geocoderAvailable?: boolean;
  latitude?: number;
  longitude?: number;
  sourceTimeStamp?: number;
  placeName?: string;
  countryCode?: string;
  countryName?: string;
  administrativeArea?: string;
  subAdministrativeArea?: string;
  locality?: string;
  subLocality?: string;
  roadName?: string;
  subRoadName?: string;
  premises?: string;
  postalCode?: string;
}

export class SensorRuntimeValueStore {
  private static hardwareValues: HardwareSensorValues = {};
  private static multimodalValues: MultimodalSensorValues = {};
  private static geocodedLocation: GeocodedLocationValue = {};

  static hardware(): HardwareSensorValues {
    return SensorRuntimeValueStore.hardwareValues;
  }

  static updateHardware(values: HardwareSensorValues): void {
    SensorRuntimeValueStore.hardwareValues = values;
  }

  static multimodal(): MultimodalSensorValues {
    return SensorRuntimeValueStore.multimodalValues;
  }

  static updateMultimodal(values: MultimodalSensorValues): void {
    SensorRuntimeValueStore.multimodalValues = values;
  }

  static geocoded(): GeocodedLocationValue {
    return SensorRuntimeValueStore.geocodedLocation;
  }

  static updateGeocoded(value: GeocodedLocationValue): void {
    SensorRuntimeValueStore.geocodedLocation = value;
  }
}
