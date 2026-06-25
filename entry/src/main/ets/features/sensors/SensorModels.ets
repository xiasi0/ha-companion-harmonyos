import { AppIconSpec } from '../../shared/icons/AppIconModels';

export interface SensorEntry {
  id: string;
  title: string;
  summary: string;
  icon: AppIconSpec;
  enabled: boolean;
}

export interface SensorGroup {
  title: string;
  sensors: SensorEntry[];
}

export enum SensorUpdateFrequency {
  NORMAL = 'normal',
  FAST_WHILE_CHARGING = 'fast_charging',
  FAST_ALWAYS = 'fast_always'
}

export function normalizeSensorUpdateFrequency(value: string): string {
  if (value === SensorUpdateFrequency.FAST_WHILE_CHARGING || value === SensorUpdateFrequency.FAST_ALWAYS) {
    return value;
  }
  return SensorUpdateFrequency.NORMAL;
}
