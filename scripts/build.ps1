param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet('debug', 'release', 'save')]
  [string]$Config,

  [Parameter(Mandatory = $false, Position = 1)]
  [ValidateSet('hap', 'app', 'debug', 'release')]
  [string]$Target = 'hap',

  [Parameter(Mandatory = $false)]
  [switch]$RequireHealthClientId
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$localDir = Join-Path $repoRoot '.local'
$activeProfile = Join-Path $repoRoot 'build-profile.json5'
$moduleConfig = Join-Path $repoRoot 'entry\src\main\module.json5'
$devecoHome = if ($env:DEVECO_STUDIO_HOME) { $env:DEVECO_STUDIO_HOME } else { 'D:\DevEco Studio' }
$hvigorw = if ($env:DEVECO_HVIGORW) { $env:DEVECO_HVIGORW } else { Join-Path $devecoHome 'tools\hvigor\bin\hvigorw.bat' }
$devecoSdk = if ($env:DEVECO_SDK_HOME) { $env:DEVECO_SDK_HOME } else { Join-Path $devecoHome 'sdk' }
$devecoJavaHome = if ($env:DEVECO_JAVA_HOME) { $env:DEVECO_JAVA_HOME } else { Join-Path $devecoHome 'jbr' }
$targetSdkVersion = '6.1.0(23)'
$compatibleSdkVersion = '6.1.0(23)'
$profileSdkChanged = $false

function Write-Utf8NoBom([string]$path, [string]$content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function Test-Utf8Bom([string]$path) {
  $bytes = [System.IO.File]::ReadAllBytes($path)
  return $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
}

function Write-Utf8PreserveBom([string]$path, [string]$content) {
  $utf8 = New-Object System.Text.UTF8Encoding((Test-Utf8Bom $path))
  [System.IO.File]::WriteAllText($path, $content, $utf8)
}

function ProfilePath([string]$name) {
  return Join-Path $localDir "build-profile.$name.json5"
}

function HealthServicePath([string]$name) {
  return Join-Path $localDir "health-service.$name.json5"
}

function EnsureLocalDir {
  if (-not (Test-Path -LiteralPath $localDir)) {
    New-Item -ItemType Directory -Path $localDir | Out-Null
  }
}

function Use-DevEcoJava {
  $javaBin = Join-Path $devecoJavaHome 'bin'
  $javaExe = Join-Path $javaBin 'java.exe'
  if (-not (Test-Path -LiteralPath $javaExe)) {
    throw "DevEco Java not found: $javaExe"
  }
  $env:JAVA_HOME = $devecoJavaHome
  $pathParts = @($env:PATH -split ';' | Where-Object { $_.Trim().Length -gt 0 })
  if ($pathParts -notcontains $javaBin) {
    $env:PATH = "$javaBin;$env:PATH"
  }
}

function Set-ProfileSdkVersions([string]$path) {
  $content = Get-Content -LiteralPath $path -Raw
  $updated = $content -replace '("targetSdkVersion"\s*:\s*)"[^"]+"', "`$1`"$targetSdkVersion`""
  $updated = $updated -replace '("compatibleSdkVersion"\s*:\s*)"[^"]+"', "`$1`"$compatibleSdkVersion`""
  if ($updated -eq $content) {
    return $false
  }
  Write-Utf8NoBom $path $updated
  return $true
}

function Ensure-HealthServiceConfig([string]$name) {
  EnsureLocalDir
  $path = HealthServicePath $name
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Utf8NoBom $path "{`n  `"client_id`": `"`"`n}`n"
    throw "Created $path. Fill client_id, then rerun build."
  }
}

function Should-RequireHealthClientId {
  $raw = if ($env:REQUIRE_HEALTH_CLIENT_ID) { $env:REQUIRE_HEALTH_CLIENT_ID } else { '' }
  $value = $raw.Trim().ToLower()
  return $RequireHealthClientId.IsPresent -or $value -eq '1' -or $value -eq 'true' -or $value -eq 'yes'
}

function TryRead-HealthClientId([string]$name) {
  $path = HealthServicePath $name
  if (-not (Test-Path -LiteralPath $path)) {
    return ''
  }
  $content = Get-Content -LiteralPath $path -Raw
  $match = [regex]::Match($content, '"client_id"\s*:\s*"([^"]*)"')
  if (-not $match.Success) {
    return ''
  }
  return $match.Groups[1].Value.Trim()
}

function Read-HealthClientId([string]$name) {
  Ensure-HealthServiceConfig $name
  $clientId = TryRead-HealthClientId $name
  if ($clientId.Length -eq 0) {
    throw "Missing client_id in $(HealthServicePath $name)"
  }
  return $clientId
}

function ConvertTo-JsonStringLiteralContent([string]$value) {
  return $value.Replace('\', '\\').Replace('"', '\"')
}

function Set-ModuleClientId([string]$clientId) {
  $content = Get-Content -LiteralPath $moduleConfig -Raw
  $escaped = ConvertTo-JsonStringLiteralContent $clientId
  $pattern = '("name"\s*:\s*"client_id"\s*,\s*"value"\s*:\s*")[^"]*(")'
  if (-not [regex]::IsMatch($content, $pattern)) {
    throw "Missing client_id metadata in $moduleConfig"
  }
  $updated = [regex]::Replace(
    $content,
    $pattern,
    { param($match) $match.Groups[1].Value + $escaped + $match.Groups[2].Value },
    1
  )
  Write-Utf8PreserveBom $moduleConfig $updated
}

function Invoke-WithHealthClientId([string]$name, [string]$buildTarget) {
  $originalModuleConfig = Get-Content -LiteralPath $moduleConfig -Raw
  try {
    $clientId = TryRead-HealthClientId $name
    if ($clientId.Length -gt 0) {
      Set-ModuleClientId $clientId
    } elseif (Should-RequireHealthClientId) {
      [void](Read-HealthClientId $name)
    } else {
      Write-Host "Health client_id not configured; keeping module metadata placeholder."
    }
    Invoke-Hvigor $buildTarget
  } finally {
    Write-Utf8PreserveBom $moduleConfig $originalModuleConfig
  }
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
  Use-DevEcoJava
  $env:DEVECO_SDK_HOME = $devecoSdk
  $tasks = @()
  if ($script:profileSdkChanged) {
    $tasks += 'clean'
  }
  if ($buildTarget -eq 'app') {
    $tasks += 'assembleApp'
    & $hvigorw --no-daemon @tasks
    if ($LASTEXITCODE -ne 0) {
      throw "Hvigor failed with exit code $LASTEXITCODE"
    }
    Get-ChildItem -Recurse -Path (Join-Path $repoRoot 'build\outputs') -Filter '*-signed.app' |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1 -ExpandProperty FullName
    return
  }
  $tasks += 'assembleHap'
  & $hvigorw --no-daemon --mode module -p module=entry @tasks
  if ($LASTEXITCODE -ne 0) {
    throw "Hvigor failed with exit code $LASTEXITCODE"
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

$originalActiveProfile = Get-Content -LiteralPath $activeProfile -Raw
try {
  Use-Profile $Config
  Invoke-WithHealthClientId $Config $Target
} finally {
  Write-Utf8NoBom $activeProfile $originalActiveProfile
}
