# 当前用户登录自启动，不需要管理员权限。
$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$scriptPath = Join-Path $base 'AutoAuth.ps1'
if (-not (Test-Path (Join-Path $base 'config.psd1'))) { throw '请先配置校园网账号。' }
$exe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$arguments = '-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $scriptPath
$command = '"{0}" {1}' -f $exe, $arguments
if ($command.Length -gt 260) { throw '项目路径过长，请将整个项目移动到较短路径后重试。' }
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
New-Item -Path $key -Force | Out-Null
New-ItemProperty -Path $key -Name 'DrComAutoAuth' -Value $command -PropertyType String -Force | Out-Null
if ((Get-ItemPropertyValue -Path $key -Name 'DrComAutoAuth') -ne $command) { throw '自启动项写入后校验失败。' }
$process = Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 2
if ($process.HasExited -and $process.ExitCode -ne 0) { throw '后台启动失败，请查看 autoauth.log。' }
Write-Host '已设置当前用户登录自启动，并启动后台认证。无需管理员权限。' -ForegroundColor Green
Write-Host "日志：$(Join-Path $base 'autoauth.log')"