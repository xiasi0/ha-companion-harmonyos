import { HaTheme } from '../../../shared/theme/HaTheme';
import { SettingsUiConfig } from './SettingsUiConfig';

@Component
export struct SettingsTextInput {
  @Prop text: string = '';
  @Prop placeholder: string = '';
  @Prop inputType: InputType = InputType.Normal;
  @Prop heightValue: number = SettingsUiConfig.formInputHeight;
  @Prop radiusValue: number = SettingsUiConfig.formInputRadius;
  @Prop horizontalPadding: number = 0;
  @Prop inputBorderWidth: number = SettingsUiConfig.formInputBorderWidth;
  @Prop useTransparentBackground: boolean = false;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  onChange: (value: string) => void = () => {};

  build() {
    TextInput({ text: this.text, placeholder: this.placeholder })
      .onChange((value: string) => {
        this.onChange(value);
      })
      .type(this.inputType)
      .height(this.heightValue)
      .fontSize(16)
      .fontColor(HaTheme.textPrimary(this.appResolvedDark))
      .backgroundColor(this.useTransparentBackground ? Color.Transparent : HaTheme.surface(this.appResolvedDark))
      .borderRadius(this.radiusValue)
      .border({ width: this.inputBorderWidth, color: HaTheme.outline(this.appResolvedDark) })
      .cancelButton({ style: CancelButtonStyle.CONSTANT })
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      .width('100%')
  }
}
