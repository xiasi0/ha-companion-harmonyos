import common from '@ohos.app.ability.common';
import audio from '@ohos.multimedia.audio';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import {
  getAvailableModels,
  MicroWakeWordDetector,
  MicroWakeWordError,
  MicroWakeWordEvent,
  MicroWakeWordModel,
  MicroWakeWordState
} from 'micro-wake-word';
import { LongRunningTaskService } from '../background/LongRunningTaskService';

const DEFAULT_PROBABILITY_CUTOFF = 0.85;
const DEFAULT_SLIDING_WINDOW_SIZE = 5;
const OKAY_NABU_MODEL_NAME = 'Okay Nabu';

export type AssistWakeWordRuntimeStatus =
  'disabled' |
  'starting' |
  'listening' |
  'stopped' |
  'no_model' |
  'permission_required' |
  'error';

export interface AssistWakeWordRuntimeSnapshot {
  enabled: boolean;
  wakeWord: string;
  probabilityCutoff: string;
}

export interface AssistWakeWordRuntimeCallbacks {
  onDetected: (wakeWordName: string, microphoneReleased: Promise<void>) => void;
  onModelsChanged: (models: MicroWakeWordModel[]) => void;
  onStatus: (status: AssistWakeWordRuntimeStatus, message: string) => void;
  onConfigChanged?: (probabilityCutoff: number, slidingWindowSize: number) => void;
}

export class AssistWakeWordRuntimeService {
  private detector: MicroWakeWordDetector | undefined = undefined;
  private callbacks: AssistWakeWordRuntimeCallbacks | undefined = undefined;
  private models: MicroWakeWordModel[] = [];
  private requestedKey: string = '';
  private configKey: string = '';
  private starting: boolean = false;
  private detected: boolean = false;
  private context: common.UIAbilityContext | undefined = undefined;

  async start(
    context: common.Context,
    snapshot: AssistWakeWordRuntimeSnapshot,
    callbacks: AssistWakeWordRuntimeCallbacks
  ): Promise<void> {
    this.callbacks = callbacks;
    this.context = context as common.UIAbilityContext;
    if (!snapshot.enabled) {
      await this.stop();
      this.emitStatus('disabled', 'disabled');
      return;
    }
    const requestedKey = `${snapshot.enabled}|${snapshot.wakeWord}|${snapshot.probabilityCutoff}`;
    if (this.detector && this.requestedKey === requestedKey && this.detector.getState() === 'listening') {
      return;
    }
    if (this.starting) {
      return;
    }
    this.starting = true;
    this.emitStatus('starting', 'starting');
    try {
      if (!await this.ensureMicrophonePermission(context)) {
        await this.stop();
        this.emitStatus('permission_required', 'permission_required');
        return;
      }
      await LongRunningTaskService.ensureAudioRecordingActive(context as common.UIAbilityContext);
      const models = await getAvailableModels(context);
      this.models = models;
      callbacks.onModelsChanged(models);
      if (models.length === 0) {
        await this.stop();
        this.emitStatus('no_model', 'no_model');
        return;
      }
      const model = AssistWakeWordRuntimeService.selectModel(models, snapshot.wakeWord);
      const cutoff = AssistWakeWordRuntimeService.parseProbabilityCutoff(snapshot.probabilityCutoff);
      callbacks.onConfigChanged?.(cutoff, DEFAULT_SLIDING_WINDOW_SIZE);
      const nextKey = `${snapshot.enabled}|${snapshot.wakeWord}|${model.name}|${cutoff}`;
      if (this.detector && this.configKey === nextKey && this.detector.getState() === 'listening') {
        this.requestedKey = requestedKey;
        this.emitStatus('listening', model.name);
        return;
      }
      await this.stopDetectorOnly();
      this.requestedKey = requestedKey;
      this.configKey = nextKey;
      this.detected = false;
      this.detector = new MicroWakeWordDetector({
        context,
        modelName: model.name,
        sourceType: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION,
        probabilityCutoff: cutoff,
        slidingWindowSize: DEFAULT_SLIDING_WINDOW_SIZE,
        onWakeWord: (event: MicroWakeWordEvent): void => this.handleWakeWord(event),
        onStateChange: (state: MicroWakeWordState): void => this.handleStateChange(state, model.name),
        onError: (error: MicroWakeWordError): void => this.handleError(error)
      });
      await this.detector.start();
      this.emitStatus('listening', model.name);
    } catch (err) {
      await this.stopDetectorOnly();
      await this.stopAudioRecordingTask();
      this.emitStatus('error', AssistWakeWordRuntimeService.stringifyError(err));
    } finally {
      this.starting = false;
    }
  }

  async refresh(
    context: common.Context,
    snapshot: AssistWakeWordRuntimeSnapshot,
    callbacks: AssistWakeWordRuntimeCallbacks
  ): Promise<void> {
    await this.start(context, snapshot, callbacks);
  }

  async stop(): Promise<void> {
    await this.stopDetectorOnly();
    this.configKey = '';
    this.requestedKey = '';
    this.detected = false;
    await this.stopAudioRecordingTask();
    this.emitStatus('stopped', 'stopped');
  }

  async release(): Promise<void> {
    if (this.detector) {
      try {
        await this.detector.release();
      } catch (_) {
      }
    }
    this.detector = undefined;
    this.configKey = '';
    this.requestedKey = '';
    this.detected = false;
    await this.stopAudioRecordingTask();
    this.emitStatus('stopped', 'stopped');
  }

  static parseProbabilityCutoff(value: string): number {
    const parsed = Number.parseFloat(value.trim());
    if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 1) {
      return DEFAULT_PROBABILITY_CUTOFF;
    }
    return parsed;
  }

  static selectModel(models: MicroWakeWordModel[], wakeWord: string): MicroWakeWordModel {
    if (models.length === 0) {
      throw new Error('No wake word model available');
    }
    const exact = models.find((model: MicroWakeWordModel): boolean => model.name === wakeWord);
    if (exact) {
      return exact;
    }
    const match = /^wake_word_(\d+)$/.exec(wakeWord);
    if (match) {
      const index = Number.parseInt(match[1], 10) - 1;
      if (index === 0) {
        const okayNabu = models.find((model: MicroWakeWordModel): boolean => model.name === OKAY_NABU_MODEL_NAME);
        return okayNabu ?? models[0];
      }
      if (index >= 0 && index < models.length) {
        return models[index];
      }
    }
    const okayNabu = models.find((model: MicroWakeWordModel): boolean => model.name === OKAY_NABU_MODEL_NAME);
    return okayNabu ?? models[0];
  }

  static modelsToJson(models: MicroWakeWordModel[]): string {
    const safeModels = models.map((model: MicroWakeWordModel): MicroWakeWordModel => {
      return {
        name: model.name,
        version: model.version
      };
    });
    return JSON.stringify(safeModels);
  }

  private async ensureMicrophonePermission(context: common.Context): Promise<boolean> {
    try {
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, ['ohos.permission.MICROPHONE']);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (_) {
      return false;
    }
  }

  private async stopDetectorOnly(): Promise<void> {
    const detector = this.detector;
    if (!detector) {
      return;
    }
    this.detector = undefined;
    await this.stopDetector(detector);
  }

  private async stopDetector(detector: MicroWakeWordDetector): Promise<void> {
    try {
      await detector.stop();
    } catch (_) {
    }
  }

  private async stopDetectorCapture(detector: MicroWakeWordDetector): Promise<void> {
    try {
      await detector.stopCapture();
    } catch (_) {
      await this.stopDetector(detector);
    }
  }

  private handleWakeWord(event: MicroWakeWordEvent): void {
    if (this.detected) {
      return;
    }
    this.detected = true;
    const modelName = event.model.name;
    const detector = this.detector;
    this.detector = undefined;
    const microphoneReleased = detector
      ? new Promise<void>((resolve): void => {
        setTimeout((): void => {
          this.stopDetectorCapture(detector)
            .then((): void => {
              resolve();
            })
            .catch((): void => {
              resolve();
            });
        }, 0);
      })
      : Promise.resolve();
    this.callbacks?.onDetected(modelName, microphoneReleased);
  }

  private handleStateChange(state: MicroWakeWordState, modelName: string): void {
    if (state === 'starting') {
      this.emitStatus('starting', modelName);
      return;
    }
    if (state === 'listening') {
      this.emitStatus('listening', modelName);
      return;
    }
    if (state === 'idle' || state === 'stopping' || state === 'released') {
      this.emitStatus('stopped', modelName);
    }
  }

  private handleError(error: MicroWakeWordError): void {
    this.emitStatus('error', error.cause ?? error.message);
  }

  private emitStatus(status: AssistWakeWordRuntimeStatus, message: string): void {
    this.callbacks?.onStatus(status, message);
  }

  private async stopAudioRecordingTask(): Promise<void> {
    const context = this.context;
    if (!context) {
      return;
    }
    await LongRunningTaskService.stopAudioRecording(context).catch((): void => {});
  }

  private static stringifyError(err: Error | string | number | boolean | Object): string {
    if (err instanceof Error) {
      return err.message ? `${err.name}: ${err.message}` : err.name;
    }
    try {
      return JSON.stringify(err);
    } catch (_) {
      return String(err);
    }
  }
}
