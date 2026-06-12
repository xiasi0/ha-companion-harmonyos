import { HaTheme } from '../../shared/theme/HaTheme';
import {
  SensorSettingsLiveGroupState,
  SensorSettingsLiveRowState,
  SensorSettingsLiveStateStore
} from '../../services/SensorSettingsLiveStateStore';
import { SettingsBoundary } from '../settings/components/SettingsBoundary';
import { SettingsCategory } from '../settings/components/SettingsCategory';
import { SettingsUiConfig } from '../settings/components/SettingsUiConfig';
import { SensorEntry, SensorGroup } from './SensorModels';
import { SensorSettingsSwitchRow } from './SensorSettingsSwitchRow';

@Component
export struct SensorSettingsPage {
  @Prop @Watch('syncLiveRows')
  groups: SensorGroup[] = [];
  @Prop contentMaxWidth: number = 720;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @State private liveGroups: SensorSettingsLiveGroupState[] = [];
  private settingsScroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onSearch: () => void = () => {};
  onFilter: () => void = () => {};
  onToggleSensor: (id: string, enabled: boolean) => void = () => {};
  onSwipeBack: () => void = () => {};

  aboutToAppear(): void {
    this.syncLiveRows();
  }

  private syncLiveRows(): void {
    SensorSettingsLiveStateStore.applySensorGroups(this.groups);
    const nextGroups: SensorSettingsLiveGroupState[] = [];
    for (let i = 0; i < this.groups.length; i++) {
      const group = this.groups[i];
      const groupState = new SensorSettingsLiveGroupState();
      groupState.key = this.groupKey(group, i);
      groupState.title = group.title;
      for (let j = 0; j < group.sensors.length; j++) {
        const sensor = group.sensors[j];
        const row = SensorSettingsLiveStateStore.stateFor(sensor.id);
        row.title = sensor.title;
        row.icon = this.sensorIcon(sensor);
        groupState.rows.push(row);
      }
      nextGroups.push(groupState);
    }
    this.liveGroups = nextGroups;
  }

  private groupKey(group: SensorGroup, index: number): string {
    if (group.sensors.length > 0) {
      return `${index}:${group.sensors[0].id}`;
    }
    return `${index}:${group.title}`;
  }

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

  @Builder
  private renderSensor(state: SensorSettingsLiveRowState): void {
    SensorSettingsSwitchRow({
      state: state,
      onToggle: this.onToggleSensor
    })
  }

  @Builder
  private renderSensorGroup(group: SensorSettingsLiveGroupState): void {
    Column() {
      ForEach(group.rows, (state: SensorSettingsLiveRowState, sensorIndex?: number) => {
        this.renderSensor(state);
        if ((sensorIndex ?? 0) < group.rows.length - 1) {
          SettingsBoundary()
        }
      }, (state: SensorSettingsLiveRowState) => state.id)
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
  }

  @Builder
  private renderList(): void {
    Stack({ alignContent: Alignment.End }) {
      List({ scroller: this.settingsScroller, space: SettingsUiConfig.listSpace }) {
        ForEach(this.liveGroups, (group: SensorSettingsLiveGroupState) => {
          if (group.rows.length > 0) {
            if (group.title.trim().length > 0) {
              ListItem() {
                SettingsCategory({ title: group.title, showBackground: false })
              }
              .width('100%')
            }

            ListItem() {
              this.renderSensorGroup(group)
            }
            .width('100%')
          }
        }, (group: SensorSettingsLiveGroupState) => group.key)
      }
      .padding(SettingsUiConfig.listPadding())
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .contentEndOffset(SettingsUiConfig.listContentEndOffset)
      .clip(false)
      .cachedCount(3, true)
      .scrollBar(BarState.Off)
      .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))

      ScrollBar({
        scroller: this.settingsScroller,
        direction: ScrollBarDirection.Vertical,
        state: BarState.Auto
      })
        .width(9)
        .height('100%')
        .backgroundColor(Color.Transparent)
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
  }

  build() {
    Column() {
      Column() {
        this.renderList()
      }
      .width('100%')
      .constraintSize({ maxWidth: this.contentMaxWidth })
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
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
