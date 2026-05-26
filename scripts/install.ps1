param(
  [Parameter(Mandatory = $false, Position = 0)]
  [string]$DeviceId = '',

  [Parameter(Mandatory = $false, Position = 1)]
  [string]$HapPath = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$hdc = if ($env:HDC_PATH) {
  $env:HDC_PATH
} else {
  'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
}

function Resolve-HapPath {
  if ($HapPath) {
    return (Resolve-Path -LiteralPath $HapPath).Path
  }

  $hap = Get-ChildItem -Recurse -Path (Join-Path $repoRoot 'entry\build') -Filter '*-signed.hap' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if (-not $hap) {
    throw 'No signed HAP found. Run: .\scripts\build.ps1 debug hap'
  }

  return $hap.FullName
}

function Resolve-DeviceId {
  if ($DeviceId) {
    return $DeviceId
  }

  $targets = & $hdc list targets
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  $devices = @($targets | Where-Object { $_ -and $_.Trim() -and $_ -notmatch '^\[Empty\]' })
  if ($devices.Count -eq 0) {
    throw 'No connected HarmonyOS device found.'
  }
  if ($devices.Count -gt 1) {
    throw "Multiple devices found. Pass one explicitly: .\scripts\install.ps1 <device-id>"
  }

  return $devices[0].Trim()
}

if (-not (Test-Path -LiteralPath $hdc)) {
  throw "hdc not found: $hdc"
}

$resolvedHap = Resolve-HapPath
$resolvedDevice = Resolve-DeviceId

& $hdc -t $resolvedDevice install -r $resolvedHap
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
