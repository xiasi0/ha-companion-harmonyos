import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import {
  SensorSettingsLiveGroupState,
  SensorSettingsLiveRowState,
  SensorSettingsLiveStateStore
} from '../../services/SensorSettingsLiveStateStore';
import { SettingsBoundary } from '../settings/components/SettingsBoundary';
import { SettingsCategory } from '../settings/components/SettingsCategory';
import { SettingsRow } from '../settings/components/SettingsRow';
import { SettingsSearchControl } from '../settings/components/SettingsSearchControl';
import { SettingsUiConfig } from '../settings/components/SettingsUiConfig';
import { SettingsItem, actionSettingsItem, infoSettingsItem } from '../../models/SettingsItem';
import { SensorEntry, SensorGroup } from './SensorModels';
import { SensorSettingsSwitchRow } from './SensorSettingsSwitchRow';

enum SensorFilterMode {
  ALL = 'all',
  ENABLED = 'enabled',
  DISABLED = 'disabled'
}

interface VisibleSensorGroup {
  key: string;
  group: SensorSettingsLiveGroupState;
  rows: SensorSettingsLiveRowState[];
}

@Component
export struct SensorSettingsPage {
  @Prop @Watch('syncLiveRows')
  groups: SensorGroup[] = [];
  @Prop contentMaxWidth: number = 720;
  @Prop showControls: boolean = true;
  @Prop healthAuthorizationState: string = '';
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
  onOpenHealthSensors: () => void = () => {};
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
        row.icon = sensor.icon;
        if (sensor.id === 'health_settings') {
          row.summary = sensor.summary;
        }
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
        groups.push({ key: this.visibleGroupKey(group, rows), group, rows });
      }
    }
    return groups;
  }

  private visibleGroupKey(group: SensorSettingsLiveGroupState, rows: SensorSettingsLiveRowState[]): string {
    const rowIds: string[] = [];
    for (let i = 0; i < rows.length; i++) {
      rowIds.push(rows[i].id);
    }
    return `${group.key}:${this.filterMode}:${this.searchText.trim().toLowerCase()}:${rowIds.join('|')}`;
  }

  private matchesFilter(row: SensorSettingsLiveRowState): boolean {
    if (this.isHealthSettingsRow(row)) {
      return true;
    }
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
    if (!this.showControls) {
      return 0;
    }
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

  private isHealthSettingsRow(state: SensorSettingsLiveRowState): boolean {
    return state.id === 'health_settings';
  }

  private healthSettingsItem(): SettingsItem {
    return actionSettingsItem(
      'sensor',
      Localization.t('health_title'),
      Localization.t('health_settings_summary'),
      '',
      'open_health_sensor_settings'
    );
  }

  private healthAuthorizationItem(): SettingsItem {
    return infoSettingsItem(
      'privacy',
      Localization.t('health_authorization_status_title'),
      '',
      this.healthAuthorizationStatus()
    );
  }

  private healthAuthorizationStatus(): string {
    switch (this.healthAuthorizationState) {
      case 'authorized':
        return Localization.t('health_authorization_authorized');
      case 'unauthorized':
        return Localization.t('health_authorization_unauthorized');
      case 'not_logged_in':
        return Localization.t('health_authorization_not_logged_in');
      case 'network_error':
        return Localization.t('health_authorization_network_error');
      case 'privacy_not_agreed':
        return Localization.t('health_authorization_privacy_not_agreed');
      case 'unavailable':
        return Localization.t('health_authorization_unavailable');
      case 'unknown':
        return Localization.t('health_authorization_unknown');
      default:
        return Localization.t('health_authorization_unavailable');
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
    if (this.showControls) {
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
  }

  @Builder
  private renderSensor(state: SensorSettingsLiveRowState): void {
    if (this.isHealthSettingsRow(state)) {
      SettingsRow({
        item: this.healthSettingsItem(),
        onAction: (_actionId: string): void => {
          this.onOpenHealthSensors();
        }
      })
    } else {
      SensorSettingsSwitchRow({
        state: state,
        onToggle: this.onToggleSensor
      })
    }
  }

  @Builder
  private renderHealthAuthorizationGroup(): void {
    Column() {
      SettingsRow({ item: this.healthAuthorizationItem() })
    }
    .width('100%')
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
    .padding(SettingsUiConfig.groupPadding)
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

        if (this.healthAuthorizationState.length > 0) {
          ListItem() {
            SettingsCategory({ title: Localization.t('health_authorization_group'), showBackground: false })
          }
          .width('100%')

          ListItem() {
            this.renderHealthAuthorizationGroup()
          }
          .width('100%')
        }

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
        }, (visibleGroup: VisibleSensorGroup) => visibleGroup.key)
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
