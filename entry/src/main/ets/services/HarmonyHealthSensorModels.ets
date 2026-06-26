export const HEALTH_DAILY_SENSOR_IDS: string[] = [
  'health_steps_today',
  'health_calories_today',
  'health_distance_today'
];

export const HEALTH_WORKOUT_SENSOR_IDS: string[] = [
  'health_workout_count_today',
  'health_last_workout',
  'health_last_workout_duration',
  'health_last_workout_calories',
  'health_last_workout_distance'
];

export const HEALTH_SENSOR_IDS: string[] = HEALTH_DAILY_SENSOR_IDS.concat(HEALTH_WORKOUT_SENSOR_IDS);

export function isHealthSensorId(sensorId: string): boolean {
  for (let i = 0; i < HEALTH_SENSOR_IDS.length; i++) {
    if (HEALTH_SENSOR_IDS[i] === sensorId) {
      return true;
    }
  }
  return false;
}
