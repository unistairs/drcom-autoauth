# Setup.ps1 —— 交互式配置校园网账号(密码用 Windows DPAPI 加密存储, 仅本机本用户可解)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Security
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== Dr.COM 自动认证 · 账号配置 ==="
$Acc = Read-Host "校园网账号"
if (-not $Acc) { Write-Host "账号不能为空"; exit 1 }
$Sec = Read-Host "校园网密码(输入不显示)" -AsSecureString
$Bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Sec)
$Plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
if (-not $Plain) { Write-Host "密码不能为空"; exit 1 }

# DPAPI 加密(当前用户范围): 只有本机本用户能解密, 不含明文, 不触发杀软
$enc = [System.Security.Cryptography.ProtectedData]::Protect(
  [System.Text.Encoding]::UTF8.GetBytes($Plain), $null,
  [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
$Protected = [Convert]::ToBase64String($enc)
$Plain = $null

$conf = @"
@{
    # 由 Setup.ps1 生成于 $(Get-Date -Format 'yyyy-MM-dd HH:mm')
    # PassProtected = DPAPI(CurrentUser) 加密后的密码(base64); 只有本机本用户可解
    # 不要把它拷到别的机器/用户下, 解不开(换机器重跑 Setup.ps1 即可)
    Acc           = "$Acc"
    PassProtected = "$Protected"

    # 只对这些 SSID 的 Wi-Fi 生效(数组; 有线不受限; 路由器 AP 名可加进来)
    WifiSsids = @("hfut-wlan")

    # portal 候选(真 portal 以劫持页跳转为准, 候选仅兜底)
    PortalCandidates = @("172.18.3.3", "172.18.2.2")

    # captive 检测探针(期望 204)
    Canary = "http://connect.rom.miui.com/generate_204"

    # portal 身份校验指纹(按学校实际情况调整)
    PortalSchoolName = "合肥工业大学"
    PortalIdPrefix   = "AH"

    # 校验严格度: normal=兼容路由器/NAT | strict=ss5 须等于本机 IP(仅直连)
    PortalCheck = "normal"
}
"@
Set-Content -Path (Join-Path $Base "config.psd1") -Value $conf -Encoding UTF8
Write-Host ""
Write-Host "配置完成: 密码已用 DPAPI 加密存储(绑定本机本用户), config.psd1 不含明文"
Write-Host "下一步: .\Start.ps1 试跑一轮; 没问题后 .\Register-AutoAuthTask.ps1 常驻。"
