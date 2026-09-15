# Start.ps1 —— 手动跑一轮认证巡逻并显示日志
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path (Join-Path $Base "config.psd1"))) {
  Write-Host "未配置, 请先运行: .\Setup.ps1" -ForegroundColor Red
  exit 1
}
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Base "AutoAuth.ps1") -Once
$runExitCode = $LASTEXITCODE
Write-Host "--- 最近日志 ---"
$log = Join-Path $Base "autoauth.log"
if (Test-Path $log) { Get-Content $log -Encoding UTF8 -Tail 5 } else { Write-Host "(无日志: 各链路健康, 无需认证)" }

exit $runExitCode
