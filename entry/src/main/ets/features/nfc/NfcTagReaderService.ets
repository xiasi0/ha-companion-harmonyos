import common from '@ohos.app.ability.common';
import { Want } from '@kit.AbilityKit';
import { tag } from '@kit.ConnectivityKit';
import { NfcTagService } from './NfcTagService';

export class NfcTagReaderService {
  static readonly COMPLETED_KEY: string = 'nfcReaderCompleted';
  static readonly ERROR_KEY: string = 'nfcReaderError';
  static readonly TICK_KEY: string = 'nfcReaderTick';
  private static reading: boolean = false;

  static handleWant(want: Want, context: common.Context): boolean {
    if (!NfcTagService.isSupported()) {
      return false;
    }
    if (NfcTagReaderService.reading ||
      AppStorage.get<boolean>('nfcReaderPending') === true) {
      return true;
    }
    let tagInfo: tag.TagInfo | undefined;
    try {
      tagInfo = tag.getTagInfo(want);
    } catch (_) {
      return false;
    }
    if (!tagInfo) {
      return false;
    }
    NfcTagReaderService.reading = true;
    NfcTagReaderService.publish('', false, true);
    NfcTagService.readTagId(tagInfo)
      .then((tagId: string): Promise<void> => {
        return NfcTagService.dispatchTag(context, tagId);
      })
      .then((): void => {
        NfcTagReaderService.publish('', true);
      })
      .catch((error: Error | string | number | boolean | Object): void => {
        NfcTagReaderService.publish(NfcTagReaderService.errorText(error), true);
      })
      .finally((): void => {
        NfcTagReaderService.reading = false;
      });
    return true;
  }

  private static publish(error: string, completed: boolean, pending: boolean = false): void {
    AppStorage.setOrCreate<boolean>(NfcTagReaderService.COMPLETED_KEY, completed);
    AppStorage.setOrCreate<string>(NfcTagReaderService.ERROR_KEY, error);
    if (pending) {
      AppStorage.setOrCreate<boolean>('nfcReaderPending', true);
    }
    const tick = AppStorage.get<number>(NfcTagReaderService.TICK_KEY) ?? 0;
    AppStorage.setOrCreate<number>(NfcTagReaderService.TICK_KEY, tick + 1);
  }

  private static errorText(error: Error | string | number | boolean | Object): string {
    return error instanceof Error ? error.message : String(error);
  }
}
