# Co-op smoke test: start host + client game processes (headless), let UiBot play one run each over localhost ENet.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File coop_smoke.ps1 [-Seed 1] [-Port 24680] [-TimeoutSec 300]
# Prints the COOP_SMOKE result line of each side and any SCRIPT ERROR lines. Exit 0 = both finished without failure/desync.
# NOTE: keep this file ASCII-only (Windows PowerShell 5.1).
param(
    [int]$Seed = 1,
    [int]$Port = 24680,
    [int]$TimeoutSec = 300,
    [string]$Godot = "D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
)
$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$script = Join-Path $PSScriptRoot "coop_smoke.gd"
$tmp = Join-Path $env:TEMP "trycard_coop_smoke"
New-Item -ItemType Directory -Force $tmp | Out-Null
$procs = @()
foreach ($role in @("host", "client")) {
    $out = Join-Path $tmp "$role.out.txt"
    $err = Join-Path $tmp "$role.err.txt"
    $procs += Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$project`"", "-s", "`"$script`"", "--", $role, "$Port", "$Seed") `
        -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -WindowStyle Hidden
    $null = $procs[-1].Handle   # without touching Handle, ExitCode stays empty after the process ends
    Start-Sleep -Milliseconds 800
}
$code = 0
foreach ($p in $procs) {
    if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Host "timeout: pid $($p.Id)"; $code = 9 }
    elseif ($p.ExitCode -ne 0) { $code = $p.ExitCode }
}
foreach ($role in @("host", "client")) {
    $lines = @(Get-Content (Join-Path $tmp "$role.out.txt") -Encoding UTF8) + @(Get-Content (Join-Path $tmp "$role.err.txt") -Encoding UTF8)
    $lines | Where-Object { $_ -match "COOP_SMOKE|SCRIPT ERROR|ERROR:|leaked" } | Select-Object -Unique -First 20 | ForEach-Object { Write-Host "[$role] $_" }
}
Write-Host "coop_smoke exit=$code"
exit $code
