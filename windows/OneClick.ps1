$ErrorActionPreference = 'Stop'
$exe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
try {
  Write-Host '========== 校园网自动认证：一键启动 ==========' -ForegroundColor Cyan
  Write-Host '每次运行都会重新配置账号。请使用平时登录电脑的账户运行。'
  $steps = @(
    @{ File='Setup.ps1'; Text='配置校园网账号和密码' },
    @{ File='Start.ps1'; Text='试跑一次认证并显示日志' },
    @{ File='Register-AutoAuthTask.ps1'; Text='设置登录自启动并启动后台认证' }
  )
  for ($i=0; $i -lt $steps.Count; $i++) {
    Write-Host ("`n[第 {0} 步，共 3 步] {1}" -f ($i+1), $steps[$i].Text)
    & $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $steps[$i].File)
    if ($LASTEXITCODE -ne 0) { throw ('第 {0} 步失败，后续步骤未执行。请保留上方错误信息。' -f ($i+1)) }
  }
  Write-Host "`n设置完成！以后登录 Windows 会自动运行。" -ForegroundColor Green
  Write-Host '联网结果以日志为准。请保留整个项目文件夹的位置。'
  [void](Read-Host '按回车键关闭窗口')
  exit 0
} catch {
  Write-Host ("`n[失败] " + $_.Exception.Message) -ForegroundColor Red
  [void](Read-Host '按回车键关闭窗口')
  exit 1
}