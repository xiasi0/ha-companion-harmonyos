import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import {
  SensorSettingsLiveGroupState,
  SensorSettingsLiveRowState,
  SensorSettingsLiveStateStore
} from '../../services/SensorSettingsLiveStateStore';
import { SettingsBoundary } from '../settings/components/SettingsBoundary';
import { SettingsCategory } from '../settings/components/SettingsCategory';
import { SettingsSearchControl } from '../settings/components/SettingsSearchControl';
import { SettingsUiConfig } from '../settings/components/SettingsUiConfig';
import { SensorEntry, SensorGroup } from './SensorModels';
import { SensorSettingsSwitchRow } from './SensorSettingsSwitchRow';

enum SensorFilterMode {
  ALL = 'all',
  ENABLED = 'enabled',
  DISABLED = 'disabled'
}

interface VisibleSensorGroup {
  group: SensorSettingsLiveGroupState;
  rows: SensorSettingsLiveRowState[];
}

@Component
export struct SensorSettingsPage {
  @Prop @Watch('syncLiveRows')
  groups: SensorGroup[] = [];
  @Prop contentMaxWidth: number = 720;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  @State private liveGroups: SensorSettingsLiveGroupState[] = [];
  @State private filterMode: SensorFilterMode = SensorFilterMode.ALL;
  @State private searchText: string = '';
  @State private filterTrackWidth: number = 0;
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

  private visibleRows(group: SensorSettingsLiveGroupState): SensorSettingsLiveRowState[] {
    const rows: SensorSettingsLiveRowState[] = [];
    for (let i = 0; i < group.rows.length; i++) {
      const row = group.rows[i];
      if (this.matchesFilter(row) && this.matchesSearch(row)) {
        rows.push(row);
      }
    }
    return rows;
  }

  private visibleGroups(): VisibleSensorGroup[] {
    const groups: VisibleSensorGroup[] = [];
    for (let i = 0; i < this.liveGroups.length; i++) {
      const group = this.liveGroups[i];
      const rows = this.visibleRows(group);
      if (rows.length > 0) {
        groups.push({ group, rows });
      }
    }
    return groups;
  }

  private matchesFilter(row: SensorSettingsLiveRowState): boolean {
    if (this.filterMode === SensorFilterMode.ENABLED) {
      return row.checked;
    }
    if (this.filterMode === SensorFilterMode.DISABLED) {
      return !row.checked;
    }
    return true;
  }

  private matchesSearch(row: SensorSettingsLiveRowState): boolean {
    const query = this.searchText.trim().toLowerCase();
    if (query.length === 0) {
      return true;
    }
    return row.title.toLowerCase().includes(query) ||
      row.summary.toLowerCase().includes(query) ||
      row.id.toLowerCase().includes(query);
  }

  private selectFilter(mode: SensorFilterMode): void {
    this.filterMode = mode;
  }

  private selectedFilterIndex(): number {
    if (this.filterMode === SensorFilterMode.ENABLED) {
      return 1;
    }
    if (this.filterMode === SensorFilterMode.DISABLED) {
      return 2;
    }
    return 0;
  }

  private filterThumbWidth(): number {
    if (this.filterTrackWidth <= 0) {
      return 0;
    }
    return Math.max(this.filterTrackWidth - 6, 0) / 3;
  }

  private filterThumbOffset(): number {
    return this.filterThumbWidth() * this.selectedFilterIndex();
  }

  private fixedControlsHeight(): number {
    return 100;
  }

  private titleBarSpacerHeight(): number {
    return 5;
  }

  private topContentSpacerHeight(): number {
    return this.titleBarSpacerHeight() + this.fixedControlsHeight();
  }

  private updateFilterTrackWidth(width: Length): void {
    if (typeof width === 'number') {
      this.filterTrackWidth = width;
    }
  }

  @Builder
  private renderFilterThumb(): void {
    Row()
      .width(this.filterThumbWidth())
      .height(42)
      .borderRadius(21)
      .backgroundColor(HaTheme.surface(this.appResolvedDark))
      .border({ width: 1, color: HaTheme.surface(this.appResolvedDark) })
      .shadow({ radius: 14, color: this.appResolvedDark ? '#66000000' : '#24000000', offsetX: 0, offsetY: 4 })
      .translate({ x: this.filterThumbOffset(), y: 0 })
      .animation({ duration: 220, curve: Curve.EaseOut })
  }

  @Builder
  private renderFilterText(title: string, mode: SensorFilterMode): void {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor(HaTheme.textPrimary(this.appResolvedDark))
        .fontWeight(this.filterMode === mode ? FontWeight.Medium : FontWeight.Regular)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height(42)
    .onClick(() => {
      this.selectFilter(mode);
    })
  }

  @Builder
  private renderFilterControl(): void {
    Stack({ alignContent: Alignment.Start }) {
      this.renderFilterThumb()

      Row() {
        this.renderFilterText(Localization.t('sensor_filter_all'), SensorFilterMode.ALL)
        this.renderFilterText(Localization.t('sensor_filter_enabled'), SensorFilterMode.ENABLED)
        this.renderFilterText(Localization.t('sensor_filter_disabled'), SensorFilterMode.DISABLED)
      }
      .width('100%')
      .height(42)
    }
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.updateFilterTrackWidth(newArea.width);
    })
    .width('100%')
    .height(48)
    .padding({ left: 3, right: 3, top: 3, bottom: 3 })
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
  }

  @Builder
  private renderSearchControl(): void {
    SettingsSearchControl({
      text: this.searchText,
      placeholder: Localization.t('sensor_search_placeholder'),
      onChange: (value: string): void => {
        this.searchText = value;
      }
    })
  }

  @Builder
  private renderFixedControls(): void {
    Column({ space: SettingsUiConfig.listSpace }) {
      this.renderFilterControl()
      this.renderSearchControl()
    }
    .width('100%')
    .height(this.topContentSpacerHeight())
    .padding({
      left: SettingsUiConfig.listPadding().left,
      right: SettingsUiConfig.listPadding().right,
      top: this.titleBarSpacerHeight(),
      bottom: 0
    })
    .backgroundColor(Color.Transparent)
    .zIndex(1)
  }

  @Builder
  private renderSensor(state: SensorSettingsLiveRowState): void {
    SensorSettingsSwitchRow({
      state: state,
      onToggle: this.onToggleSensor
    })
  }

  @Builder
  private renderSensorGroup(rows: SensorSettingsLiveRowState[]): void {
    Column() {
      ForEach(rows, (state: SensorSettingsLiveRowState, sensorIndex?: number) => {
        this.renderSensor(state);
        if ((sensorIndex ?? 0) < rows.length - 1) {
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
        ListItem() {
          Row()
        }
        .width('100%')
        .height(this.topContentSpacerHeight())

        ForEach(this.visibleGroups(), (visibleGroup: VisibleSensorGroup) => {
          if (visibleGroup.group.title.trim().length > 0) {
            ListItem() {
              SettingsCategory({ title: visibleGroup.group.title, showBackground: false })
            }
            .width('100%')
          }

          ListItem() {
            this.renderSensorGroup(visibleGroup.rows)
          }
          .width('100%')
        }, (visibleGroup: VisibleSensorGroup) => visibleGroup.group.key)
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
      Stack({ alignContent: Alignment.Top }) {
        this.renderList()
        this.renderFixedControls()
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
