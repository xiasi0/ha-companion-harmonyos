import { Localization } from '../../shared/i18n/Localization';
import { materialIcon } from '../../shared/icons/AppIconModels';
import { HEALTH_DAILY_SENSOR_IDS, HEALTH_WORKOUT_SENSOR_IDS } from '../../services/HarmonyHealthSensorModels';
import { SensorEntry, SensorGroup } from './SensorModels';

const HEALTH_SENSOR_TITLE_KEYS: Record<string, string> = {
  'health_steps_today': 'health_sensor_steps_today',
  'health_calories_today': 'health_sensor_calories_today',
  'health_distance_today': 'health_sensor_distance_today',
  'health_workout_count_today': 'health_sensor_workout_count_today',
  'health_last_workout': 'health_sensor_last_workout',
  'health_last_workout_duration': 'health_sensor_last_workout_duration',
  'health_last_workout_calories': 'health_sensor_last_workout_calories',
  'health_last_workout_distance': 'health_sensor_last_workout_distance'
};

const HEALTH_SENSOR_ICON_NAMES: Record<string, string> = {
  'health_steps_today': 'directions_walk',
  'health_calories_today': 'directions_run',
  'health_distance_today': 'pin_road_2',
  'health_workout_count_today': '_123',
  'health_last_workout': 'avg_time',
  'health_last_workout_duration': 'avg_time',
  'health_last_workout_calories': 'directions_run',
  'health_last_workout_distance': 'pin_road_2'
};

export class HealthSensorCatalog {
  static groups(enabledSensorIds: string[] = []): SensorGroup[] {
    return [
      {
        title: Localization.t('health_sensor_group_daily_activity'),
        sensors: HealthSensorCatalog.sensors(HEALTH_DAILY_SENSOR_IDS, enabledSensorIds)
      },
      {
        title: Localization.t('health_sensor_group_workout'),
        sensors: HealthSensorCatalog.sensors(HEALTH_WORKOUT_SENSOR_IDS, enabledSensorIds)
      }
    ];
  }

  private static sensors(ids: string[], enabledSensorIds: string[]): SensorEntry[] {
    const result: SensorEntry[] = [];
    for (let i = 0; i < ids.length; i++) {
      result.push(HealthSensorCatalog.sensor(ids[i], enabledSensorIds));
    }
    return result;
  }

  private static sensor(id: string, enabledSensorIds: string[]): SensorEntry {
    return {
      id,
      title: Localization.t(HEALTH_SENSOR_TITLE_KEYS[id]),
      icon: materialIcon(HEALTH_SENSOR_ICON_NAMES[id]),
      enabled: HealthSensorCatalog.contains(enabledSensorIds, id),
      summary: ''
    };
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
