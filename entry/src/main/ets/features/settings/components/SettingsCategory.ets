import { HaColors } from '../../../shared/constants/HaStyle';
import { HaTheme } from '../../../shared/theme/HaTheme';
import { SettingsUiConfig } from './SettingsUiConfig';

@Component
export struct SettingsCategory {
  @Prop
  title: string = '';
  @Prop
  showBackground: boolean = true;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;

  build() {
    Text(this.title)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(HaColors.SETTINGS_ACCENT)
      .lineHeight(20)
      .width('100%')
      .padding(SettingsUiConfig.categoryPadding())
      .backgroundColor(this.showBackground ? HaTheme.groupedBackground(this.appResolvedDark) : Color.Transparent)
  }
}
