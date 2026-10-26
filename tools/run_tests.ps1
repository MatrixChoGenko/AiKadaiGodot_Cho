# Run GUT tests headless (DevelopmentPlan 1.1 / Architecture 18.1).
# Usage:  powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 [-Godot <path>] [-SkipImport] [-Select a,b] [-Full]
#   -Select : run only test files whose name contains one of these substrings (GUT -gselect), e.g. -Select test_shop,test_tooltip
#   -Full   : print the whole GUT log (default prints only failures, warnings and the totals, to keep the output short)
# Exit code: 0 = all tests passed, otherwise failed.
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads BOM-less scripts as the ANSI code page.
param(
    [string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" }),
    [switch]$SkipImport,
    [string[]]$Select = @(),
    [switch]$Full
)

$ErrorActionPreference = "Stop"
$projectDir = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $Godot)) {
    Write-Host "Godot not found: $Godot (pass -Godot or set env GODOT)" -ForegroundColor Red
    exit 2
}

# Import first so the class_name cache and GUT resources exist (needed after a fresh copy or deleting .godot/).
if (-not $SkipImport) {
    & $Godot --headless --path $projectDir --import | Out-Null
}

# -Select "a,b" arrives as one string when called via -File; split it.
$patterns = @($Select | ForEach-Object { $_ -split "," } | Where-Object { $_ -ne "" })
$runs = if ($patterns.Count -gt 0) { $patterns } else { @("") }

$code = 0
foreach ($pat in $runs) {
    $gutArgs = @("--headless", "--path", $projectDir, "-s", "addons/gut/gut_cmdln.gd", "-gconfig=res://.gutconfig.json")
    if ($pat -ne "") { $gutArgs += "-gselect=$pat" }

    # Native stderr becomes ErrorRecords in PS 5.1; do not let them stop the script.
    $ErrorActionPreference = "Continue"
    $lines = @(& $Godot @gutArgs 2>&1 | ForEach-Object { ("$_" -replace "\x1b\[[0-9;]*m", "") })
    $runCode = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($runCode -ne 0) { $code = $runCode }

    if ($Full) {
        $lines | ForEach-Object { Write-Host $_ }
        continue
    }

    $label = if ($pat -ne "") { "[$pat] " } else { "" }
    # Problems that can appear even when every test is green.
    $warn = @($lines | Where-Object { $_ -match "SCRIPT ERROR|leaked|still in use|Parse Error|\[Failed\]|\[Risky\]|^\s*-\s*test_" })
    $warn | Select-Object -First 60 | ForEach-Object { Write-Host "$label$_" }

    $get = { param($key) ($lines | Where-Object { $_ -match "^$key\s+\d" } | Select-Object -Last 1) -replace "^$key\s+", "" }
    $scripts = & $get "Scripts"; $tests = & $get "Tests"; $passing = & $get "Passing Tests"; $time = & $get "Time"
    Write-Host ("{0}scripts={1} tests={2} passing={3} time={4} exit={5}" -f $label, $scripts, $tests, $passing, $time, $runCode)
    if ("$tests" -eq "") {
        Write-Host "${label}no test file matched" -ForegroundColor Yellow
        $code = 3
    }
    if ($runCode -ne 0 -and $warn.Count -eq 0) {
        # Failure without a recognizable line: show the tail so the cause is not hidden.
        $lines | Select-Object -Last 40 | ForEach-Object { Write-Host "$label$_" }
    }
}

if ($code -eq 0) { Write-Host "run_tests: PASS" -ForegroundColor Green } else { Write-Host "run_tests: FAIL (exit $code)" -ForegroundColor Red }
exit $code
