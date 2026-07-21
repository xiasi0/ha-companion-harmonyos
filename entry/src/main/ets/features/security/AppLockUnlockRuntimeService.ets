import common from '@ohos.app.ability.common';
import { Localization } from '../../shared/i18n/Localization';
import { AppLockRuntimeService } from './AppLockRuntimeService';

export interface AppLockUnlockRuntimeState {
  appUnlocking: boolean;
  appLocked: boolean;
  message: string;
}

export class AppLockUnlockRuntimeService {
  static unlock(
    context: common.Context,
    state: AppLockUnlockRuntimeState,
    ignoreTransitions: () => void,
    onUnlocked: () => void = () => {}
  ): void {
    if (state.appUnlocking) {
      return;
    }
    state.appUnlocking = true;
    ignoreTransitions();
    AppLockRuntimeService.authenticateUnlock(context)
      .then((result): void => {
        state.appUnlocking = false;
        if (result.success) {
          state.appLocked = false;
          state.message = '';
          onUnlocked();
        } else {
          state.message = result.message.length > 0
            ? Localization.format('app_lock_auth_failed_with_message', 'message', result.message)
            : Localization.t('app_lock_auth_failed');
        }
      })
      .catch((): void => {
        state.appUnlocking = false;
        state.message = Localization.t('app_lock_auth_error');
      });
  }
}
