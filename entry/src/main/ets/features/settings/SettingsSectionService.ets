// Produces the settings sections shown by the native settings UI.
// Capability policy and localized display text are combined here before rendering.
import {
  SettingsCapability,
  SettingsItem,
  SettingsSection,
  actionSettingsItem,
  detailSettingsItem,
  infoSettingsItem,
  settingsItemCapability,
  switchSettingsItem
} from '../../models/SettingsItem';
import { CapabilityAvailability, CapabilityDecision, CapabilityPolicy } from '../../shared/device/CapabilityPolicy';
import { DeviceProfileInfo } from '../../shared/device/DeviceProfile';
import { Localization } from '../../shared/i18n/Localization';
import { AppVersionService } from '../../services/AppVersionService';
import { CompanionSettingsData } from './CompanionSettingsData';

export interface CompanionSettingsSectionsInput {
  profile: DeviceProfileInfo;
  serverName: string;
  deviceName: string;
  serverOptions: ServerOption[];
  sensorUpdateFrequencySummary: string;
  fullScreenEnabled: boolean;
  screenOrientation: string;
  keepScreenOnEnabled: boolean;
  pageZoomLevel: string;
  pinchToZoomEnabled: boolean;
  autoPlayVideoEnabled: boolean;
  alwaysShowFirstViewOnAppStartEnabled: boolean;
  serviceCardUpdateFrequency: string;
  appLanguage: string;
  appTheme: string;
  notificationUnreadCount: number;
}

export interface ServerOption {
  id: string;
  name: string;
  summary: string;
  active: boolean;
}

export interface ServerSettingsSectionsInput {
  profile: DeviceProfileInfo;
  serverName: string;
  deviceName: string;
  effectiveExternalUrl: string;
  homeNetworkSummary: string;
  internalConnectionSummary: string;
  securityLevelSummary: string;
  trustServer: boolean;
  appLockEnabled: boolean;
  appLockHomeBypass: boolean;
  sessionTimeoutSummary: string;
  websocketSummary: string;
  showActivateServer: boolean;
}

export class SettingsSectionService {
  static companionSections(input: CompanionSettingsSectionsInput): SettingsSection[] {
    return [
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_server_device'), [
        ...SettingsSectionService.serverItems(input),
        SettingsSectionService.capabilityItem(actionSettingsItem('plus', Localization.t('settings_add_server'), '', Localization.t('common_available'), 'add_server'), SettingsCapability.SERVER_MANAGEMENT)
      ]),
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_sensors'), [
        SettingsSectionService.capabilityItem(actionSettingsItem('sensor', Localization.t('settings_manage_sensors'), Localization.t('settings_manage_sensors_summary'), Localization.t('common_available'), 'open_sensor_settings'), SettingsCapability.SENSORS),
        SettingsSectionService.capabilityItem(actionSettingsItem('sensor_update', Localization.t('settings_sensor_update_frequency'), input.sensorUpdateFrequencySummary, Localization.t('common_available'), 'open_sensor_update_frequency'), SettingsCapability.SENSORS)
      ]),
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_other'), [
        SettingsSectionService.capabilityItem(actionSettingsItem('gestures', Localization.t('settings_gestures'), '', Localization.t('common_available'), 'open_display_gestures'), SettingsCapability.DISPLAY),
        SettingsSectionService.switchItem('fullscreen', Localization.t('settings_fullscreen'), Localization.t('settings_fullscreen_summary'), input.fullScreenEnabled, '', 'toggle_fullscreen', SettingsCapability.DISPLAY),
        SettingsSectionService.capabilityItem(actionSettingsItem('orientation', Localization.t('settings_orientation'), CompanionSettingsData.orientationSummary(input.screenOrientation), Localization.t('common_available'), 'open_display_orientation'), SettingsCapability.DISPLAY),
        SettingsSectionService.switchItem('keep_screen', Localization.t('settings_keep_screen_on'), Localization.t('settings_keep_screen_on_summary'), input.keepScreenOnEnabled, '', 'toggle_keep_screen', SettingsCapability.DISPLAY),
        SettingsSectionService.capabilityItem(actionSettingsItem('zoom', Localization.t('settings_page_zoom'), CompanionSettingsData.pageZoomSummary(input.pageZoomLevel), Localization.t('common_available'), 'open_display_zoom'), SettingsCapability.DISPLAY),
        SettingsSectionService.switchItem('pinch_zoom', Localization.t('settings_pinch_zoom'), Localization.t('settings_pinch_zoom_summary'), input.pinchToZoomEnabled, '', 'toggle_pinch_to_zoom', SettingsCapability.DISPLAY),
        SettingsSectionService.switchItem('autoplay_video', Localization.t('settings_autoplay_video'), Localization.t('settings_autoplay_video_summary'), input.autoPlayVideoEnabled, '', 'toggle_autoplay_video', SettingsCapability.DISPLAY),
        SettingsSectionService.switchItem('show_first_view', Localization.t('settings_show_first_view'), Localization.t('settings_show_first_view_summary'), input.alwaysShowFirstViewOnAppStartEnabled, '', 'toggle_always_show_first_view', SettingsCapability.DISPLAY),
        SettingsSectionService.capabilityItem(infoSettingsItem('nfc', Localization.t('settings_nfc_tags'), Localization.t('settings_nfc_tags_summary'), Localization.t('common_placeholder')), SettingsCapability.NFC),
        SettingsSectionService.capabilityItem(SettingsSectionService.detailActionItem('card_update_frequency', Localization.t('settings_service_card_update_frequency'), CompanionSettingsData.serviceCardUpdateFrequencySummary(input.serviceCardUpdateFrequency), Localization.t('common_available'), '', 'service_card_update_frequency'), SettingsCapability.WIDGETS),
        SettingsSectionService.capabilityItem(actionSettingsItem('language', Localization.t('settings_language'), CompanionSettingsData.languageSummary(input.appLanguage), Localization.t('common_available'), 'open_display_language'), SettingsCapability.DISPLAY),
        SettingsSectionService.capabilityItem(actionSettingsItem('theme', Localization.t('settings_theme'), CompanionSettingsData.themeSummary(input.appTheme), Localization.t('common_available'), 'open_display_theme'), SettingsCapability.DISPLAY)
      ]),
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_notifications'), [
        SettingsSectionService.notificationItem(input.notificationUnreadCount)
      ]),
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_assist'), [
        SettingsSectionService.capabilityItem(infoSettingsItem('assist', 'Assist', Localization.t('settings_assist_summary'), Localization.t('common_placeholder')), SettingsCapability.ASSIST),
        SettingsSectionService.capabilityItem(infoSettingsItem('headphones', Localization.t('settings_headphone_button'), Localization.t('settings_headphone_button_summary'), Localization.t('common_placeholder')), SettingsCapability.ASSIST)
      ]),
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_app_info'), [
        SettingsSectionService.capabilityItem(detailSettingsItem('info', Localization.t('settings_app_version'), AppVersionService.versionLabel(), Localization.t('common_available'), Localization.t('settings_app_version_body')), SettingsCapability.APP_INFO),
        SettingsSectionService.capabilityItem(SettingsSectionService.detailActionItem('license', Localization.t('settings_open_source_licenses'), Localization.t('settings_open_source_licenses_summary'), '', '', 'open_source_licenses'), SettingsCapability.APP_INFO),
        SettingsSectionService.capabilityItem(SettingsSectionService.detailActionItem('privacy', Localization.t('settings_privacy_policy'), Localization.t('settings_privacy_policy_summary'), '', '', 'privacy_policy'), SettingsCapability.APP_INFO)
      ])
    ];
  }

  private static serverItems(input: CompanionSettingsSectionsInput): SettingsItem[] {
    if (input.serverOptions.length === 0) {
      return [
        SettingsSectionService.capabilityItem(
          actionSettingsItem('ha', input.serverName, input.deviceName, Localization.t('common_available'), 'open_server'),
          SettingsCapability.SERVER_MANAGEMENT
        )
      ];
    }
    return input.serverOptions.map((server: ServerOption): SettingsItem => {
      const status = server.active ? Localization.t('common_available') : '';
      const actionId = `open_server_detail:${server.id}`;
      return SettingsSectionService.capabilityItem(
        actionSettingsItem('ha', server.name, server.summary, status, actionId),
        SettingsCapability.SERVER_MANAGEMENT
      );
    });
  }

  static serverSections(input: ServerSettingsSectionsInput): SettingsSection[] {
    const activateSections: SettingsSection[] = input.showActivateServer
      ? [
        SettingsSectionService.policySection(input.profile, '', [
          SettingsSectionService.capabilityItem(
            actionSettingsItem(
              'launch',
              Localization.t('server_activate'),
              Localization.t('server_activate_gesture_hint'),
              Localization.t('common_available'),
              'activate_server'
            ),
            SettingsCapability.SERVER_MANAGEMENT
          )
        ])
      ]
      : [];
    const securityItems: SettingsItem[] = [
      SettingsSectionService.serverSwitchItem('remote', Localization.t('server_trust_server'), Localization.t('server_trust_server_summary'), input.trustServer, Localization.t('server_trust_server_body'), 'server_trust_server', SettingsCapability.SECURITY),
      SettingsSectionService.serverSwitchItem('lock', Localization.t('server_app_lock'), Localization.t('server_app_lock_summary'), input.appLockEnabled, Localization.t('server_app_lock_body'), 'server_app_lock', SettingsCapability.SECURITY)
    ];
    if (input.appLockEnabled) {
      securityItems.push(SettingsSectionService.serverSwitchItem('wifi', Localization.t('server_app_lock_home_bypass'), Localization.t('server_app_lock_home_bypass_summary'), input.appLockHomeBypass, Localization.t('server_app_lock_home_bypass_body'), 'server_app_lock_home_bypass', SettingsCapability.SECURITY));
      securityItems.push(SettingsSectionService.serverDetailItem('timeout', Localization.t('server_session_timeout'), input.sessionTimeoutSummary, Localization.t('common_available'), Localization.t('server_session_timeout_body'), 'server_session_timeout', SettingsCapability.SECURITY));
    }

    return [
      ...activateSections,
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_device_registration'), [
        SettingsSectionService.capabilityItem(actionSettingsItem('ha', Localization.t('server_name'), input.serverName, Localization.t('common_available'), 'server_name'), SettingsCapability.SERVER_MANAGEMENT),
        SettingsSectionService.serverDetailItem('edit', Localization.t('server_device_name'), input.deviceName, Localization.t('common_available'), Localization.t('server_device_name_summary'), 'server_device_name', SettingsCapability.SERVER_MANAGEMENT)
      ]),
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_connection_info'), [
        SettingsSectionService.serverDetailItem('globe', Localization.t('server_external_url'), input.effectiveExternalUrl, Localization.t('common_available'), Localization.t('server_external_url_summary'), 'server_external_url', SettingsCapability.SERVER_CONNECTION),
        SettingsSectionService.serverDetailItem('wifi', Localization.t('server_home_network'), input.homeNetworkSummary, '', Localization.t('server_home_network_summary'), 'server_home_network', SettingsCapability.SERVER_CONNECTION),
        SettingsSectionService.serverDetailItem('computer', Localization.t('server_internal_url'), input.internalConnectionSummary, '', Localization.t('server_internal_url_summary'), 'server_internal_url', SettingsCapability.SERVER_CONNECTION),
        SettingsSectionService.serverDetailItem('lock', Localization.t('server_connection_security'), input.securityLevelSummary, Localization.t('common_available'), Localization.t('server_connection_security_summary'), 'server_connection_security', SettingsCapability.SERVER_CONNECTION)
      ]),
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_security'), securityItems),
      SettingsSectionService.policySection(input.profile, Localization.t('settings_section_other'), [
        SettingsSectionService.serverDetailItem('websocket', Localization.t('server_websocket'), input.websocketSummary, Localization.t('common_available'), Localization.t('server_websocket_summary'), 'server_websocket', SettingsCapability.PERSISTENT_CONNECTION),
        SettingsSectionService.capabilityItem(actionSettingsItem('clear', Localization.t('server_delete'), '', '', 'delete_server'), SettingsCapability.SERVER_MANAGEMENT)
      ])
    ];
  }

  private static capabilityItem(item: SettingsItem, capability: SettingsCapability): SettingsItem {
    return settingsItemCapability(item, capability);
  }

  private static notificationItem(unreadCount: number): SettingsItem {
    const item = SettingsSectionService.capabilityItem(
      actionSettingsItem('notifications', Localization.t('settings_section_notifications'), '', '', 'open_notification_settings'),
      SettingsCapability.NOTIFICATIONS
    );
    if (unreadCount > 0) {
      item.badge = unreadCount > 99 ? '99+' : `${unreadCount}`;
    }
    return item;
  }

  private static switchItem(
    icon: string,
    title: string,
    summary: string,
    isOn: boolean,
    body: string,
    actionId: string,
    capability: SettingsCapability
  ): SettingsItem {
    const item = switchSettingsItem(icon, title, summary, isOn, body);
    item.actionId = actionId;
    item.status = Localization.t('common_available');
    return SettingsSectionService.capabilityItem(item, capability);
  }

  private static serverDetailItem(
    icon: string,
    title: string,
    summary: string,
    status: string,
    body: string,
    actionId: string,
    capability: SettingsCapability
  ): SettingsItem {
    const item = detailSettingsItem(icon, title, summary, status, body);
    item.actionId = actionId;
    return SettingsSectionService.capabilityItem(item, capability);
  }

  private static detailActionItem(
    icon: string,
    title: string,
    summary: string,
    status: string,
    body: string,
    actionId: string
  ): SettingsItem {
    const item = detailSettingsItem(icon, title, summary, status, body);
    item.actionId = actionId;
    return item;
  }

  private static serverSwitchItem(
    icon: string,
    title: string,
    summary: string,
    isOn: boolean,
    body: string,
    actionId: string,
    capability: SettingsCapability
  ): SettingsItem {
    return SettingsSectionService.switchItem(icon, title, summary, isOn, body, actionId, capability);
  }

  private static policySection(profile: DeviceProfileInfo, title: string, items: SettingsItem[]): SettingsSection {
    return {
      title,
      items: SettingsSectionService.policyItems(profile, items)
    };
  }

  private static policyItems(profile: DeviceProfileInfo, items: SettingsItem[]): SettingsItem[] {
    const result: SettingsItem[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const decision = CapabilityPolicy.settingsCapability(item.capability, profile);
      if (decision.availability !== CapabilityAvailability.HIDDEN) {
        result.push(SettingsSectionService.applyCapabilityDecision(item, decision));
      }
    }
    return result;
  }

  private static applyCapabilityDecision(item: SettingsItem, decision: CapabilityDecision): SettingsItem {
    if (decision.availability === CapabilityAvailability.PLACEHOLDER) {
      item.status = Localization.t('common_placeholder');
      if (item.body.length === 0) {
        item.body = decision.reason;
      }
    }
    return item;
  }
}
