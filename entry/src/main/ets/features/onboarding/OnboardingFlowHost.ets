import { HaServerItem } from '../../models/HaServerItem';
import { WelcomePage } from './WelcomePage';
import { DiscoveryPage } from './DiscoveryPage';
import { ManualServerPage } from './ManualServerPage';
import { NameDevicePage } from './NameDevicePage';
import { LocalFirstPage } from './LocalFirstPage';
import { LocationSharingPage } from './LocationSharingPage';
import { SecureConnectionPage } from './SecureConnectionPage';
import { HomeNetworkPage } from './HomeNetworkPage';

@Component
export struct OnboardingFlowHost {
  @Prop step: number = 0;
  @Prop contentMaxWidth: number = 420;
  @Prop discoveredServers: HaServerItem[] = [];
  @Prop showDiscoveredSheet: boolean = false;
  @Prop discoverySpinAngle: number = 0;
  @Prop discoveryPulseScale: number = 1;
  @Prop manualAddress: string = '';
  @Prop addressInvalid: boolean = false;
  @Prop deviceName: string = '';
  @Prop haBaseUrl: string = '';
  @Prop secureConnectionChoice: string = '';
  @Prop homeNetworkName: string = '';

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
    if (this.step === 0) {
      WelcomePage({
        contentMaxWidth: this.contentMaxWidth,
        onConnect: this.onConnectWelcome,
        onLearnMore: this.onLearnMore,
        onPrivacyPolicy: this.onPrivacyPolicy
      })
    } else if (this.step === 1) {
      DiscoveryPage({
        contentMaxWidth: this.contentMaxWidth,
        discoveredServers: this.discoveredServers,
        showDiscoveredSheet: this.showDiscoveredSheet,
        discoverySpinAngle: this.discoverySpinAngle,
        discoveryPulseScale: this.discoveryPulseScale,
        onBack: this.onBack,
        onHelp: this.onHelp,
        onManualInput: this.onManualInput,
        onSelectServer: this.onSelectServer,
        onCloseSheet: this.onCloseSheet,
        onStartAnimation: this.onStartAnimation,
        onStopAnimation: this.onStopAnimation,
        onSwipeBack: this.onBack
      })
    } else if (this.step === 2) {
      ManualServerPage({
        contentMaxWidth: this.contentMaxWidth,
        manualAddress: this.manualAddress,
        addressInvalid: this.addressInvalid,
        onBack: this.onBack,
        onHelp: this.onHelp,
        onAddressChange: this.onManualAddressChange,
        onConnect: this.onManualConnect,
        onSwipeBack: this.onBack
      })
    } else if (this.step === 5) {
      NameDevicePage({
        contentMaxWidth: this.contentMaxWidth,
        deviceName: this.deviceName,
        onBack: this.onBack,
        onHelp: this.onHelp,
        onDeviceNameChange: this.onDeviceNameChange,
        onContinue: this.onCompleteDeviceRegistration
      })
    } else if (this.step === 6) {
      LocalFirstPage({
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBack,
        onHelp: this.onHelp,
        onContinue: this.onContinueLocalFirst
      })
    } else if (this.step === 7) {
      LocationSharingPage({
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBack,
        onHelp: this.onHelp,
        onShareLocation: this.onShareLocation,
        onSkipLocation: this.onSkipLocation
      })
    } else if (this.step === 8) {
      SecureConnectionPage({
        contentMaxWidth: this.contentMaxWidth,
        haBaseUrl: this.haBaseUrl,
        secureConnectionChoice: this.secureConnectionChoice,
        onBack: this.onSecureBack,
        onHelp: this.onHelp,
        onChoiceChange: this.onSecureChoiceChange,
        onContinue: this.onSecureContinue
      })
    } else if (this.step === 9) {
      HomeNetworkPage({
        contentMaxWidth: this.contentMaxWidth,
        homeNetworkName: this.homeNetworkName,
        onBack: this.onBack,
        onHelp: this.onHelp,
        onHomeNetworkNameChange: this.onHomeNetworkNameChange,
        onContinue: this.onHomeNetworkContinue
      })
    }
  }
}
