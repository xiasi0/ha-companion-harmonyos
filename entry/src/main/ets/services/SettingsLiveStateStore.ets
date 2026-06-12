import {
  SettingsCapability,
  SettingsItem,
  SettingsItemType,
  SettingsSection
} from '../models/SettingsItem';

@Observed
export class SettingsLiveRowState {
  key: string = '';
  type: SettingsItemType = SettingsItemType.DETAIL;
  icon: string = '';
  title: string = '';
  summary: string = '';
  status: string = '';
  body: string = '';
  action: string = '';
  actionId: string = '';
  badge: string = '';
  isOn: boolean = false;
  capability: SettingsCapability = SettingsCapability.NONE;
}

@Observed
export class SettingsLiveGroupState {
  key: string = '';
  title: string = '';
  rows: SettingsLiveRowState[] = [];
}

export class SettingsLiveStateStore {
  private static rows: Map<string, SettingsLiveRowState> = new Map<string, SettingsLiveRowState>();

  static itemKey(item: SettingsItem): string {
    const identity = item.actionId.length > 0 ? item.actionId : item.title;
    return `${item.type}-${identity}`;
  }

  static stateFor(item: SettingsItem): SettingsLiveRowState {
    const key = SettingsLiveStateStore.itemKey(item);
    const existing = SettingsLiveStateStore.rows.get(key);
    if (existing) {
      return existing;
    }
    const created = new SettingsLiveRowState();
    created.key = key;
    SettingsLiveStateStore.rows.set(key, created);
    SettingsLiveStateStore.applyItem(created, item);
    return created;
  }

  static applySections(sections: SettingsSection[]): void {
    for (let i = 0; i < sections.length; i++) {
      const section = sections[i];
      for (let j = 0; j < section.items.length; j++) {
        const item = section.items[j];
        SettingsLiveStateStore.applyItem(SettingsLiveStateStore.stateFor(item), item);
      }
    }
  }

  private static applyItem(state: SettingsLiveRowState, item: SettingsItem): void {
    state.type = item.type;
    state.icon = item.icon;
    state.title = item.title;
    state.summary = item.summary;
    state.status = item.status;
    state.body = item.body;
    state.action = item.action;
    state.actionId = item.actionId;
    state.badge = item.badge;
    state.isOn = item.isOn;
    state.capability = item.capability;
  }

  static toItem(state: SettingsLiveRowState): SettingsItem {
    return {
      type: state.type,
      icon: state.icon,
      title: state.title,
      summary: state.summary,
      status: state.status,
      body: state.body,
      action: state.action,
      actionId: state.actionId,
      badge: state.badge,
      isOn: state.isOn,
      capability: state.capability
    };
  }
}
