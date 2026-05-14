// ArkUI root page that hosts the application shell.
// Keep this file thin so lifecycle and business orchestration stay in app runtime classes.
import { AppBackDispatcher } from '../app/AppBackDispatcher';
import { AppShell } from '../app/AppShell';
import { AppRootLayoutSafeArea } from '../shared/ui/AppRootLayoutSafeArea';

@Entry
@Component
struct Index {
  private backDispatcher: AppBackDispatcher = new AppBackDispatcher();

  onBackPress(): boolean {
    return this.backDispatcher.handleBack();
  }

  build() {
    Stack() {
      AppShell({
        backDispatcher: this.backDispatcher
      })
    }
    .width('100%')
    .height('100%')
    .ignoreLayoutSafeArea(AppRootLayoutSafeArea.nonSafeAreaTypes(), AppRootLayoutSafeArea.ignoredImmersiveEdges())
  }
}
