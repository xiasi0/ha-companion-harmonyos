import { SettingsDetailPage } from './SettingsDetailPage';
import { CompanionSettingChoicePage } from './CompanionSettingChoicePage';
import { CompanionSettingsData, GestureSettingGroup } from './CompanionSettingsData';
import { GestureSettingsPage } from './GestureSettingsPage';
import { ServerHomeNetworkPage } from './ServerHomeNetworkPage';
import { ServerSettingDetailPage } from './ServerSettingDetailPage';
import { OpenSourceLicensesPage } from './OpenSourceLicensesPage';
import { Localization } from '../../shared/i18n/Localization';

@Component
export struct SettingsDetailHost {
  @Prop detailKey: string = '';
  @Prop title: string = '';
  @Prop summary: string = '';
  @Prop body: string = '';
  @Prop status: string = '';
  @Prop action: string = '';
  @Prop textValue: string = '';
  @Prop optionValue: string = '';
  @Prop contentMaxWidth: number = 720;
  @Prop wifiSsids: string[] = [];
  @Prop ssidInput: string = '';
  @Prop prioritizeInternal: boolean = false;
  @Prop gestureGroups: GestureSettingGroup[] = [];
  @Prop screenOrientation: string = 'system';
  @Prop pageZoomLevel: string = '100';
  @Prop appLanguage: string = 'default';
  @Prop appTheme: string = 'light';
  @Prop serviceCardUpdateFrequency: string = 'default';
  onBackToServer: () => void = () => {};
  onBackToCompanion: () => void = () => {};
  onBackToGestures: () => void = () => {};
  onOpenDashboard: () => void = () => {};
  onSsidInputChange: (value: string) => void = () => {};
  onAddSsid: () => void = () => {};
  onRemoveSsid: (value: string) => void = () => {};
  onPrioritizeChange: (value: boolean) => void = () => {};
  onOpenGesture: (key: string) => void = () => {};
  onSelectGestureAction: (key: string, value: string) => void = () => {};
  onSelectChoice: (key: string, value: string) => void = () => {};
  onTextChange: (value: string) => void = () => {};
  onOptionChange: (value: string) => void = () => {};
  onSaveServerDetail: () => void = () => {};
  onHelp: () => void = () => {};
  onSwipeBack: () => void = () => {};
  gestureActionValue: (key: string) => string = () => '';

  private displayTitle(defaultTitle: string): string {
    return this.title.length > 0 ? this.title : defaultTitle;
  }

  build() {
    if (this.detailKey === 'server_home_network') {
      ServerHomeNetworkPage({
        wifiSsids: this.wifiSsids,
        ssidInput: this.ssidInput,
        prioritizeInternal: this.prioritizeInternal,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToServer,
        onSsidInputChange: this.onSsidInputChange,
        onAddSsid: this.onAddSsid,
        onRemoveSsid: this.onRemoveSsid,
        onPrioritizeChange: this.onPrioritizeChange,
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey === 'display_gestures') {
      GestureSettingsPage({
        groups: this.gestureGroups,
        description: CompanionSettingsData.gestureDescription(),
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToCompanion,
        onOpenGesture: this.onOpenGesture,
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey.startsWith('gesture_action_')) {
      CompanionSettingChoicePage({
        title: this.displayTitle(Localization.t('settings_gestures')),
        groups: CompanionSettingsData.gestureActionGroups(),
        selectedValue: this.gestureActionValue(this.detailKey.slice('gesture_action_'.length)),
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToGestures,
        onSelect: (value: string): void => {
          this.onSelectGestureAction(this.detailKey.slice('gesture_action_'.length), value);
        },
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey === 'display_orientation') {
      CompanionSettingChoicePage({
        title: Localization.t('settings_orientation'),
        groups: CompanionSettingsData.orientationOptions(),
        selectedValue: this.screenOrientation,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToCompanion,
        onSelect: (value: string): void => {
          this.onSelectChoice(this.detailKey, value);
        },
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey === 'display_zoom') {
      CompanionSettingChoicePage({
        title: Localization.t('settings_page_zoom'),
        groups: CompanionSettingsData.pageZoomOptions(),
        selectedValue: this.pageZoomLevel,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToCompanion,
        onSelect: (value: string): void => {
          this.onSelectChoice(this.detailKey, value);
        },
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey === 'display_language') {
      CompanionSettingChoicePage({
        title: Localization.t('settings_language'),
        groups: CompanionSettingsData.languageOptions(),
        selectedValue: this.appLanguage,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToCompanion,
        onSelect: (value: string): void => {
          this.onSelectChoice(this.detailKey, value);
        },
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey === 'display_theme') {
      CompanionSettingChoicePage({
        title: Localization.t('settings_theme'),
        groups: CompanionSettingsData.themeOptions(),
        selectedValue: this.appTheme,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToCompanion,
        onSelect: (value: string): void => {
          this.onSelectChoice(this.detailKey, value);
        },
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey === 'service_card_update_frequency') {
      CompanionSettingChoicePage({
        title: Localization.t('settings_service_card_update_frequency'),
        groups: CompanionSettingsData.serviceCardUpdateFrequencyOptions(),
        selectedValue: this.serviceCardUpdateFrequency,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToCompanion,
        onSelect: (value: string): void => {
          this.onSelectChoice(this.detailKey, value);
        },
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey.startsWith('server_')) {
      ServerSettingDetailPage({
        title: this.displayTitle(Localization.t('settings_server_title')),
        summary: this.summary,
        body: this.body,
        detailKey: this.detailKey,
        textValue: this.textValue,
        optionValue: this.optionValue,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToServer,
        onTextChange: this.onTextChange,
        onOptionChange: this.onOptionChange,
        onSave: this.onSaveServerDetail,
        onHelp: this.onHelp,
        onSwipeBack: this.onSwipeBack
      })
    } else if (this.detailKey === 'open_source_licenses') {
      OpenSourceLicensesPage({
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToCompanion,
        onSwipeBack: this.onSwipeBack
      })
    } else {
      SettingsDetailPage({
        title: this.displayTitle(Localization.t('settings_companion_title')),
        summary: this.summary,
        status: this.status,
        body: this.body,
        action: this.action,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBackToCompanion,
        onAction: this.onOpenDashboard,
        onSwipeBack: this.onSwipeBack
      })
    }
  }
}
