import { SettingsRow } from '../settings/components/SettingsRow';
import { SettingsBoundary } from '../settings/components/SettingsBoundary';
import { SettingsUiConfig } from '../settings/components/SettingsUiConfig';
import { SettingsDialogUiConfig } from '../settings/components/SettingsDialogUiConfig';
import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import { infoSettingsItem } from '../../models/SettingsItem';
import { NotificationRecentRecord } from './NotificationRecentStore';
import { NotificationService } from './NotificationService';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import common from '@ohos.app.ability.common';

@CustomDialog
@Component
struct NotificationDetailDialog {
  controller: CustomDialogController;
  @Prop title: string = '';
  @Prop text: string = '';
  @Prop meta: string = '';
  @Prop dark: boolean = false;
  onClose: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text(this.title)
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(HaTheme.textPrimary(this.dark))
        .width('100%')

      Scroll() {
        Column({ space: 12 }) {
          Text(this.text)
            .fontSize(15)
            .lineHeight(22)
            .fontColor(HaTheme.textSecondary(this.dark))
            .width('100%')

          if (this.meta.length > 0) {
            Text(this.meta)
              .fontSize(12)
              .fontColor(HaTheme.textMuted(this.dark))
              .width('100%')
          }
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 320 })
      .scrollBar(BarState.Auto)

      Row() {
        Blank()
          .layoutWeight(1)

        Button(Localization.t('action_confirm'))
          .height(SettingsDialogUiConfig.dialogButtonHeight)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(SettingsUiConfig.notificationEventColor)
          .backgroundColor(SettingsDialogUiConfig.transparentBackground)
          .borderRadius(SettingsDialogUiConfig.dialogButtonRadius)
          .onClick((): void => {
            this.onClose();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(SettingsDialogUiConfig.dialogPadding())
    .backgroundColor(HaTheme.surface(this.dark))
  }
}

@Component
export struct NotificationHistoryPage {
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @StorageLink('notificationHistoryRevision') @Watch('onHistoryRevisionChanged') historyRevision: number = 0;
  @State records: NotificationRecentRecord[] = [];
  @State detailTitle: string = '';
  @State detailText: string = '';
  @State detailMeta: string = '';
  private scroller: Scroller = new Scroller();
  private detailDialogOpen: boolean = false;
  private detailDialogController: CustomDialogController = new CustomDialogController({
    builder: NotificationDetailDialog({
      title: this.detailTitle,
      text: this.detailText,
      meta: this.detailMeta,
      dark: this.appResolvedDark,
      onClose: (): void => {
        this.closeRecordDetail();
      }
    }),
    cancel: (): void => {
      this.closeRecordDetail();
    },
    autoCancel: true,
    alignment: DialogAlignment.Center,
    maskColor: SettingsDialogUiConfig.dialogMaskColor,
    width: SettingsDialogUiConfig.dialogWidth(),
    cornerRadius: SettingsDialogUiConfig.dialogCornerRadius,
    openAnimation: { duration: SettingsDialogUiConfig.dialogOpenDuration, curve: Curve.EaseOut },
    closeAnimation: { duration: SettingsDialogUiConfig.dialogCloseDuration, curve: Curve.EaseIn }
  });
  onBack: () => void = () => {};
  onClearAll: () => void = () => {};
  onSwipeBack: () => void = () => {};

  aboutToAppear(): void {
    this.refreshHistory();
  }

  private onHistoryRevisionChanged(): void {
    this.refreshHistory();
  }

  private refreshHistory(): void {
    const context = this.getUIContext().getHostContext() as common.Context;
    NotificationService.listRecent(context)
      .then((records: NotificationRecentRecord[]): void => {
        this.records = records;
      })
      .catch((): void => {
        this.records = [];
      });
  }

  private openRecord(record: NotificationRecentRecord): void {
    this.showRecordDetail(record);
    if (!record.unread) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.Context;
    NotificationService.markRead(context, record.localId)
      .then((): void => {
        this.records = this.records.map((item: NotificationRecentRecord): NotificationRecentRecord => {
          if (item.localId !== record.localId) {
            return item;
          }
          return {
            localId: item.localId,
            notificationId: item.notificationId,
            serverInstanceId: item.serverInstanceId,
            title: item.title,
            text: item.text,
            additionalText: item.additionalText,
            source: item.source,
            dataJson: item.dataJson,
            receivedAt: item.receivedAt,
            unread: false
          };
        });
      })
      .catch((): void => {});
  }

  private showRecordDetail(record: NotificationRecentRecord): void {
    this.detailTitle = record.title.length > 0 ? record.title : Localization.t('app_name');
    this.detailText = record.text;
    const parts: string[] = [];
    if (record.additionalText.length > 0) {
      parts.push(record.additionalText);
    } else if (record.source.length > 0) {
      parts.push(record.source);
    }
    parts.push(this.formatReceivedAt(record.receivedAt));
    this.detailMeta = parts.join('\n');
    if (!this.detailDialogOpen) {
      this.detailDialogController.open();
      this.detailDialogOpen = true;
    }
  }

  private closeRecordDetail(): void {
    if (!this.detailDialogOpen) {
      return;
    }
    this.detailDialogController.close();
    this.detailDialogOpen = false;
  }

  private formatReceivedAt(receivedAt: number): string {
    const date = new Date(receivedAt);
    const now = new Date();
    const hour = NotificationHistoryPage.twoDigits(date.getHours());
    const minute = NotificationHistoryPage.twoDigits(date.getMinutes());
    if (date.toDateString() === now.toDateString()) {
      return `${hour}:${minute}`;
    }
    const month = NotificationHistoryPage.twoDigits(date.getMonth() + 1);
    const day = NotificationHistoryPage.twoDigits(date.getDate());
    return `${month}-${day} ${hour}:${minute}`;
  }

  private static twoDigits(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  @Builder
  private renderHistoryGroup(): void {
    Column() {
      if (this.records.length === 0) {
        SettingsRow({
          item: infoSettingsItem(
            'notifications',
            Localization.t('notifications_history_empty_title'),
            Localization.t('notifications_history_empty_summary')
          )
        })
      } else {
        ForEach(this.records, (record: NotificationRecentRecord, index?: number) => {
          this.renderHistoryItem(record);
          if ((index ?? 0) < this.records.length - 1) {
            SettingsBoundary()
          }
        }, (record: NotificationRecentRecord) =>
          `${record.localId}-${record.receivedAt}-${record.unread ? 'unread' : 'read'}-${this.historyRevision}`)
      }
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  @Builder
  private renderHistoryItem(record: NotificationRecentRecord): void {
    Row({ space: 12 }) {
      Column() {
        if (record.unread) {
          Circle()
            .width(8)
            .height(8)
            .fill(SettingsUiConfig.notificationEventColor)
        }
      }
      .width(16)
      .height(48)
      .justifyContent(FlexAlign.Center)

      Column({ space: 4 }) {
        Row() {
          Text(record.title.length > 0 ? record.title : Localization.t('app_name'))
            .fontSize(16)
            .fontWeight(record.unread ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(HaTheme.textPrimary(this.appResolvedDark))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.formatReceivedAt(record.receivedAt))
            .fontSize(12)
            .fontColor(HaTheme.textMuted(this.appResolvedDark))
            .maxLines(1)
            .margin({ left: 8 })
        }
        .width('100%')

        Text(record.text)
          .fontSize(14)
          .fontColor(HaTheme.textSecondary(this.appResolvedDark))
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (record.additionalText.length > 0 || record.source.length > 0) {
          Text(record.additionalText.length > 0 ? record.additionalText : record.source)
            .fontSize(12)
            .fontColor(HaTheme.textMuted(this.appResolvedDark))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: SettingsUiConfig.rowMinHeight })
    .padding(SettingsUiConfig.rowPadding())
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.openRecord(record);
    })
  }

  @Builder
  private renderHistoryList(): void {
    List({ scroller: this.scroller, space: SettingsUiConfig.listSpace }) {
      ListItem() {
        this.renderHistoryGroup()
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

  build() {
    HdsNavigation() {
      Column() {
        this.renderHistoryList()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .constraintSize({ maxWidth: this.contentMaxWidth })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .titleBar(SettingsUiConfig.titleBar(
      Localization.t('notifications_history'),
      this.onBack,
      this.appResolvedDark,
      undefined,
      {
        icon: new SymbolGlyphModifier($r('sys.symbol.clean')),
        label: Localization.t('notifications_clear_all'),
        action: this.onClearAll
      }
    ))
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
