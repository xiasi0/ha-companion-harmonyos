export class AssistOverlayLifecycleService {
  private timer: number | undefined = undefined;
  private wakeSession: boolean = false;
  private busy: boolean = false;
  private generation: number = 0;
  private readonly onTimeout: () => void;
  private readonly delayMs: number;

  constructor(onTimeout: () => void, delayMs: number = 30000) {
    this.onTimeout = onTimeout;
    this.delayMs = delayMs;
  }

  beginWakeSession(): void {
    this.wakeSession = true;
    this.markBusy();
  }

  isWakeSession(): boolean {
    return this.wakeSession;
  }

  markActivity(): void {
    if (this.busy) {
      return;
    }
    this.armDismiss();
  }

  markBusy(): void {
    this.busy = true;
    this.clearTimer();
  }

  armDismiss(): void {
    this.busy = false;
    this.clearTimer();
    if (!this.wakeSession) {
      return;
    }
    const generation = this.generation;
    this.timer = setTimeout((): void => {
      if (generation !== this.generation || !this.wakeSession) {
        return;
      }
      this.timer = undefined;
      this.onTimeout();
    }, this.delayMs);
  }

  cancel(): void {
    this.wakeSession = false;
    this.busy = false;
    this.clearTimer();
  }

  private clearTimer(): void {
    this.generation += 1;
    if (this.timer !== undefined) {
      clearTimeout(this.timer);
      this.timer = undefined;
    }
  }
}
