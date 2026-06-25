import { MATERIAL_SYMBOLS_FONT_FAMILY } from './MaterialSymbols';
import { registerMaterialSymbolsFont } from './MaterialSymbolsFont';

@Component
export struct MaterialSymbolIcon {
  @Prop
  codepoint: number = 0;
  @Prop
  iconSize: number = 24;
  @Prop
  color: ResourceColor = '#172126';

  aboutToAppear(): void {
    registerMaterialSymbolsFont(this.getUIContext());
  }

  private iconText(): string {
    if (this.codepoint <= 0xFFFF) {
      return String.fromCharCode(this.codepoint);
    }
    const value = this.codepoint - 0x10000;
    return String.fromCharCode(
      Math.floor(value / 0x400) + 0xD800,
      value % 0x400 + 0xDC00
    );
  }

  build() {
    Text(this.iconText())
      .fontFamily(MATERIAL_SYMBOLS_FONT_FAMILY)
      .fontSize(this.iconSize)
      .fontColor(this.color)
      .lineHeight(this.iconSize)
  }
}
