import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..');
const defaultFontDir = path.join(repoRoot, 'fonts-source', 'google-material-symbols');
const usedIconsPath = path.join(repoRoot, 'tools', 'material-symbols', 'used-icons.json');
const fontName = 'MaterialSymbolsRounded[FILL,GRAD,opsz,wght]';
const fontFamily = 'Material Symbols Rounded';
const arkTsIdentifierPattern = /^[A-Za-z_$][A-Za-z0-9_$]*$/;
const explicitCodepoints = new Map([
  ['_123', 'eb8d'],
  ['battery_health', 'e1a4'],
  ['do_not_disturb_sensor', 'e643'],
  ['last_reboot_time', 'e889'],
  ['last_update_trigger', 'e889'],
  ['location_permission', 'e0c8'],
  ['mobile_data_roaming', 'e6ca']
]);
const python = resolvePython();

function parseCodepoints(content) {
  const result = new Map();
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line) {
      continue;
    }
    const [name, codepoint] = line.split(/\s+/);
    if (name && codepoint) {
      result.set(name, codepoint.toLowerCase());
    }
  }
  return result;
}

function selectedSymbolEntries(codepoints, icons) {
  return icons.map((icon) => {
    const codepoint = codepoints.get(icon);
    const explicitCodepoint = explicitCodepoints.get(icon);
    const selectedCodepoint = codepoint ?? explicitCodepoint;
    if (!selectedCodepoint) {
      throw new Error(`Missing Material Symbol codepoint: ${icon}`);
    }
    return {
      icon,
      unicode: `0x${selectedCodepoint}`,
      text: codepoint ? icon : ''
    };
  });
}

function readUsedIcons() {
  const icons = JSON.parse(fs.readFileSync(usedIconsPath, 'utf8'));
  if (!Array.isArray(icons)) {
    throw new Error(`Material Symbols icon list must be a JSON array: ${usedIconsPath}`);
  }
  if (icons.some((icon) => typeof icon !== 'string' || icon.trim() === '')) {
    throw new Error(`Material Symbols icon list must be a JSON string array: ${usedIconsPath}`);
  }
  return Array.from(new Set(icons.map((icon) => icon.trim()))).sort();
}

function writeText(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

export function arkTsCodepoints(entries) {
  const lines = [
    `export const MATERIAL_SYMBOLS_FONT_FAMILY: string = '${fontFamily}';`,
    `export const MATERIAL_SYMBOLS_FONT_SOURCE: Resource = $rawfile('fonts/material_symbols_rounded.ttf');`,
    '',
    'export class MaterialSymbols {'
  ];
  for (const entry of entries) {
    if (!arkTsIdentifierPattern.test(entry.icon)) {
      throw new Error(`Invalid ArkTS Material Symbol identifier: ${entry.icon}`);
    }
    lines.push(`  static readonly ${entry.icon}: number = ${entry.unicode};`);
  }
  lines.push('}', '');
  return lines.join('\n');
}

function subsetFont(sourceFont, targetFont, entries) {
  const unicodes = entries.map((entry) => `U+${entry.unicode.slice(2).toUpperCase()}`).join(',');
  const ligatureText = entries.map((entry) => entry.text ?? '').filter((text) => text.length > 0).join(' ');
  const staticFont = path.join(repoRoot, '.tmp', 'material-symbols-rounded-static.ttf');
  fs.mkdirSync(path.dirname(staticFont), { recursive: true });
  const instantiateResult = runPython([
    '-c',
    [
      'from fontTools.ttLib import TTFont',
      'from fontTools.varLib import instancer',
      `font = TTFont(${JSON.stringify(sourceFont)})`,
      "static_font = instancer.instantiateVariableFont(font, {'FILL': 0, 'GRAD': 0, 'opsz': 24, 'wght': 300}, inplace=False)",
      `static_font.save(${JSON.stringify(staticFont)})`
    ].join('\n')
  ]);
  if (instantiateResult.status !== 0) {
    throw new Error(`fontTools varLib instancer failed:\n${pythonHelp()}\n\n${formatSpawnFailure(instantiateResult)}`);
  }

  const subsetArgs = [
    '-m',
    'fontTools.subset',
    staticFont,
    `--unicodes=${unicodes}`,
    `--output-file=${targetFont}`,
    '--layout-features=*',
    '--glyph-names'
  ];
  if (ligatureText.length > 0) {
    subsetArgs.splice(4, 0, `--text=${ligatureText}`);
  }
  const result = runPython(subsetArgs);
  if (result.status !== 0) {
    throw new Error(`fontTools.subset failed:\n${pythonHelp()}\n\n${formatSpawnFailure(result)}`);
  }
}

function formatSpawnFailure(result) {
  return [
    result.error ? result.error.message : '',
    result.stdout ?? '',
    result.stderr ?? ''
  ].filter((line) => line.trim().length > 0).join('\n');
}

function pythonHelp() {
  return [
    `Python executable: ${[python.command, ...python.args].join(' ')}`,
    `Tried: ${python.tried.join(', ')}`,
    'Install fontTools with:',
    `${[python.command, ...python.args, '-m', 'pip', 'install', 'fonttools'].join(' ')}`,
    'Set PYTHON or PYTHON_EXE to use a different Python executable.'
  ].join('\n');
}

function runPython(args) {
  return spawnSync(python.command, [...python.args, ...args], {
    cwd: repoRoot,
    encoding: 'utf8'
  });
}

function resolvePython() {
  const configured = process.env.PYTHON ?? process.env.PYTHON_EXE;
  const candidates = configured
    ? [{ command: configured, args: [] }]
    : [
        { command: 'python', args: [] },
        { command: 'py', args: ['-3'] },
        { command: 'python3', args: [] }
      ];

  for (const candidate of candidates) {
    const result = spawnSync(candidate.command, [...candidate.args, '--version'], {
      cwd: repoRoot,
      encoding: 'utf8'
    });
    if (result.status === 0) {
      return {
        ...candidate,
        tried: candidates.map((item) => [item.command, ...item.args].join(' '))
      };
    }
  }
  return {
    ...candidates[0],
    tried: candidates.map((item) => [item.command, ...item.args].join(' '))
  };
}

function assertSourceFilesExist(codepointFile, sourceFont) {
  const missing = [codepointFile, sourceFont].filter((filePath) => !fs.existsSync(filePath));
  if (missing.length === 0) {
    return;
  }
  throw new Error([
    'Missing Material Symbols source files.',
    '',
    'Download the Material Symbols Rounded variable font files from:',
    'https://github.com/google/material-design-icons/tree/master/variablefont',
    '',
    `Place these files in ${defaultFontDir}:`,
    `- ${fontName}.ttf`,
    `- ${fontName}.codepoints`,
    '',
    `Missing: ${missing.join(', ')}`
  ].join('\n'));
}

function generateMaterialSymbols() {
  const codepointFile = path.join(defaultFontDir, `${fontName}.codepoints`);
  const sourceFont = path.join(defaultFontDir, `${fontName}.ttf`);
  const rawDir = path.join(repoRoot, 'entry', 'src', 'main', 'resources', 'rawfile', 'fonts');
  const targetFont = path.join(rawDir, 'material_symbols_rounded.ttf');
  const targetArkTs = path.join(repoRoot, 'entry', 'src', 'main', 'ets', 'shared', 'icons', 'MaterialSymbols.ets');

  assertSourceFilesExist(codepointFile, sourceFont);
  const icons = readUsedIcons();
  const entries = selectedSymbolEntries(parseCodepoints(fs.readFileSync(codepointFile, 'utf8')), icons);
  fs.mkdirSync(rawDir, { recursive: true });
  subsetFont(sourceFont, targetFont, entries);
  writeText(targetArkTs, arkTsCodepoints(entries));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    generateMaterialSymbols();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}
