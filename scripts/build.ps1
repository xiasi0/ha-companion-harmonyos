param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet('debug', 'release', 'save')]
  [string]$Config,

  [Parameter(Mandatory = $false, Position = 1)]
  [ValidateSet('hap', 'app', 'debug', 'release')]
  [string]$Target = 'hap'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$localDir = Join-Path $repoRoot '.local'
$activeProfile = Join-Path $repoRoot 'build-profile.json5'
$hvigorw = 'D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat'
$devecoSdk = 'D:\DevEco Studio\sdk'

function ProfilePath([string]$name) {
  return Join-Path $localDir "build-profile.$name.json5"
}

function EnsureLocalDir {
  if (-not (Test-Path -LiteralPath $localDir)) {
    New-Item -ItemType Directory -Path $localDir | Out-Null
  }
}

function Save-Profile([string]$name) {
  EnsureLocalDir
  Copy-Item -LiteralPath $activeProfile -Destination (ProfilePath $name) -Force
  Write-Host "Saved current build-profile.json5 as .local/build-profile.$name.json5"
}

function Use-Profile([string]$name) {
  $source = ProfilePath $name
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Missing $source. Switch DevEco to $name once, then run: .\scripts\build.ps1 save $name"
  }
  Copy-Item -LiteralPath $source -Destination $activeProfile -Force
  Write-Host "Using .local/build-profile.$name.json5"
}

function Invoke-Hvigor([string]$buildTarget) {
  if (-not (Test-Path -LiteralPath $hvigorw)) {
    throw "Hvigor wrapper not found: $hvigorw"
  }
  $env:DEVECO_SDK_HOME = $devecoSdk
  if ($buildTarget -eq 'app') {
    & $hvigorw --no-daemon assembleApp
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
    Get-ChildItem -Recurse -Path (Join-Path $repoRoot 'build\outputs') -Filter '*-signed.app' |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1 -ExpandProperty FullName
    return
  }
  & $hvigorw --no-daemon --mode module -p module=entry assembleHap
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  Get-ChildItem -Recurse -Path (Join-Path $repoRoot 'entry\build') -Filter '*-signed.hap' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName
}

if ($Config -eq 'save') {
  if ($Target -ne 'debug' -and $Target -ne 'release') {
    throw "Usage: .\scripts\build.ps1 save debug|release"
  }
  Save-Profile $Target
  exit 0
}

if ($Target -ne 'hap' -and $Target -ne 'app') {
  throw "Usage: .\scripts\build.ps1 debug|release hap|app"
}

Use-Profile $Config
Invoke-Hvigor $Target
