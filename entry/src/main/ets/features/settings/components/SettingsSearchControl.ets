import { HaTheme } from '../../../shared/theme/HaTheme';
import { SettingsTextInput } from './SettingsTextInput';
import { SettingsUiConfig } from './SettingsUiConfig';

@Component
export struct SettingsSearchControl {
  @Prop text: string = '';
  @Prop placeholder: string = '';
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  onChange: (value: string) => void = () => {};

  build() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(20)
        .fontColor([HaTheme.textSecondary(this.appResolvedDark)])

      SettingsTextInput({
        text: this.text,
        placeholder: this.placeholder,
        heightValue: 40,
        radiusValue: 20,
        horizontalPadding: 16,
        inputBorderWidth: 0,
        useTransparentBackground: true,
        onChange: this.onChange
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 14, right: 4, top: 4, bottom: 4 })
    .borderRadius(SettingsUiConfig.groupRadius)
    .backgroundColor(HaTheme.surface(this.appResolvedDark))
    .shadow(SettingsUiConfig.groupShadow())
  }
}
