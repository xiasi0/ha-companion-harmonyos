import { HaColors } from '../../shared/constants/HaStyle';
import { AppIconView } from '../../shared/icons/AppIconView';
import { systemIcon } from '../../shared/icons/AppIconModels';
import { Localization } from '../../shared/i18n/Localization';
import { HaTheme } from '../../shared/theme/HaTheme';
import { SettingsTextInput } from '../settings/components/SettingsTextInput';

export interface AssistMessage {
  id: number;
  role: string;
  text: string;
}
export interface AssistAgentOption {
  id: string;
  name: string;
}

@Component
export struct AssistConversationPage {
  @Prop
  microphoneGranted: boolean = false;
  @Prop
  @Watch('onListeningChanged')
  listening: boolean = false;
  @Prop
  pending: boolean = false;
  @Prop
  textMode: boolean = false;
  @Prop
  inputText: string = '';
  @Prop
  errorText: string = '';
  @Prop
  statusText: string = '';
  @Prop
  agentName: string = 'Home Assistant';
  @Prop
  agentLoading: boolean = false;
  @Prop
  pipelineReady: boolean = false;
  @Prop
  agentOptions: AssistAgentOption[] = [];
  @Prop
  selectedAgentId: string = '';
  @Prop
  @Watch('onMessagesChanged')
  messages: AssistMessage[] = [];
  @State
  agentPickerVisible: boolean = false;
  @State
  userScrolling: boolean = false;
  @State
  sheetOffsetY: number = 760;
  @State
  scrimOpacity: number = 0;
  @State
  closing: boolean = false;
  @State
  micBreathingScale: number = 1;
  @State
  micBreathingOpacity: number = 0;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private messageScroller: Scroller = new Scroller();
  private lastMessageSignature: string = '';
  private micBreathingToken: number = 0;
  onClose: () => void = () => {};
  onRequestMicrophone: () => void = () => {};
  onToggleMicrophone: () => void = () => {};
  onToggleTextMode: () => void = () => {};
  onInputChange: (value: string) => void = () => {};
  onSendText: () => void = () => {};
  onRefreshAgents: () => void = () => {};
  onSelectAgent: (agentId: string) => void = () => {};

  aboutToAppear(): void {
    this.sheetOffsetY = 760;
    this.scrimOpacity = 0;
    this.closing = false;
    setTimeout(() => {
      animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.sheetOffsetY = 0;
        this.scrimOpacity = 1;
      });
    }, 16);
    if (this.listening) {
      this.startMicBreathing();
    }
  }

  aboutToDisappear(): void {
    this.stopMicBreathing();
  }

  private closeWithAnimation(): void {
    if (this.closing) {
      return;
    }
    this.closing = true;
    animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.sheetOffsetY = 760;
      this.scrimOpacity = 0;
    });
    setTimeout(() => {
      this.onClose();
    }, 230);
  }

  private micButtonColor(): string {
    return this.listening ? this.userBubbleColor() : HaColors.TRANSPARENT;
  }

  private userBubbleColor(): string {
    return this.appResolvedDark ? '#16414A' : '#D8F2FC';
  }

  private onListeningChanged(): void {
    if (this.listening) {
      this.startMicBreathing();
    } else {
      this.stopMicBreathing();
    }
  }

  private startMicBreathing(): void {
    const token = ++this.micBreathingToken;
    this.micBreathingScale = 1;
    this.micBreathingOpacity = 0.42;
    this.runMicBreathing(token);
  }

  private runMicBreathing(token: number): void {
    if (!this.listening || token !== this.micBreathingToken) {
      return;
    }
    animateTo({ duration: 860, curve: Curve.EaseInOut }, () => {
      this.micBreathingScale = 1.45;
      this.micBreathingOpacity = 0;
    });
    setTimeout(() => {
      if (!this.listening || token !== this.micBreathingToken) {
        return;
      }
      this.micBreathingScale = 1;
      this.micBreathingOpacity = 0.42;
      setTimeout(() => {
        this.runMicBreathing(token);
      }, 40);
    }, 900);
  }

  private stopMicBreathing(): void {
    this.micBreathingToken++;
    animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.micBreathingScale = 1;
      this.micBreathingOpacity = 0;
    });
  }

  private messageBubbleColor(message: AssistMessage): string {
    return message.role === 'user' ? this.userBubbleColor() : HaColors.BRAND;
  }

  private messageTextColor(message: AssistMessage): string {
    return message.role === 'user' ? HaTheme.textPrimary(this.appResolvedDark) : HaColors.ON_PRIMARY;
  }

  private messageSignature(): string {
    let signature = `${this.messages.length}`;
    for (let i = 0; i < this.messages.length; i++) {
      signature += `:${this.messages[i].id}:${this.messages[i].text.length}`;
    }
    return signature;
  }

  private onMessagesChanged(): void {
    const nextSignature = this.messageSignature();
    if (nextSignature === this.lastMessageSignature) {
      return;
    }
    this.lastMessageSignature = nextSignature;
    if (this.userScrolling) {
      return;
    }
    setTimeout(() => {
      if (!this.userScrolling) {
        this.messageScroller.scrollEdge(Edge.Bottom);
      }
    }, 16);
  }

  @Builder
  private renderMessage(message: AssistMessage): void {
    Row() {
      if (message.role === 'user') {
        Blank()
      }

      Text(message.text.trim().length > 0 ? message.text : ' ')
        .fontSize(message.text.trim().length > 0 ? 15 : 12)
        .lineHeight(message.text.trim().length > 0 ? 21 : 16)
        .fontColor(message.text.trim().length > 0 ?
          this.messageTextColor(message) :
          HaColors.TRANSPARENT)
        .padding(message.text.trim().length > 0 ? { left: 9, right: 9, top: 6, bottom: 6 } : { left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(this.messageBubbleColor(message))
        .borderRadius({
          topLeft: 12,
          topRight: 12,
          bottomLeft: message.role === 'user' ? 12 : 0,
          bottomRight: message.role === 'user' ? 0 : 12
        })
        .width(message.text.trim().length > 0 ? '78%' : 42)

      if (message.role !== 'user') {
        Blank()
      }
    }
    .width('100%')
    .padding({
      left: message.role === 'user' ? 24 : 0,
      right: message.role === 'user' ? 0 : 24,
      top: 6,
      bottom: 6
    })
  }

  @Builder
  private renderAgentPicker(): void {
    if (this.agentPickerVisible) {
      Column() {
        ForEach(this.agentOptions, (option: AssistAgentOption) => {
          Row() {
            Text(option.name)
              .fontSize(15)
              .lineHeight(22)
              .fontColor(HaTheme.textPrimary(this.appResolvedDark))
              .layoutWeight(1)

            if (option.id === this.selectedAgentId) {
              Text('✓')
                .fontSize(16)
                .fontColor(HaColors.PRIMARY)
            }
          }
          .width('100%')
          .height(44)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.agentPickerVisible = false;
            this.onSelectAgent(option.id);
          })
        }, (option: AssistAgentOption) => option.id.length > 0 ? option.id : 'default')
      }
      .width(220)
      .padding({ top: 6, bottom: 6 })
      .backgroundColor(HaTheme.surface(this.appResolvedDark))
      .borderRadius(8)
      .shadow({
        radius: 14,
        color: HaColors.SCRIM,
        offsetX: 0,
        offsetY: 4
      })
      .margin({ top: 8 })
    }
  }

  @Builder
  private renderHeader(): void {
    Column({ space: 0 }) {
      Text(Localization.t('assist_title'))
        .fontSize(20)
        .lineHeight(24)
        .fontColor(HaTheme.textPrimary(this.appResolvedDark))

      Row({ space: 4 }) {
        Text(this.agentLoading ? Localization.t('assist_loading') : this.agentName)
          .fontSize(13)
          .lineHeight(17)
          .fontColor(HaTheme.textPrimary(this.appResolvedDark))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        AppIconView({
          icon: systemIcon('chevron_down'),
          iconSize: 16,
          slotSize: 16,
          color: HaTheme.textPrimary(this.appResolvedDark)
        })
      }
      .padding({ left: 0, right: 0, top: 1, bottom: 1 })
      .onClick(() => {
        if (this.agentLoading) {
          return;
        }
        if (this.agentOptions.length <= 1) {
          this.onRefreshAgents();
        }
        this.agentPickerVisible = !this.agentPickerVisible;
      })

      this.renderAgentPicker();
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 4 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private renderVoiceControls(): void {
    Row() {
      Blank()
        .width(48)
        .height(64)

      Blank()
        .layoutWeight(1)

      Stack({ alignContent: Alignment.Center }) {
        if (this.listening) {
          Column()
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.userBubbleColor())
            .opacity(this.micBreathingOpacity)
            .scale({ x: this.micBreathingScale, y: this.micBreathingScale })
        }

        Button() {
          AppIconView({
            icon: systemIcon('mic'),
            iconSize: 28,
            slotSize: 48,
            color: HaTheme.textPrimary(this.appResolvedDark)
          })
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor(this.micButtonColor())
        .padding(0)
        .enabled(this.pipelineReady && !this.pending)
        .onClick(() => {
          if (!this.pipelineReady) {
            return;
          }
          if (!this.microphoneGranted) {
            this.onRequestMicrophone();
          } else {
            this.onToggleMicrophone();
          }
        })
      }
      .width(64)
      .height(64)

      Blank()
        .layoutWeight(1)

      Button() {
        AppIconView({
          icon: systemIcon('keyboard'),
          iconSize: 28,
          slotSize: 44,
          color: HaTheme.textPrimary(this.appResolvedDark)
        })
      }
      .width(56)
      .height(44)
      .backgroundColor(HaColors.TRANSPARENT)
      .padding(0)
      .enabled(this.pipelineReady && !this.pending)
      .onClick(() => {
        if (!this.pipelineReady) {
          return;
        }
        this.onToggleTextMode();
      })
    }
    .width('100%')
    .height(76)
    .padding({ left: 16, right: 16, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private renderTextControls(): void {
    Row({ space: 8 }) {
      SettingsTextInput({
        text: this.inputText,
        placeholder: Localization.t('assist_input_placeholder'),
        heightValue: 48,
        radiusValue: 24,
        horizontalPadding: 14,
        onChange: this.onInputChange
      })
      .enabled(this.pipelineReady && !this.pending)
      .layoutWeight(1)

      Button() {
        if (this.inputText.trim().length > 0) {
          AppIconView({
            icon: systemIcon('send'),
            iconSize: 24,
            slotSize: 44,
            color: HaTheme.textPrimary(this.appResolvedDark)
          })
        } else {
          AppIconView({
            icon: systemIcon('mic'),
            iconSize: 26,
            slotSize: 44,
            color: HaTheme.textPrimary(this.appResolvedDark)
          })
        }
      }
      .height(44)
      .width(48)
      .backgroundColor(HaColors.TRANSPARENT)
      .borderRadius(22)
      .enabled(this.pipelineReady && !this.pending)
      .onClick(() => {
        if (!this.pipelineReady) {
          return;
        }
        if (this.inputText.trim().length > 0) {
          this.onSendText();
        } else {
          this.onToggleTextMode();
        }
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 18 })
  }

  @Builder
  private renderMessageArea(): void {
    Scroll(this.messageScroller) {
      Column({ space: 0 }) {
        Blank()
          .layoutWeight(1)

        ForEach(this.messages, (message: AssistMessage) => {
          this.renderMessage(message);
        }, (message: AssistMessage) => `${message.id}-${message.text}`)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .onScrollStart(() => {
      this.userScrolling = true;
    })
    .onScrollStop(() => {
      this.userScrolling = false;
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(`rgba(0, 0, 0, ${0.38 * this.scrimOpacity})`)
        .onClick(() => {
          this.closeWithAnimation();
        })

      Column() {
        this.renderHeader();

        this.renderMessageArea();

        if (this.textMode) {
          this.renderTextControls();
        } else {
          this.renderVoiceControls();
        }
      }
      .width('100%')
      .height('64%')
      .backgroundColor(HaTheme.surface(this.appResolvedDark))
      .borderRadius({ topLeft: 26, topRight: 26 })
      .border({
        width: { top: 1, left: 1, right: 1, bottom: 0 },
        color: HaTheme.outline(this.appResolvedDark)
      })
      .shadow({
        radius: 18,
        color: HaColors.SCRIM,
        offsetX: 0,
        offsetY: -4
      })
      .translate({ x: 0, y: this.sheetOffsetY })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
  }
}
