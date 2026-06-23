import { MATERIAL_SYMBOLS_FONT_FAMILY } from './MaterialSymbols';
import { registerMaterialSymbolsFont } from './MaterialSymbolsFont';

@Component
export struct MaterialSymbolIcon {
  codepoint: number = 0;
  iconSize: number = 24;
  color: ResourceColor = '#172126';

  aboutToAppear(): void {
    registerMaterialSymbolsFont(this.getUIContext());
  }

  build() {
    Text(String.fromCharCode(this.codepoint))
      .fontFamily(MATERIAL_SYMBOLS_FONT_FAMILY)
      .fontSize(this.iconSize)
      .fontColor(this.color)
      .lineHeight(this.iconSize)
  }
}
