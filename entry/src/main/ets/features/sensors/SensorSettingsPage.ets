import { SettingsItem, SettingsSection, switchSettingsItem } from '../../models/SettingsItem';
import { Localization } from '../../shared/i18n/Localization';
import { SettingsHomePage } from '../settings/SettingsHomePage';
import { SensorEntry, SensorGroup } from './SensorModels';

@Component
export struct SensorSettingsPage {
  @Prop groups: SensorGroup[] = [];
  @Prop contentMaxWidth: number = 720;
  @Prop switchRevision: number = 0;
  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onSearch: () => void = () => {};
  onFilter: () => void = () => {};
  onToggleSensor: (id: string) => void = () => {};
  onSwipeBack: () => void = () => {};

  private sensorIcon(sensor: SensorEntry): string {
    if (sensor.id === 'battery_level') {
      return 'sensor_battery_level';
    }
    if (sensor.id === 'battery_state') {
      return 'sensor_battery_state';
    }
    if (sensor.id === 'charger_type') {
      return 'sensor_charger_type';
    }
    if (sensor.id === 'network_type') {
      return 'sensor_network_type';
    }
    if (sensor.id === 'accurate_location') {
      return 'sensor_accurate_location';
    }
    if (sensor.id === 'zone_background') {
      return 'sensor_zone_background';
    }
    if (sensor.id === 'location_background') {
      return 'sensor_location_background';
    }
    if (sensor.id === 'last_update_trigger') {
      return 'sensor_last_update_trigger';
    }
    if (sensor.icon === 'update') {
      return 'sensor_update';
    }
    if (sensor.icon === 'wifi') {
      return 'wifi';
    }
    if (sensor.icon === 'nfc') {
      return 'nfc';
    }
    if (sensor.icon === 'lock') {
      return 'lock';
    }
    return 'sensor';
  }

  private sensorDescription(sensor: SensorEntry): string {
    if (sensor.id === 'battery_level') {
      return Localization.t('sensor_desc_battery_level');
    }
    if (sensor.id === 'battery_state') {
      return Localization.t('sensor_desc_battery_state');
    }
    if (sensor.id === 'charger_type') {
      return Localization.t('sensor_desc_charger_type');
    }
    if (sensor.id === 'network_type') {
      return Localization.t('sensor_desc_network_type');
    }
    if (sensor.id === 'accurate_location') {
      return Localization.t('sensor_desc_accurate_location');
    }
    if (sensor.id === 'zone_background') {
      return Localization.t('sensor_desc_zone_background');
    }
    if (sensor.id === 'location_background') {
      return Localization.t('sensor_desc_location_background');
    }
    if (sensor.summary.length > 0) {
      return sensor.summary;
    }
    return Localization.t('sensor_desc_direct');
  }

  private sensorItem(sensor: SensorEntry): SettingsItem {
    const item = switchSettingsItem(this.sensorIcon(sensor), sensor.title, sensor.summary, sensor.enabled,
      this.sensorDescription(sensor));
    item.actionId = sensor.id;
    return item;
  }

  private sensorSections(): SettingsSection[] {
    const sections: SettingsSection[] = [];
    for (let i = 0; i < this.groups.length; i++) {
      const group = this.groups[i];
      const items: SettingsItem[] = [];
      for (let j = 0; j < group.sensors.length; j++) {
        items.push(this.sensorItem(group.sensors[j]));
      }
      if (items.length > 0) {
        sections.push({ title: group.title, items: items });
      }
    }
    return sections;
  }

  build() {
    SettingsHomePage({
      sections: this.sensorSections(),
      contentMaxWidth: this.contentMaxWidth,
      switchRevision: this.switchRevision,
      title: Localization.t('sensor_title'),
      hideBackButton: false,
      embeddedInNavigation: true,
      onBack: this.onBack,
      onOpen: (item: SettingsItem): void => {
        if (item.actionId.length > 0) {
          this.onToggleSensor(item.actionId);
        }
      },
      onSwipeBack: this.onSwipeBack
    })
  }
}
