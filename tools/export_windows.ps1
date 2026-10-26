# Build the Windows release (exe + pck) and pack it into a zip for sharing.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools\export_windows.ps1 [-Debug] [-NoZip]
# Output: build\windows\ (TryCard.exe, TryCard.pck, TryCard.console.exe, README.txt, licenses\)
#         build\TryCard_v<version>.zip
# Needs the export templates for the same Godot version in %APPDATA%\Godot\export_templates\.
# This file must stay ASCII only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
param(
    [switch]$Debug,
    [switch]$NoZip
)
$ErrorActionPreference = "Stop"
$godot = "D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "build\windows"
$preset = "Windows Desktop"

$tplDir = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable"
if (-not (Test-Path (Join-Path $tplDir "windows_release_x86_64.exe"))) {
    throw "Export templates not found in $tplDir"
}

# build\ must not be imported by Godot.
New-Item -ItemType Directory -Force $out | Out-Null
$ignore = Join-Path $root "build\.gdignore"
if (-not (Test-Path $ignore)) { New-Item -ItemType File $ignore | Out-Null }
Get-ChildItem $out | Remove-Item -Recurse -Force

& $godot --headless --path $root --import
if ($LASTEXITCODE -ne 0) { throw "import failed ($LASTEXITCODE)" }

$mode = if ($Debug) { "--export-debug" } else { "--export-release" }
& $godot --headless --path $root $mode $preset (Join-Path $out "TryCard.exe")
if ($LASTEXITCODE -ne 0) { throw "export failed ($LASTEXITCODE)" }
foreach ($f in "TryCard.exe", "TryCard.pck") {
    if (-not (Test-Path (Join-Path $out $f))) { throw "missing $f after export" }
}

# Readme and the licenses of the shipped assets.
Copy-Item (Join-Path $root "tools\dist\README.txt") $out
$lic = Join-Path $out "licenses"
New-Item -ItemType Directory -Force $lic | Out-Null
Copy-Item (Join-Path $root "assets\models\LICENSE_*.txt") $lic
Copy-Item (Join-Path $root "assets\textures\icons\LICENSE_*.txt") $lic
Copy-Item (Join-Path $root "assets\fonts\banner_mincho_OFL.txt") $lic

Get-ChildItem $out -Recurse -File | ForEach-Object {
    "{0,-40} {1,8:N1} MB" -f $_.FullName.Substring($out.Length + 1), ($_.Length / 1MB)
}

if (-not $NoZip) {
    $ver = (Select-String -Path (Join-Path $root "project.godot") -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
    $zip = Join-Path $root "build\TryCard_v$ver.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $out "*") -DestinationPath $zip
    "zip: {0} ({1:N1} MB)" -f $zip, ((Get-Item $zip).Length / 1MB)
}
