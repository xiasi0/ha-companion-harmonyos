import { PrimaryButton } from '../../shared/components/PrimaryButton';
import { Localization } from '../../shared/i18n/Localization';
import { HaTheme } from '../../shared/theme/HaTheme';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsRadioRow } from './components/SettingsRadioRow';
import { SettingsTextInput } from './components/SettingsTextInput';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

@Component
export struct ServerSettingDetailPage {
  @Prop
  title: string = '';
  @Prop
  summary: string = '';
  @Prop
  body: string = '';
  @Prop
  detailKey: string = '';
  @Prop
  textValue: string = '';
  @Prop
  optionValue: string = '';
  @Prop
  contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onTextChange: (value: string) => void = () => {};
  onOptionChange: (value: string) => void = () => {};
  onSave: () => void = () => {};
  onHelp: () => void = () => {};
  onSwipeBack: () => void = () => {};

  private isTextDetail(): boolean {
    return this.detailKey === 'server_external_url' ||
      this.detailKey === 'server_session_timeout';
  }

  private inputPlaceholder(): string {
    if (this.detailKey === 'server_external_url') {
      return 'http://homeassistant.local:8123';
    }
    if (this.detailKey === 'server_session_timeout') {
      return '0';
    }
    return '';
  }

  private inputType(): InputType {
    if (this.detailKey === 'server_external_url') {
      return InputType.URL;
    }
    if (this.detailKey === 'server_session_timeout') {
      return InputType.Number;
    }
    return InputType.Normal;
  }

  private optionTitle(value: string): string {
    if (value === 'always') {
      return Localization.t('common_always');
    }
    return Localization.t('server_websocket_system');
  }

  private optionSummary(value: string): string {
    if (value === 'always') {
      return Localization.t('server_websocket_always_body');
    }
    return Localization.t('server_websocket_system_body');
  }

  private websocketDescription(): string {
    return Localization.t('server_websocket_description');
  }

  private selectedWebsocketValue(): string {
    return this.optionValue === 'always' ? 'always' : 'system';
  }

  @Builder
  private renderWebsocketOption(value: string): void {
    SettingsRadioRow({
      title: this.optionTitle(value),
      summary: this.optionSummary(value),
      selected: this.selectedWebsocketValue() === value,
      minHeight: 82,
      onSelect: (): void => {
        this.onOptionChange(value);
      }
    })
  }

  @Builder
  private renderWebsocketContent(): void {
    List({ scroller: this.scroller, space: SettingsUiConfig.listSpace }) {
      ListItem() {
        Column() {
          Text(this.websocketDescription())
            .fontSize(16)
            .fontColor(HaTheme.textPrimary(this.appResolvedDark))
            .lineHeight(26)
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        }
        .width('100%')
        .borderRadius(SettingsUiConfig.groupRadius)
        .backgroundColor(HaTheme.surface(this.appResolvedDark))
        .shadow(SettingsUiConfig.groupShadow())
      }
      .width('100%')

      ListItem() {
        Column() {
          this.renderWebsocketOption('system')
          SettingsBoundary()
          this.renderWebsocketOption('always')
        }
        .width('100%')
        .borderRadius(SettingsUiConfig.groupRadius)
        .backgroundColor(HaTheme.surface(this.appResolvedDark))
        .shadow(SettingsUiConfig.groupShadow())
        .padding(SettingsUiConfig.groupPadding)
      }
      .width('100%')
    }
    .padding(SettingsUiConfig.listPadding())
    .layoutWeight(1)
    .width('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth })
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(SettingsUiConfig.listContentEndOffset)
    .clip(false)
    .cachedCount(3, true)
    .scrollBar(SettingsUiConfig.scrollBarState())
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .alignListItem(ListItemAlign.Center)
  }

  @Builder
  private renderTextEditor(): void {
    Column({ space: 16 }) {
      SettingsTextInput({
        text: this.textValue,
        placeholder: this.inputPlaceholder(),
        inputType: this.inputType(),
        onChange: this.onTextChange
      })

      PrimaryButton({
        text: Localization.t('action_save'),
        maxWidth: this.contentMaxWidth,
        enabledValue: this.textValue.trim().length > 0,
        action: this.onSave
      })
    }
    .width('100%')
  }

  @Builder
  private renderGeneralContent(): void {
    Scroll(this.scroller) {
      Column({ space: 20 }) {
        if (this.summary.length > 0 && this.detailKey !== 'server_external_url') {
          Text(this.summary)
            .fontSize(14)
            .fontColor(HaTheme.textSecondary(this.appResolvedDark))
            .lineHeight(20)
            .width('100%')
        }

        if (this.body.length > 0 && this.detailKey !== 'server_external_url') {
          Text(this.body)
            .fontSize(16)
            .fontColor(HaTheme.textPrimary(this.appResolvedDark))
            .lineHeight(24)
            .width('100%')
        }

        if (this.isTextDetail()) {
          this.renderTextEditor()
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth })
      .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      .borderRadius(SettingsUiConfig.groupRadius)
      .backgroundColor(HaTheme.surface(this.appResolvedDark))
      .shadow(SettingsUiConfig.groupShadow())
    }
    .layoutWeight(1)
    .width('100%')
    .padding(SettingsUiConfig.listPadding())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(SettingsUiConfig.scrollBarState())
    .clip(false)
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
  }

  @Builder
  private renderPageContent(): void {
    if (this.detailKey === 'server_websocket') {
      this.renderWebsocketContent()
    } else {
      this.renderGeneralContent()
    }
  }

  build() {
    HdsNavigation() {
      this.renderPageContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .titleBar(SettingsUiConfig.titleBar(this.title, this.onBack, this.appResolvedDark, this.onHelp))
    .bindToScrollable([this.scroller])
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetX > 60 || event.offsetX < -60) {
            this.onSwipeBack();
          }
        })
    )
  }
}
