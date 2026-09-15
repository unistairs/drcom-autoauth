$ErrorActionPreference = 'Stop'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if (Get-ItemProperty -Path $key -Name DrComAutoAuth -ErrorAction SilentlyContinue) {
  Remove-ItemProperty -Path $key -Name DrComAutoAuth
}
# 兼容旧版计划任务。
$task = Get-ScheduledTask -TaskName DrComAutoAuth -ErrorAction SilentlyContinue
if ($task) {
  Stop-ScheduledTask -TaskName DrComAutoAuth
  Unregister-ScheduledTask -TaskName DrComAutoAuth -Confirm:$false
}
$target = '"' + (Join-Path $PSScriptRoot 'AutoAuth.ps1') + '"'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($target) } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction Stop }
Write-Host '已取消登录自启动并停止本项目后台进程；账号配置和脚本已保留。'