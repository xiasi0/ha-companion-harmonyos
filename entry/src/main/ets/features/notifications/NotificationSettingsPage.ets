import { SettingsBoundary } from '../settings/components/SettingsBoundary';
import { SettingsRow } from '../settings/components/SettingsRow';
import { SettingsUiConfig } from '../settings/components/SettingsUiConfig';
import { NotificationCapability, NotificationService } from './NotificationService';
import { SettingsItem, actionSettingsItem } from '../../models/SettingsItem';
import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import common from '@ohos.app.ability.common';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct NotificationSettingsPage {
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @State permissionEnabled: boolean = false;
  @State busy: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onOpenHistory: () => void = () => {};
  onSwipeBack: () => void = () => {};

  aboutToAppear(): void {
    this.refreshPermission();
  }

  private refreshPermission(): void {
    NotificationService.isEnabled()
      .then((enabled: boolean): void => {
        this.permissionEnabled = enabled;
      })
      .catch((): void => {
        this.permissionEnabled = false;
      });
  }

  private handleAction(actionId: string): void {
    if (actionId.length === 0 || this.busy) {
      return;
    }
    if (actionId === 'open_notification_history') {
      this.onOpenHistory();
      return;
    }
    if (actionId === 'open_notification_settings') {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.busy = true;
      NotificationService.openSystemSettings(context)
        .then((enabled: boolean): void => {
          this.permissionEnabled = enabled;
        })
        .catch((): void => {})
        .finally((): void => {
          this.busy = false;
        });
    }
  }

  private iconForAction(actionId: string): string {
    if (actionId === 'open_notification_history') {
      return 'info';
    }
    return 'notifications';
  }

  private settingsItem(item: NotificationCapability): SettingsItem {
    return actionSettingsItem(
      this.iconForAction(item.actionId),
      item.title,
      item.summary,
      item.status,
      item.actionId
    );
  }

  @Builder
  private renderItem(item: NotificationCapability): void {
    SettingsRow({
      item: this.settingsItem(item),
      onAction: (actionId: string): void => {
        this.handleAction(actionId);
      }
    })
    .enabled(item.actionId.length > 0 && !this.busy)
    .opacity(this.busy && item.actionId.length > 0 ? 0.58 : 1)
  }

  @Builder
  private renderSettingsGroup(): void {
    Column() {
      ForEach(NotificationService.settings(this.permissionEnabled), (item: NotificationCapability, index?: number) => {
        this.renderItem(item);
        if ((index ?? 0) < NotificationService.settings(this.permissionEnabled).length - 1) {
          SettingsBoundary()
        }
      }, (item: NotificationCapability) => `${item.title}-${item.status}`)
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  @Builder
  private renderSettingsList(): void {
    List({ scroller: this.scroller, space: SettingsUiConfig.listSpace }) {
      ListItem() {
        this.renderSettingsGroup()
      }
      .width('100%')
    }
    .padding(SettingsUiConfig.listPadding())
    .layoutWeight(1)
    .width('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(SettingsUiConfig.listContentEndOffset)
    .clip(false)
    .cachedCount(3, true)
    .scrollBar(SettingsUiConfig.scrollBarState())
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
  }

  @Builder
  private renderPageContent(): void {
      Column() {
        this.renderSettingsList()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .constraintSize({ maxWidth: this.contentMaxWidth })
  }

  build() {
    HdsNavigation() {
      this.renderPageContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .titleBar(SettingsUiConfig.titleBar(Localization.t('notifications_title'), this.onBack, this.appResolvedDark))
    .bindToScrollable([this.scroller])
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 24 }).onActionEnd((event: GestureEvent) => {
      if (event.offsetX > 60 || event.offsetX < -60) {
        this.onSwipeBack();
      }
    }))
  }
}
