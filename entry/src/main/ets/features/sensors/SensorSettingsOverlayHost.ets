import { AppRoute } from '../../app/AppRoute';
import { SensorSettingsPage } from './SensorSettingsPage';
import { SensorUpdateFrequencyPage } from './SensorUpdateFrequencyPage';
import { SensorGroup, SensorUpdateFrequency } from './SensorModels';

@Component
export struct SensorSettingsOverlayHost {
  @Prop route: number = AppRoute.SENSOR_SETTINGS;
  @Prop groups: SensorGroup[] = [];
  @Prop selectedFrequency: string = SensorUpdateFrequency.NORMAL;
  @Prop contentMaxWidth: number = 720;

  onBack: () => void = () => {};
  onHelp: () => void = () => {};
  onSearch: () => void = () => {};
  onFilter: () => void = () => {};
  onToggleSensor: (id: string, enabled: boolean) => void = () => {};
  onSelectFrequency: (value: string) => void = () => {};
  onSwipeBack: () => void = () => {};

  build() {
    if (this.route === AppRoute.SENSOR_UPDATE_FREQUENCY) {
      SensorUpdateFrequencyPage({
        selected: this.selectedFrequency,
        contentMaxWidth: this.contentMaxWidth,
        embeddedInNavigation: true,
        onBack: this.onBack,
        onHelp: this.onHelp,
        onSelect: this.onSelectFrequency,
        onSwipeBack: this.onSwipeBack
      })
    } else {
      SensorSettingsPage({
        groups: this.groups,
        contentMaxWidth: this.contentMaxWidth,
        onBack: this.onBack,
        onHelp: this.onHelp,
        onSearch: this.onSearch,
        onFilter: this.onFilter,
        onToggleSensor: this.onToggleSensor,
        onSwipeBack: this.onSwipeBack
      })
    }
  }
}
