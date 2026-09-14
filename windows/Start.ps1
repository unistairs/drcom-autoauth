# Start.ps1 —— 手动跑一轮认证巡逻并显示日志
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path (Join-Path $Base "config.psd1"))) {
  Write-Host "未配置, 请先运行: .\Setup.ps1" -ForegroundColor Red
  exit 1
}
& (Join-Path $Base "AutoAuth.ps1") -Once
Write-Host "--- 最近日志 ---"
$log = Join-Path $Base "autoauth.log"
if (Test-Path $log) { Get-Content $log -Tail 5 } else { Write-Host "(无日志: 各链路健康, 无需认证)" }
