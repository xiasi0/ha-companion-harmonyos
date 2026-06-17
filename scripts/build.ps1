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
$targetSdkVersion = '6.1.0(23)'
$compatibleSdkVersion = '6.1.0(23)'
$profileSdkChanged = $false

function ProfilePath([string]$name) {
  return Join-Path $localDir "build-profile.$name.json5"
}

function EnsureLocalDir {
  if (-not (Test-Path -LiteralPath $localDir)) {
    New-Item -ItemType Directory -Path $localDir | Out-Null
  }
}

function Set-ProfileSdkVersions([string]$path) {
  $content = Get-Content -LiteralPath $path -Raw
  $updated = $content -replace '("targetSdkVersion"\s*:\s*)"[^"]+"', "`$1`"$targetSdkVersion`""
  $updated = $updated -replace '("compatibleSdkVersion"\s*:\s*)"[^"]+"', "`$1`"$compatibleSdkVersion`""
  if ($updated -eq $content) {
    return $false
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $updated, $utf8NoBom)
  return $true
}

function Save-Profile([string]$name) {
  EnsureLocalDir
  $destination = ProfilePath $name
  Copy-Item -LiteralPath $activeProfile -Destination $destination -Force
  [void](Set-ProfileSdkVersions $destination)
  Write-Host "Saved current build-profile.json5 as .local/build-profile.$name.json5"
}

function Use-Profile([string]$name) {
  $source = ProfilePath $name
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Missing $source. Switch DevEco to $name once, then run: .\scripts\build.ps1 save $name"
  }
  $sourceSdkChanged = Set-ProfileSdkVersions $source
  Copy-Item -LiteralPath $source -Destination $activeProfile -Force
  $activeSdkChanged = Set-ProfileSdkVersions $activeProfile
  $script:profileSdkChanged = $sourceSdkChanged -or $activeSdkChanged
  Write-Host "Using .local/build-profile.$name.json5"
}

function Invoke-Hvigor([string]$buildTarget) {
  if (-not (Test-Path -LiteralPath $hvigorw)) {
    throw "Hvigor wrapper not found: $hvigorw"
  }
  $env:DEVECO_SDK_HOME = $devecoSdk
  $tasks = @()
  if ($script:profileSdkChanged) {
    $tasks += 'clean'
  }
  if ($buildTarget -eq 'app') {
    $tasks += 'assembleApp'
    & $hvigorw --no-daemon @tasks
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
    Get-ChildItem -Recurse -Path (Join-Path $repoRoot 'build\outputs') -Filter '*-signed.app' |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1 -ExpandProperty FullName
    return
  }
  $tasks += 'assembleHap'
  & $hvigorw --no-daemon --mode module -p module=entry @tasks
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
