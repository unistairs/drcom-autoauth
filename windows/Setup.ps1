# Setup.ps1 —— 交互式配置校园网账号(密码只存 MD5 派生哈希, 不落明文)
$ErrorActionPreference = "Stop"
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-Md5Hex([string]$s) {
  $md5 = [System.Security.Cryptography.MD5]::Create()
  return ([BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s)))).Replace("-", "").ToLower()
}

Write-Host "=== Dr.COM 自动认证 · 账号配置 ==="
$Acc = Read-Host "校园网账号"
if (-not $Acc) { Write-Host "账号不能为空"; exit 1 }
$Sec = Read-Host "校园网密码(输入不显示)" -AsSecureString
$Bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Sec)
$Plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
if (-not $Plain) { Write-Host "密码不能为空"; exit 1 }

# Dr.COM 上传的就是 MD5(pid+密码+calg)+calg+pid, pid=2/calg=12345678 是 portal 公开常量
$Hash = Get-Md5Hex("2" + $Plain + "12345678")
$Plain = $null   # 立即丢弃明文

$conf = @"
@{
    # 由 Setup.ps1 生成于 $(Get-Date -Format 'yyyy-MM-dd HH:mm')
    # 密码只存 MD5 派生值(认证等价物, 但不含明文); 如需改用明文, 加 Pass = "..." 即可
    Acc      = "$Acc"
    PassHash = "$Hash"

    # 只对这些 SSID 的 Wi-Fi 生效(数组; 有线不受限; 路由器 AP 名可加进来)
    WifiSsids = @("hfut-wlan")

    # portal 候选(真 portal 以劫持页跳转为准, 候选仅兜底)
    PortalCandidates = @("172.18.3.3", "172.18.2.2")

    # captive 检测探针(期望 204)
    Canary = "http://connect.rom.miui.com/generate_204"

    # portal 身份校验指纹(按学校实际情况调整)
    PortalSchoolName = "合肥工业大学"
    PortalIdPrefix   = "AH"
}
"@
Set-Content -Path (Join-Path $Base "config.psd1") -Value $conf -Encoding UTF8
Write-Host ""
Write-Host "配置完成: config.psd1 已生成"
Write-Host "提示: 哈希仅对本校 portal 参数有效; 它是认证等价物, 不要分享。"
Write-Host "下一步: .\Start.ps1 试跑一轮; 没问题后 .\Register-AutoAuthTask.ps1 常驻。"
