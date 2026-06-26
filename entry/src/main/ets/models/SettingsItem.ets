import { Localization } from '../shared/i18n/Localization';
import { AppIconSpec, systemIcon } from '../shared/icons/AppIconModels';

export enum SettingsItemType {
  DETAIL,
  ACTION,
  SWITCH,
  INFO
}

export enum SettingsCapability {
  NONE,
  SERVER_MANAGEMENT,
  SENSORS,
  DISPLAY,
  NFC,
  NOTIFICATIONS,
  ASSIST,
  WIDGETS,
  APP_INFO,
  SERVER_CONNECTION,
  SECURITY,
  PERSISTENT_CONNECTION
}

export interface SettingsItem {
  type: SettingsItemType;
  icon: AppIconSpec;
  title: string;
  summary: string;
  status: string;
  body: string;
  action: string;
  actionId: string;
  badge: string;
  isOn: boolean;
  capability: SettingsCapability;
}

type SettingsItemIcon = AppIconSpec | string;

function normalizedSettingsItemIcon(icon: SettingsItemIcon): AppIconSpec {
  if (typeof icon === 'string') {
    return systemIcon(icon);
  }
  return icon;
}

export interface SettingsSection {
  title: string;
  items: SettingsItem[];
}

export function detailSettingsItem(
  icon: SettingsItemIcon,
  title: string,
  summary: string,
  status: string,
  body: string,
  action: string = ''
): SettingsItem {
  return {
    type: SettingsItemType.DETAIL,
    icon: normalizedSettingsItemIcon(icon),
    title,
    summary,
    status,
    body,
    action,
    actionId: '',
    badge: '',
    isOn: false,
    capability: SettingsCapability.NONE
  };
}

export function actionSettingsItem(
  icon: SettingsItemIcon,
  title: string,
  summary: string,
  status: string,
  actionId: string
): SettingsItem {
  return {
    type: SettingsItemType.ACTION,
    icon: normalizedSettingsItemIcon(icon),
    title,
    summary,
    status,
    body: '',
    action: '',
    actionId,
    badge: '',
    isOn: false,
    capability: SettingsCapability.NONE
  };
}

export function infoSettingsItem(
  icon: SettingsItemIcon,
  title: string,
  summary: string,
  status: string = ''
): SettingsItem {
  return {
    type: SettingsItemType.INFO,
    icon: normalizedSettingsItemIcon(icon),
    title,
    summary,
    status,
    body: '',
    action: '',
    actionId: '',
    badge: '',
    isOn: false,
    capability: SettingsCapability.NONE
  };
}

export function switchSettingsItem(
  icon: SettingsItemIcon,
  title: string,
  summary: string,
  isOn: boolean,
  body: string
): SettingsItem {
  return {
    type: SettingsItemType.SWITCH,
    icon: normalizedSettingsItemIcon(icon),
    title,
    summary,
    status: Localization.t('settings_switch_pending'),
    body,
    action: '',
    actionId: '',
    badge: '',
    isOn,
    capability: SettingsCapability.NONE
  };
}

export function settingsItemCapability(item: SettingsItem, capability: SettingsCapability): SettingsItem {
  item.capability = capability;
  return item;
}
