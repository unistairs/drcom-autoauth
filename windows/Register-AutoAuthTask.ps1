# 注册 autoauth 为登录自启计划任务(脚本内部 20 秒循环)
# 用法: 右键用 PowerShell 运行, 或在 PowerShell 中执行本脚本
$ErrorActionPreference = "Stop"
$scriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "AutoAuth.ps1"
if (-not (Test-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "config.psd1"))) {
  Write-Host "请先复制 config.example.psd1 为 config.psd1 并填入账号密码" -ForegroundColor Red
  exit 1
}
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "DrComAutoAuth" -Action $action -Trigger $trigger `
  -Settings $settings -Description "Dr.COM 校园网 portal 自动认证" -Force | Out-Null
Start-ScheduledTask -TaskName "DrComAutoAuth"
Write-Host "已注册并启动: DrComAutoAuth (登录自启, 每 20 秒检测认证)" -ForegroundColor Green
Write-Host "日志: $(Split-Path -Parent $MyInvocation.MyCommand.Path)\autoauth.log"
