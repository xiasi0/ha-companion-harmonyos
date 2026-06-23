# Material Symbols

Add icon names to `used-icons.json`.

Font files and codepoint files are local-only and ignored by git.
Download the source files before building or regenerating symbols.
Install `fontTools` in your Python environment:

```powershell
python -m pip install fonttools
```

Set `PYTHON` or `PYTHON_EXE` if your Python executable is not named `python`.

Regenerate symbols after changing `used-icons.json`:

```powershell
node scripts/generate-material-symbols.mjs
```

Generated outputs to commit:

- `entry/src/main/resources/rawfile/fonts/material_symbols_rounded.ttf`
- `entry/src/main/ets/shared/icons/MaterialSymbols.ets`

The upstream source font stays local. Commit the generated runtime subset font and ArkTS icon constants.
