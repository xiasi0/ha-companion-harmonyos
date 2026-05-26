import { HaServerItem } from '../../models/HaServerItem';
import { UrlService } from '../../services/UrlService';
import { OnboardingFlowHost } from './OnboardingFlowHost';

@Component
export struct OnboardingRuntimeHost {
  @Prop step: number = 0;
  @Prop contentMaxWidth: number = 720;
  @Prop discoveredServers: HaServerItem[] = [];
  @Prop showDiscoveredSheet: boolean = false;
  @Prop discoverySpinAngle: number = 0;
  @Prop discoveryPulseScale: number = 1;
  @Prop manualAddress: string = '';
  @Prop deviceName: string = '';
  @Prop haBaseUrl: string = '';
  @Prop secureConnectionChoice: string = '';
  @Prop homeNetworkName: string = '';
  @Prop secureConnectionFromSettings: boolean = false;

  onConnectWelcome: () => void = () => {};
  onLearnMore: () => void = () => {};
  onPrivacyPolicy: () => void = () => {};
  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onManualInput: () => void = () => {};
  onSelectServer: (url: string) => void = () => {};
  onCloseSheet: () => void = () => {};
  onStartAnimation: () => void = () => {};
  onStopAnimation: () => void = () => {};
  onManualAddressChange: (value: string) => void = () => {};
  onManualConnect: () => void = () => {};
  onDeviceNameChange: (value: string) => void = () => {};
  onCompleteDeviceRegistration: () => void = () => {};
  onContinueLocalFirst: () => void = () => {};
  onShareLocation: () => void = () => {};
  onSkipLocation: () => void = () => {};
  onSecureBack: () => void = () => {};
  onSecureChoiceChange: (value: string) => void = () => {};
  onSecureContinue: () => void = () => {};
  onHomeNetworkNameChange: (value: string) => void = () => {};
  onHomeNetworkContinue: () => void = () => {};

  build() {
    OnboardingFlowHost({
      step: this.step,
      contentMaxWidth: this.contentMaxWidth,
      discoveredServers: this.discoveredServers,
      showDiscoveredSheet: this.showDiscoveredSheet,
      discoverySpinAngle: this.discoverySpinAngle,
      discoveryPulseScale: this.discoveryPulseScale,
      manualAddress: this.manualAddress,
      addressInvalid: this.manualAddress.trim().length > 0 && UrlService.normalizeBaseUrl(this.manualAddress).length === 0,
      deviceName: this.deviceName,
      haBaseUrl: this.haBaseUrl,
      secureConnectionChoice: this.secureConnectionChoice,
      homeNetworkName: this.homeNetworkName,
      onConnectWelcome: this.onConnectWelcome,
      onLearnMore: this.onLearnMore,
      onPrivacyPolicy: this.onPrivacyPolicy,
      onBack: this.onBack,
      onHelp: this.onHelp,
      onManualInput: this.onManualInput,
      onSelectServer: this.onSelectServer,
      onCloseSheet: this.onCloseSheet,
      onStartAnimation: this.onStartAnimation,
      onStopAnimation: this.onStopAnimation,
      onManualAddressChange: this.onManualAddressChange,
      onManualConnect: this.onManualConnect,
      onDeviceNameChange: this.onDeviceNameChange,
      onCompleteDeviceRegistration: this.onCompleteDeviceRegistration,
      onContinueLocalFirst: this.onContinueLocalFirst,
      onShareLocation: this.onShareLocation,
      onSkipLocation: this.onSkipLocation,
      onSecureBack: this.onSecureBack,
      onSecureChoiceChange: this.onSecureChoiceChange,
      onSecureContinue: this.onSecureContinue,
      onHomeNetworkNameChange: this.onHomeNetworkNameChange,
      onHomeNetworkContinue: this.onHomeNetworkContinue
    })
  }
}
