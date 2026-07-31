import common from '@ohos.app.ability.common';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { HaConversationAgent, HaConversationAgentsResult } from '../../services/HaApiService';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { HarmonySpeechService } from '../../services/HarmonySpeechService';
import { ServerManager } from '../../services/ServerManager';
import { UrlService } from '../../services/UrlService';
import { Localization } from '../../shared/i18n/Localization';
import { AppRoute } from '../../app/AppRoute';
import { AssistAgentOption, AssistMessage } from './AssistConversationPage';
import { AssistConversationCoordinator } from './AssistConversationCoordinator';
import { AssistOverlayHost } from './AssistOverlayHost';
import { AssistRuntimeService } from './AssistRuntimeService';

@Component
export struct AssistRuntimeHost {
  @StorageLink('assistAgentId') assistAgentId: string = '';

  @Prop route: number = AppRoute.ASSIST_CONVERSATION;
  @Prop baseUrl: string = '';
  @Prop accessToken: string = '';
  @Prop @Watch('onStartListeningSignalChanged') startListeningSignal: number = 0;
  @Prop startListeningRequested: boolean = false;

  @State private microphoneGranted: boolean = false;
  @State private listening: boolean = false;
  @State private pending: boolean = false;
  @State private textMode: boolean = false;
  @State private inputText: string = '';
  @State private responseText: string = '';
  @State private errorText: string = '';
  @State private statusText: string = '';
  @State private agents: HaConversationAgent[] = [];
  @State private agentLoading: boolean = false;
  @State private agentsReady: boolean = false;
  @State private messages: AssistMessage[] = [];
  @State private messageId: number = 1;

  private conversationId: string = '';
  private voiceInputMessageId: number = 0;
  private handledStartListeningSignal: number = 0;
  private pendingStartListening: boolean = false;
  private ttsRequestId: number = 0;
  private voiceStartRequestId: number = 0;
  private pipelineRequestId: number = 0;
  private speechService: HarmonySpeechService = new HarmonySpeechService();

  onClose: () => void = () => {};
  onAudioCaptureStart: () => Promise<void> = () => Promise.resolve();
  onSpeechComplete: () => void = () => {};
  onActivity: () => void = () => {};
  onBusy: () => void = () => {};

  aboutToAppear(): void {
    this.ensureConversationState();
    this.refreshAgents(false);
    this.consumeStartListeningSignal();
  }

  aboutToDisappear(): void {
    this.stopVoice(false);
    this.speechService.shutdown();
  }

  private ensureConversationState(): void {
    if (this.messages.length > 0) {
      return;
    }
    const state = AssistRuntimeService.openState(false);
    this.inputText = state.inputText;
    this.responseText = state.responseText;
    this.errorText = state.errorText;
    this.statusText = state.statusText;
    this.pending = state.pending;
    this.listening = state.listening;
    this.textMode = state.textMode;
    this.messageId = state.messageId;
    this.conversationId = state.conversationId;
    this.voiceInputMessageId = state.voiceInputMessageId;
    this.messages = state.messages;
  }

  private consumeStartListeningSignal(): void {
    if (this.route !== AppRoute.ASSIST_CONVERSATION || this.handledStartListeningSignal === this.startListeningSignal) {
      return;
    }
    this.handledStartListeningSignal = this.startListeningSignal;
    if (this.startListeningRequested && this.messages.length > 0) {
      this.startListeningInCurrentConversation();
      return;
    }
    this.resetConversation(this.startListeningRequested);
  }

  private onStartListeningSignalChanged(): void {
    this.consumeStartListeningSignal();
  }

  private resetConversation(startListening: boolean): void {
    const state = AssistRuntimeService.openState(startListening);
    this.inputText = state.inputText;
    this.responseText = state.responseText;
    this.errorText = state.errorText;
    this.statusText = state.statusText;
    this.pending = state.pending;
    this.listening = state.listening;
    this.textMode = state.textMode;
    this.messageId = state.messageId;
    this.conversationId = state.conversationId;
    this.voiceInputMessageId = state.voiceInputMessageId;
    this.messages = state.messages;
    this.pendingStartListening = startListening;
    this.refreshAgents(false);
    if (startListening && this.isPipelineReady()) {
      this.pendingStartListening = false;
      this.requestMicrophonePermission();
    }
  }

  private startListeningInCurrentConversation(): void {
    if (this.listening) {
      return;
    }
    this.pendingStartListening = true;
    if (!this.isPipelineReady()) {
      this.statusText = Localization.t('assist_loading');
      this.refreshAgents(false);
      this.onSpeechComplete();
      return;
    }
    this.pendingStartListening = false;
    this.requestMicrophonePermission();
  }

  private isPipelineReady(): boolean {
    return AssistConversationCoordinator.isPipelineReady(this.agentsReady, this.agents, this.agentLoading);
  }

  private refreshAgents(force: boolean = false): void {
    const normalizedBaseUrl = UrlService.normalizeBaseUrl(this.baseUrl);
    const token = this.accessToken.trim();
    if (normalizedBaseUrl.length === 0 || token.length === 0 || this.agentLoading) {
      return;
    }
    if (AssistRuntimeService.canSkipAgentRefresh(force, this.agentsReady, this.agents, this.agentLoading)) {
      return;
    }
    this.agentLoading = true;
    this.resolveAllowedBaseUrl()
      .then((baseUrl: string): Promise<HaConversationAgentsResult> => {
        if (baseUrl.length === 0) {
          const result: HaConversationAgentsResult = {
            responseCode: 0,
            agents: [],
            failureSummary: Localization.t('assist_connection_unavailable')
          };
          return Promise.resolve(result);
        }
        return AssistRuntimeService.fetchAgents(baseUrl, token);
      })
      .then((result: HaConversationAgentsResult): void => {
        this.agentLoading = false;
        const state = AssistRuntimeService.agentStateFromResult(result, this.assistAgentId);
        this.agents = state.agents;
        this.agentsReady = state.ready;
        this.assistAgentId = state.selectedAgentId;
        if (this.pendingStartListening && this.route === AppRoute.ASSIST_CONVERSATION && this.isPipelineReady()) {
          this.pendingStartListening = false;
          this.requestMicrophonePermission();
        }
      })
      .catch((): void => {
        this.agentLoading = false;
        this.agentsReady = false;
      });
  }

  private currentAgentName(): string {
    return AssistConversationCoordinator.currentAgentName(this.agents, this.assistAgentId);
  }

  private agentOptions(): AssistAgentOption[] {
    return AssistConversationCoordinator.agentOptions(this.agents);
  }

  private selectAgent(agentId: string): void {
    this.onActivity();
    this.assistAgentId = agentId;
    this.statusText = '';
  }

  private appendMessage(role: string, text: string): void {
    const next = AssistConversationCoordinator.appendMessage(this.messages, this.messageId, role, text);
    if (next !== this.messages) {
      this.messageId += 1;
      this.messages = next;
    }
  }

  private appendPlaceholder(role: string): number {
    const nextId = this.messageId;
    this.messageId += 1;
    this.messages = AssistConversationCoordinator.appendPlaceholder(this.messages, nextId, role);
    return nextId;
  }

  private updateMessage(targetMessageId: number, text: string): void {
    this.messages = AssistConversationCoordinator.updateMessage(this.messages, targetMessageId, text);
  }

  private requestMicrophonePermission(): void {
    this.onBusy();
    if (!this.isPipelineReady()) {
      this.statusText = Localization.t('assist_loading');
      this.refreshAgents(false);
      this.onSpeechComplete();
      return;
    }
    abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(this.getUIContext().getHostContext() as common.Context, ['ohos.permission.MICROPHONE'])
      .then((result): void => {
        this.microphoneGranted = result.authResults.length > 0 && result.authResults[0] === 0;
        this.errorText = this.microphoneGranted ? '' : Localization.t('assist_microphone_denied');
        if (this.microphoneGranted) {
          this.startVoice();
        } else {
          this.onSpeechComplete();
        }
      })
      .catch((err: Error | string | number | boolean | Object): void => {
        this.microphoneGranted = false;
        this.listening = false;
        this.errorText = Localization.format('assist_microphone_request_failed', 'error', this.stringifyError(err));
        this.onSpeechComplete();
      });
  }

  private toggleMicrophone(): void {
    this.onBusy();
    if (this.listening) {
      this.stopVoice(true);
      return;
    }
    if (!this.isPipelineReady()) {
      this.statusText = Localization.t('assist_loading');
      this.refreshAgents(false);
      this.onSpeechComplete();
      return;
    }
    this.requestMicrophonePermission();
  }

  private toggleTextMode(): void {
    if (!this.isPipelineReady()) {
      this.onActivity();
      this.statusText = Localization.t('assist_loading');
      this.refreshAgents(false);
      return;
    }
    if (!this.textMode && this.listening) {
      this.onBusy();
      this.stopVoice(false);
    } else {
      this.onActivity();
    }
    this.textMode = !this.textMode;
  }

  private startVoice(): void {
    this.onBusy();
    if (!this.isPipelineReady()) {
      this.statusText = Localization.t('assist_loading');
      this.refreshAgents(false);
      this.onSpeechComplete();
      return;
    }
    const requestId = this.voiceStartRequestId + 1;
    this.voiceStartRequestId = requestId;
    this.ttsRequestId += 1;
    this.speechService.stopSpeaking();
    this.onAudioCaptureStart()
      .then((): void => {
        if (requestId !== this.voiceStartRequestId) {
          return;
        }
        this.startVoiceAfterAudioReady();
      })
      .catch((): void => {
        if (requestId !== this.voiceStartRequestId) {
          return;
        }
        this.listening = false;
        this.statusText = '';
        this.onSpeechComplete();
      });
  }

  private startVoiceAfterAudioReady(): void {
    if (!this.isPipelineReady()) {
      this.statusText = Localization.t('assist_loading');
      this.refreshAgents(false);
      this.onSpeechComplete();
      return;
    }
    this.textMode = false;
    this.errorText = '';
    this.responseText = '';
    this.statusText = '';
    this.voiceInputMessageId = this.appendPlaceholder('user');
    this.listening = true;
    this.speechService.startRecognition({
      onStatus: (): void => {
        this.statusText = '';
      },
      onPartial: (text: string): void => {
        const value = text.trim();
        if (value.length > 0) {
          this.updateMessage(this.voiceInputMessageId, value);
        }
      },
      onFinal: (text: string): void => {
        const value = text.trim();
        if (value.length > 0) {
          this.updateMessage(this.voiceInputMessageId, value);
        }
      },
      onComplete: (text: string): void => {
        this.listening = false;
        const recognized = text.trim();
        if (recognized.length === 0) {
          this.statusText = '';
          this.updateMessage(this.voiceInputMessageId, '');
          this.voiceInputMessageId = 0;
          this.onSpeechComplete();
          return;
        }
        this.updateMessage(this.voiceInputMessageId, recognized);
        this.voiceInputMessageId = 0;
        this.submitText(recognized, true, false);
      },
      onError: (): void => {
        this.errorText = '';
        this.updateMessage(this.voiceInputMessageId, '');
        this.voiceInputMessageId = 0;
        this.listening = false;
        this.statusText = '';
        this.onSpeechComplete();
      }
    }).catch((): void => {
      this.errorText = '';
      this.updateMessage(this.voiceInputMessageId, '');
      this.voiceInputMessageId = 0;
      this.listening = false;
      this.statusText = '';
      this.onSpeechComplete();
    });
  }

  private stopVoice(sendEnd: boolean): void {
    this.voiceStartRequestId += 1;
    this.listening = false;
    if (!sendEnd) {
      this.ttsRequestId += 1;
      this.speechService.stopSpeaking();
      this.updateMessage(this.voiceInputMessageId, '');
      this.voiceInputMessageId = 0;
    }
    this.speechService.stopRecognition(sendEnd).catch((err: Error | string | number | boolean | Object): void => {
      this.errorText = Localization.format('assist_stop_failed', 'error', this.stringifyError(err));
      this.onSpeechComplete();
    });
  }

  private sendText(): void {
    const text = this.inputText.trim();
    if (text.length === 0 || this.pending || !this.isPipelineReady()) {
      this.onActivity();
      if (!this.isPipelineReady()) {
        this.statusText = Localization.t('assist_loading');
        this.refreshAgents(false);
      }
      return;
    }
    this.submitText(text, false, true);
  }

  private submitText(text: string, speakResponse: boolean, appendUserMessage: boolean): void {
    if (!this.isPipelineReady()) {
      this.statusText = Localization.t('assist_loading');
      this.refreshAgents(false);
      this.onSpeechComplete();
      return;
    }
    const normalizedBaseUrl = UrlService.normalizeBaseUrl(this.baseUrl);
    const token = this.accessToken.trim();
    if (normalizedBaseUrl.length === 0 || token.length === 0) {
      this.errorText = Localization.t('assist_connection_unavailable');
      this.onSpeechComplete();
      return;
    }

    const requestId = this.pipelineRequestId + 1;
    this.pipelineRequestId = requestId;
    this.onBusy();
    this.resolveAllowedBaseUrl()
      .then((baseUrl: string): void => {
        if (requestId !== this.pipelineRequestId) {
          return;
        }
        if (baseUrl.length === 0) {
          this.errorText = Localization.t('assist_connection_unavailable');
          this.onSpeechComplete();
          return;
        }
        if (appendUserMessage) {
          this.appendMessage('user', text);
        }
        this.pending = true;
        this.errorText = '';
        this.responseText = '';
        this.inputText = '';
        this.statusText = '';
        const assistantMessageId = this.appendPlaceholder('assistant');
        AssistRuntimeService.runTextPipeline(baseUrl, token, text, this.assistAgentId, this.conversationId)
          .then((result): void => {
            if (requestId !== this.pipelineRequestId) {
              return;
            }
            this.pending = false;
            if (result.failureSummary.length > 0) {
              this.updateMessage(assistantMessageId, '');
              this.statusText = '';
              this.errorText = result.failureSummary;
              this.onSpeechComplete();
              return;
            }
            this.conversationId = result.conversationId;
            this.responseText = result.text;
            this.updateMessage(assistantMessageId, result.text);
            this.statusText = '';
            if (speakResponse && result.text.trim().length > 0) {
              this.speakResponse(result.text);
            } else {
              this.onSpeechComplete();
            }
          })
          .catch((err: Error | string | number | boolean | Object): void => {
            if (requestId !== this.pipelineRequestId) {
              return;
            }
            this.pending = false;
            this.updateMessage(assistantMessageId, '');
            this.statusText = '';
            this.errorText = this.stringifyError(err);
            this.onSpeechComplete();
          });
      })
      .catch((err: Error | string | number | boolean | Object): void => {
        if (requestId !== this.pipelineRequestId) {
          return;
        }
        this.errorText = this.stringifyError(err);
        this.onSpeechComplete();
      });
  }

  private speakResponse(text: string): void {
    this.onBusy();
    const requestId = this.ttsRequestId + 1;
    this.ttsRequestId = requestId;
    let completed = false;
    const completeOnce = (): boolean => {
      if (completed || requestId !== this.ttsRequestId) {
        return false;
      }
      completed = true;
      return true;
    };
    this.speechService.speak(text, {
      onStart: (): void => {
        if (requestId !== this.ttsRequestId) {
          return;
        }
        this.statusText = '';
      },
      onComplete: (): void => {
        if (!completeOnce()) {
          return;
        }
        if (this.statusText === Localization.t('assist_speaking')) {
          this.statusText = '';
        }
        this.onSpeechComplete();
      },
      onError: (message: string): void => {
        if (!completeOnce()) {
          return;
        }
        this.statusText = '';
        this.errorText = message;
        this.onSpeechComplete();
      }
    }).catch((err: Error | string | number | boolean | Object): void => {
      if (!completeOnce()) {
        return;
      }
      this.statusText = '';
      this.errorText = Localization.format('assist_speak_failed', 'error', this.stringifyError(err));
      this.onSpeechComplete();
    });
  }

  private closeConversation(): void {
    this.pipelineRequestId += 1;
    this.stopVoice(false);
    this.pending = false;
    this.statusText = '';
    this.textMode = false;
    this.onClose();
  }

  private stringifyError(err: Error | string | number | boolean | Object): string {
    if (err instanceof Error) {
      return err.message;
    }
    if (typeof err === 'string') {
      return err;
    }
    try {
      return JSON.stringify(err);
    } catch (_) {
      return String(err);
    }
  }

  private async resolveAllowedBaseUrl(): Promise<string> {
    const context = this.getUIContext().getHostContext() as common.Context;
    const serverId = ServerManager.getActiveServerIdSync(context);
    if (serverId.length === 0) {
      return '';
    }
    const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, serverId);
    return policy.allowed ? policy.baseUrl : '';
  }

  build() {
    AssistOverlayHost({
      route: this.route,
      microphoneGranted: this.microphoneGranted,
      listening: this.listening,
      pending: this.pending,
      textMode: this.textMode,
      inputText: this.inputText,
      errorText: this.errorText,
      statusText: this.statusText,
      agentName: this.currentAgentName(),
      agentLoading: this.agentLoading,
      pipelineReady: this.isPipelineReady(),
      agentOptions: this.agentOptions(),
      selectedAgentId: this.assistAgentId,
      messages: this.messages,
      onClose: (): void => {
        this.closeConversation();
      },
      onRequestMicrophone: (): void => {
        this.requestMicrophonePermission();
      },
      onToggleMicrophone: (): void => {
        this.toggleMicrophone();
      },
      onToggleTextMode: (): void => {
        this.toggleTextMode();
      },
      onInputChange: (value: string): void => {
        this.onActivity();
        this.inputText = value;
      },
      onSendText: (): void => {
        this.sendText();
      },
      onRefreshAgents: (): void => {
        this.onActivity();
        this.refreshAgents(true);
      },
      onSelectAgent: (agentId: string): void => {
        this.selectAgent(agentId);
      }
    })
  }
}
