import common from '@ohos.app.ability.common';
import audio from '@ohos.multimedia.audio';
import { media } from '@kit.MediaKit';

const WAKE_WORD_PROMPT_RAWFILE = 'wake_word_triggered.flac';

export class WakeWordPromptSoundService {
  private soundPool: media.SoundPool | undefined = undefined;
  private soundId: number = 0;
  private loading: Promise<void> | undefined = undefined;

  prepare(context: common.Context): void {
    this.ensureLoaded(context).catch((): void => {});
  }

  play(context: common.Context): void {
    this.ensureLoaded(context)
      .then(async (): Promise<void> => {
        if (this.soundPool && this.soundId > 0) {
          await this.soundPool.play(this.soundId, {
            loop: 0,
            leftVolume: 1,
            rightVolume: 1,
            priority: 1
          });
        }
      })
      .catch((): void => {});
  }

  async release(): Promise<void> {
    const soundPool = this.soundPool;
    this.soundPool = undefined;
    this.soundId = 0;
    this.loading = undefined;
    if (soundPool) {
      try {
        await soundPool.release();
      } catch (_) {
      }
    }
  }

  private ensureLoaded(context: common.Context): Promise<void> {
    if (this.soundPool && this.soundId > 0) {
      return Promise.resolve();
    }
    if (!this.loading) {
      this.loading = this.load(context)
        .catch((err: Error): Promise<never> => {
          this.loading = undefined;
          throw err;
        });
    }
    return this.loading;
  }

  private async load(context: common.Context): Promise<void> {
    const audioRendererInfo: audio.AudioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_VOICE_ASSISTANT,
      rendererFlags: 1
    };
    let soundPool: media.SoundPool | undefined = undefined;
    try {
      soundPool = await media.createSoundPool(1, audioRendererInfo);
      const fileDescriptor = await context.resourceManager.getRawFd(WAKE_WORD_PROMPT_RAWFILE);
      let soundId = 0;
      try {
        soundId = await soundPool.load(fileDescriptor.fd, fileDescriptor.offset, fileDescriptor.length);
      } finally {
        await context.resourceManager.closeRawFd(WAKE_WORD_PROMPT_RAWFILE);
      }
      this.soundPool = soundPool;
      this.soundId = soundId;
    } catch (err) {
      if (soundPool) {
        try {
          await soundPool.release();
        } catch (_) {
        }
      }
      throw WakeWordPromptSoundService.toError(err);
    }
  }

  private static toError(err: Error | string | number | boolean | Object): Error {
    if (err instanceof Error) {
      return err;
    }
    try {
      return new Error(JSON.stringify(err));
    } catch (_) {
      return new Error(String(err));
    }
  }
}
