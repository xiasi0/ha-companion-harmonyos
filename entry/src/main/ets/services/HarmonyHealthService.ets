import common from '@ohos.app.ability.common';
import { healthStore } from '@kit.HealthServiceKit';
import { SensorAttributes, SensorDescriptor } from './HarmonySensorModels';
import { isHealthSensorId } from './HarmonyHealthSensorModels';

const HEALTH_ICON = 'mdi:heart-pulse';
const HEALTH_TEXT_UNAVAILABLE = 'unavailable';
const HEALTH_TEXT_UNAUTHORIZED = 'unauthorized';
const HEALTH_CALORIES_PER_KILOCALORIE = 1000;
const HEALTH_MILLISECONDS_PER_MINUTE = 60 * 1000;
const HEALTH_MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000;
const HEALTH_TODAY_WORKOUT_READ_COUNT = 50;
const HEALTH_RECENT_WORKOUT_READ_COUNT = 20;
const HEALTH_RECENT_WORKOUT_LOOKBACK_DAYS = 7;

export type HarmonyHealthAuthorizationState =
  'authorized' | 'partial_authorized' | 'unauthorized' | 'not_logged_in' | 'network_error' | 'privacy_not_agreed' | 'unavailable';

interface HarmonyHealthAuthorizationScope {
  state: HarmonyHealthAuthorizationState;
  dailyActivityAuthorized: boolean;
  workoutsAuthorized: boolean;
}

export interface HarmonyHealthDailyActivity {
  steps: number | null;
  calories: number | null;
  distance: number | null;
}

export interface HarmonyHealthWorkoutSummary {
  todayCount: number;
  lastStartedAt: number | null;
  lastDuration: number | null;
  lastCalories: number | null;
  lastDistance: number | null;
}

export interface HarmonyHealthSnapshot {
  authorizationState: HarmonyHealthAuthorizationState;
  dailyActivityAuthorized: boolean;
  workoutsAuthorized: boolean;
  dailyActivity: HarmonyHealthDailyActivity;
  workouts: HarmonyHealthWorkoutSummary;
  errorSummary: string;
  updatedAt: number;
}

export class HarmonyHealthService {
  private initialized: boolean = false;

  static isHealthSensorId(sensorId: string): boolean {
    return isHealthSensorId(sensorId);
  }

  async checkAuthorization(context?: common.Context): Promise<HarmonyHealthAuthorizationState> {
    if (context) {
      await this.init(context);
    }
    try {
      return (await this.authorizationScope()).state;
    } catch (error) {
      return HarmonyHealthService.authorizationStateFromError(error);
    }
  }

  async requestAuthorization(context: common.UIAbilityContext): Promise<HarmonyHealthAuthorizationState> {
    await this.init(context);
    try {
      const response = await healthStore.requestAuthorizations(context, HarmonyHealthService.authorizationRequest());
      return HarmonyHealthService.authorizationScopeFromTypes(response.readDataTypes).state;
    } catch (error) {
      return HarmonyHealthService.authorizationStateFromError(error);
    }
  }

  async cancelAuthorization(context: common.Context): Promise<HarmonyHealthAuthorizationState> {
    await this.init(context);
    try {
      await healthStore.cancelAuthorizations();
      return this.checkAuthorization();
    } catch (error) {
      return HarmonyHealthService.authorizationStateFromError(error);
    }
  }

  async readSnapshot(context: common.Context): Promise<HarmonyHealthSnapshot> {
    const updatedAt = Date.now();
    try {
      await this.init(context);
      const scope = await this.authorizationScope();
      if (!scope.dailyActivityAuthorized && !scope.workoutsAuthorized) {
        return HarmonyHealthService.emptySnapshot(scope, '', updatedAt);
      }
      const dailyActivity = scope.dailyActivityAuthorized
        ? await this.readDailyActivity(new Date())
        : HarmonyHealthService.emptyDailyActivity();
      const workouts = scope.workoutsAuthorized
        ? await this.readWorkouts(updatedAt)
        : HarmonyHealthService.emptyWorkoutSummary();
      return {
        authorizationState: scope.state,
        dailyActivityAuthorized: scope.dailyActivityAuthorized,
        workoutsAuthorized: scope.workoutsAuthorized,
        dailyActivity,
        workouts,
        errorSummary: '',
        updatedAt
      };
    } catch (error) {
      return HarmonyHealthService.emptySnapshot(
        HarmonyHealthService.emptyAuthorizationScope(HarmonyHealthService.authorizationStateFromError(error)),
        HarmonyHealthService.errorSummary(error),
        updatedAt
      );
    }
  }

  static descriptors(snapshot: HarmonyHealthSnapshot, enabledSensorIds: string[]): SensorDescriptor[] {
    const enabled = (id: string): boolean => HarmonyHealthService.contains(enabledSensorIds, id);
    const attrs: SensorAttributes = {
      health_authorization: snapshot.authorizationState,
      health_daily_activity_authorized: snapshot.dailyActivityAuthorized,
      health_workouts_authorized: snapshot.workoutsAuthorized,
      health_error: snapshot.errorSummary,
      sensor_updated_at: snapshot.updatedAt,
      health_last_workout_started_at: snapshot.workouts.lastStartedAt,
      health_last_workout_duration: snapshot.workouts.lastDuration,
      health_last_workout_calories: snapshot.workouts.lastCalories,
      health_last_workout_distance: snapshot.workouts.lastDistance
    };
    return [
      {
        id: 'health_steps_today',
        name: 'Health steps today',
        type: 'sensor',
        icon: 'mdi:walk',
        state: HarmonyHealthService.categoryNumberState(snapshot.dailyActivity.steps, snapshot.dailyActivityAuthorized),
        attributes: attrs,
        enabled: enabled('health_steps_today'),
        unitOfMeasurement: 'steps',
        stateClass: 'total_increasing'
      },
      {
        id: 'health_calories_today',
        name: 'Health calories today',
        type: 'sensor',
        icon: HEALTH_ICON,
        state: HarmonyHealthService.categoryNumberState(snapshot.dailyActivity.calories, snapshot.dailyActivityAuthorized),
        attributes: attrs,
        enabled: enabled('health_calories_today'),
        unitOfMeasurement: 'kcal',
        stateClass: 'total_increasing'
      },
      {
        id: 'health_distance_today',
        name: 'Health distance today',
        type: 'sensor',
        icon: 'mdi:map-marker-distance',
        state: HarmonyHealthService.categoryNumberState(snapshot.dailyActivity.distance, snapshot.dailyActivityAuthorized),
        attributes: attrs,
        enabled: enabled('health_distance_today'),
        unitOfMeasurement: 'm',
        stateClass: 'total_increasing'
      },
      {
        id: 'health_workout_count_today',
        name: 'Health workouts today',
        type: 'sensor',
        icon: 'mdi:run',
        state: snapshot.workoutsAuthorized ? snapshot.workouts.todayCount : HEALTH_TEXT_UNAUTHORIZED,
        attributes: attrs,
        enabled: enabled('health_workout_count_today'),
        stateClass: 'measurement'
      },
      {
        id: 'health_last_workout',
        name: 'Health last workout',
        type: 'sensor',
        icon: 'mdi:calendar-clock',
        state: snapshot.workoutsAuthorized
          ? HarmonyHealthService.timeState(snapshot.workouts.lastStartedAt)
          : HEALTH_TEXT_UNAUTHORIZED,
        attributes: attrs,
        enabled: enabled('health_last_workout')
      },
      {
        id: 'health_last_workout_duration',
        name: 'Health last workout duration',
        type: 'sensor',
        icon: 'mdi:timer-outline',
        state: HarmonyHealthService.categoryNumberState(snapshot.workouts.lastDuration, snapshot.workoutsAuthorized),
        attributes: attrs,
        enabled: enabled('health_last_workout_duration'),
        unitOfMeasurement: 'min',
        stateClass: 'measurement'
      },
      {
        id: 'health_last_workout_calories',
        name: 'Health last workout calories',
        type: 'sensor',
        icon: HEALTH_ICON,
        state: HarmonyHealthService.categoryNumberState(snapshot.workouts.lastCalories, snapshot.workoutsAuthorized),
        attributes: attrs,
        enabled: enabled('health_last_workout_calories'),
        unitOfMeasurement: 'kcal',
        stateClass: 'measurement'
      },
      {
        id: 'health_last_workout_distance',
        name: 'Health last workout distance',
        type: 'sensor',
        icon: 'mdi:map-marker-distance',
        state: HarmonyHealthService.categoryNumberState(snapshot.workouts.lastDistance, snapshot.workoutsAuthorized),
        attributes: attrs,
        enabled: enabled('health_last_workout_distance'),
        unitOfMeasurement: 'm',
        stateClass: 'measurement'
      }
    ];
  }

  private async init(context: common.Context): Promise<void> {
    if (this.initialized) {
      return;
    }
    await healthStore.init(context);
    this.initialized = true;
  }

  private async readDailyActivity(date: Date): Promise<HarmonyHealthDailyActivity> {
    const request: healthStore.samplePointHelper.dailyActivities.AggregateRequest = {
      dataType: healthStore.samplePointHelper.dailyActivities.DATA_TYPE,
      startLocalDate: HarmonyHealthService.localDate(date),
      endLocalDate: HarmonyHealthService.localDate(date),
      groupBy: {
        unitType: healthStore.GroupUnitType.DAY,
        duration: 1
      },
      metrics: {
        step: ['sum'],
        calorie: ['sum'],
        distance: ['sum']
      }
    };
    let rows: healthStore.samplePointHelper.dailyActivities.AggregateResult[] = [];
    try {
      rows = await healthStore.aggregateData<healthStore.samplePointHelper.dailyActivities.AggregateResult>(request);
    } catch (error) {
      throw new Error(HarmonyHealthService.errorSummary(error as Error | string | number | boolean | Object));
    }
    if (rows.length === 0) {
      return {
        steps: null,
        calories: null,
        distance: null
      };
    }
    const fields = rows[0].fields;
    return {
      steps: HarmonyHealthService.metricSum(fields.step),
      calories: HarmonyHealthService.caloriesToKilocalories(HarmonyHealthService.metricSum(fields.calorie)),
      distance: HarmonyHealthService.metricSum(fields.distance)
    };
  }

  private async readWorkouts(endTime: number): Promise<HarmonyHealthWorkoutSummary> {
    const todayRows = await this.readWorkoutRows(
      HarmonyHealthService.startOfDay(endTime),
      endTime,
      HEALTH_TODAY_WORKOUT_READ_COUNT
    );
    const recentRows = await this.readWorkoutRows(
      endTime - HEALTH_RECENT_WORKOUT_LOOKBACK_DAYS * HEALTH_MILLISECONDS_PER_DAY,
      endTime,
      HEALTH_RECENT_WORKOUT_READ_COUNT
    );
    const latest = recentRows.length > 0 ? recentRows[0] : undefined;
    return {
      todayCount: todayRows.length,
      lastStartedAt: latest ? latest.startTime : null,
      lastDuration: latest && typeof latest.duration === 'number' ? Math.round(latest.duration / HEALTH_MILLISECONDS_PER_MINUTE) : null,
      lastCalories: latest ? HarmonyHealthService.caloriesToKilocalories(
        HarmonyHealthService.summaryNumber(latest.summaries, 'calorie', 'totalCalories')
      ) : null,
      lastDistance: latest ? HarmonyHealthService.summaryNumber(latest.summaries, 'distance', 'totalDistance') : null
    };
  }

  private async readWorkoutRows(startTime: number, endTime: number, count: number): Promise<healthStore.ExerciseSequence[]> {
    const request: healthStore.ExerciseSequenceReadRequest = {
      startTime,
      endTime,
      count,
      sortOrder: healthStore.SortOrder.DESC,
      exerciseType: null
    };
    try {
      return await healthStore.readData<healthStore.ExerciseSequence>(request);
    } catch (error) {
      throw new Error(HarmonyHealthService.errorSummary(error as Error | string | number | boolean | Object));
    }
  }

  private static authorizationRequest(): healthStore.AuthorizationRequest {
    return {
      readDataTypes: [
        healthStore.samplePointHelper.dailyActivities.DATA_TYPE,
        healthStore.exerciseSequenceHelper.DATA_TYPE
      ],
      writeDataTypes: []
    };
  }

  private async authorizationScope(): Promise<HarmonyHealthAuthorizationScope> {
    const response = await healthStore.getAuthorizations(HarmonyHealthService.authorizationRequest());
    return HarmonyHealthService.authorizationScopeFromTypes(response.readDataTypes);
  }

  private static authorizationScopeFromTypes(granted: healthStore.DataType[]): HarmonyHealthAuthorizationScope {
    const dailyId = healthStore.samplePointHelper.dailyActivities.DATA_TYPE.id;
    const exerciseId = healthStore.exerciseSequenceHelper.DATA_TYPE.id;
    const dailyActivityAuthorized = HarmonyHealthService.hasDataTypeId(granted, dailyId);
    const workoutsAuthorized = HarmonyHealthService.hasDataTypeId(granted, exerciseId);
    let state: HarmonyHealthAuthorizationState = 'unauthorized';
    if (dailyActivityAuthorized && workoutsAuthorized) {
      state = 'authorized';
    } else if (dailyActivityAuthorized || workoutsAuthorized) {
      state = 'partial_authorized';
    }
    return {
      state,
      dailyActivityAuthorized,
      workoutsAuthorized
    };
  }

  private static hasDataTypeId(types: healthStore.DataType[], id: number): boolean {
    for (let i = 0; i < types.length; i++) {
      if (types[i].id === id) {
        return true;
      }
    }
    return false;
  }

  private static localDate(date: Date): string {
    return `${HarmonyHealthService.padDatePart(date.getMonth() + 1)}/${HarmonyHealthService.padDatePart(date.getDate())}/${date.getFullYear()}`;
  }

  private static startOfDay(time: number): number {
    const date = new Date(time);
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  }

  private static metricSum(value: Object | undefined): number | null {
    if (!value) {
      return null;
    }
    const metric = value as Record<string, number>;
    return typeof metric.sum === 'number' ? metric.sum : null;
  }

  private static summaryNumber(summary: Object, key: string, field: string): number | null {
    const summaries = summary as Record<string, Object>;
    const item = summaries[key] as Record<string, number>;
    if (!item) {
      return null;
    }
    const value = item[field];
    return typeof value === 'number' && Number.isFinite(value) ? value : null;
  }

  private static caloriesToKilocalories(value: number | null): number | null {
    return typeof value === 'number' && Number.isFinite(value) ? Math.round(value / HEALTH_CALORIES_PER_KILOCALORIE) : null;
  }

  private static numberState(value: number | null): number | string {
    return typeof value === 'number' ? value : HEALTH_TEXT_UNAVAILABLE;
  }

  private static categoryNumberState(value: number | null, authorized: boolean): number | string {
    return authorized ? HarmonyHealthService.numberState(value) : HEALTH_TEXT_UNAUTHORIZED;
  }

  private static timeState(value: number | null): string {
    if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
      return HEALTH_TEXT_UNAVAILABLE;
    }
    const date = new Date(value);
    return `${date.getFullYear()}-${HarmonyHealthService.padDatePart(date.getMonth() + 1)}-${HarmonyHealthService.padDatePart(date.getDate())} ` +
      `${HarmonyHealthService.padDatePart(date.getHours())}:${HarmonyHealthService.padDatePart(date.getMinutes())}`;
  }

  private static padDatePart(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static emptySnapshot(
    scope: HarmonyHealthAuthorizationScope,
    errorSummary: string,
    updatedAt: number
  ): HarmonyHealthSnapshot {
    return {
      authorizationState: scope.state,
      dailyActivityAuthorized: scope.dailyActivityAuthorized,
      workoutsAuthorized: scope.workoutsAuthorized,
      dailyActivity: HarmonyHealthService.emptyDailyActivity(),
      workouts: HarmonyHealthService.emptyWorkoutSummary(),
      errorSummary,
      updatedAt
    };
  }

  private static emptyAuthorizationScope(state: HarmonyHealthAuthorizationState): HarmonyHealthAuthorizationScope {
    return {
      state,
      dailyActivityAuthorized: false,
      workoutsAuthorized: false
    };
  }

  private static emptyDailyActivity(): HarmonyHealthDailyActivity {
    return {
      steps: null,
      calories: null,
      distance: null
    };
  }

  private static emptyWorkoutSummary(): HarmonyHealthWorkoutSummary {
    return {
      todayCount: 0,
      lastStartedAt: null,
      lastDuration: null,
      lastCalories: null,
      lastDistance: null
    };
  }

  private static authorizationStateFromError(error: Error | string | number | boolean | Object): HarmonyHealthAuthorizationState {
    const code = HarmonyHealthService.errorCode(error);
    const summary = HarmonyHealthService.errorSummary(error);
    if (summary.indexOf('Application certificate fingerprint is incorrect') >= 0) {
      return 'unavailable';
    }
    if (code === 1002702001 || code === 1002702002) {
      return 'not_logged_in';
    }
    if (code === 1002701001) {
      return 'network_error';
    }
    if (code === 1002703001) {
      return 'privacy_not_agreed';
    }
    if (code === 201) {
      return 'unauthorized';
    }
    return 'unavailable';
  }

  private static errorCode(error: Error | string | number | boolean | Object): number {
    if (typeof error === 'number') {
      return error;
    }
    const candidate = error as Record<string, Object>;
    const code = candidate['code'];
    return typeof code === 'number' ? code : 0;
  }

  private static errorSummary(error: Error | string | number | boolean | Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    if (typeof error === 'string') {
      return error;
    }
    const candidate = error as Record<string, Object>;
    const message = candidate['message'];
    if (typeof message === 'string') {
      return message;
    }
    const code = HarmonyHealthService.errorCode(error);
    return code > 0 ? `health_error_${code}` : '';
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
