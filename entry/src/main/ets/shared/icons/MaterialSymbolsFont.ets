import { MATERIAL_SYMBOLS_FONT_FAMILY, MATERIAL_SYMBOLS_FONT_SOURCE } from './MaterialSymbols';

export function registerMaterialSymbolsFont(uiContext: UIContext): void {
  uiContext.getFont().registerFont({
    familyName: MATERIAL_SYMBOLS_FONT_FAMILY,
    familySrc: MATERIAL_SYMBOLS_FONT_SOURCE
  });
}
