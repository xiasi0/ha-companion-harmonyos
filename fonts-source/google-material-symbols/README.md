# Google Material Symbols Rounded Source

Local source files for Google Material Symbols Rounded.

- Upstream: https://github.com/google/material-design-icons/tree/master/variablefont
- Preview: https://fonts.google.com/icons?hl=zh-cn&icon.set=Material+Symbols&icon.style=Rounded
- License: Apache License 2.0
- App builds use `tools/material-symbols/used-icons.json` to generate a smaller runtime TTF.

## Font Style

This project only uses the `Rounded` style:

- `Rounded`: symbols with softer corners and rounder stroke endings. This usually matches friendly app UI better.

The upstream Rounded font is a variable font with these axes:

- `FILL`: switches between outline and filled appearance.
- `wght`: stroke weight.
- `GRAD`: grade adjustment, useful for subtle optical weight changes.
- `opsz`: optical size.

The current HarmonyOS generator static-instances the variable font before subsetting, then emits a smaller runtime TTF.

## Source Files

Place these upstream files in this directory when regenerating symbols:

- `MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf`
- `MaterialSymbolsRounded[FILL,GRAD,opsz,wght].codepoints`

The `.ttf` file is used by the local build script. The `.codepoints` file maps icon names, such as `home`, to Unicode code points.

The upstream `.woff2` file is a web font build. It is not needed for the HarmonyOS build.

Font files and codepoint files are intentionally ignored by git.
