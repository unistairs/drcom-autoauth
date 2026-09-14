# Dr.COM 校园网 portal 自动认证看门狗 (Windows / PowerShell 5.1+)
# 与 macOS 版逻辑一致: 逐链路 captive 检测 -> 顺劫持跳转找真 portal ->
#   四重指纹校验防钓鱼 -> ps/pid/calg -> MD5/base64 编码 -> POST 登录 -> msga 判定 -> 验证
# 依赖: Windows 10 1803+ 自带 curl.exe, PowerShell 5.1+。无需管理员(用户级计划任务即可)。
param([switch]$Once)   # -Once: 只跑一轮(手动调试); 默认 20 秒循环常驻

$ErrorActionPreference = "Continue"
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $Base "autoauth.log"
$ConfPath = Join-Path $Base "config.psd1"

function Log([string]$m) { Add-Content -Path $LogFile -Value ("{0} {1}" -f (Get-Date -Format "MM-dd HH:mm:ss"), $m) }

if (-not (Test-Path $ConfPath)) {
  Log "缺少 $ConfPath —— 请复制 config.example.psd1 为 config.psd1 并填入账号密码"
  exit 1
}
$Conf = Import-PowerShellDataFile $ConfPath
if (-not $Conf.Acc -or -not $Conf.Pass) { Log "config.psd1 缺少 Acc/Pass"; exit 1 }
$WifiSsidRequired = if ($Conf.WifiSsidRequired) { $Conf.WifiSsidRequired } else { "hfut-wlan" }
$PortalCandidates = if ($Conf.PortalCandidates) { $Conf.PortalCandidates } else { @("172.18.3.3", "172.18.2.2") }
$Canary = if ($Conf.Canary) { $Conf.Canary } else { "http://connect.rom.miui.com/generate_204" }
$SchoolName = if ($Conf.PortalSchoolName) { $Conf.PortalSchoolName } else { "合肥工业大学" }
$PortalIdPrefix = if ($Conf.PortalIdPrefix) { $Conf.PortalIdPrefix } else { "AH" }

function Decode-GB2312([string]$path) {
  if (-not (Test-Path $path)) { return "" }
  $bytes = [System.IO.File]::ReadAllBytes($path)
  return [System.Text.Encoding]::GetEncoding(936).GetString($bytes)
}

# 活跃链路: 有线全部 + Wi-Fi(仅指定 SSID)
function Get-ActiveLegs {
  $wifiSsid = ""
  $netsh = netsh wlan show interfaces 2>$null | Select-String "^\s*SSID\s*:\s*(.+)$"
  if ($netsh) { $wifiSsid = $netsh.Matches[0].Groups[1].Value.Trim() }
  Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notmatch "^169\.254\." -and $_.IPAddress -ne "127.0.0.1" } |
    ForEach-Object {
      $alias = $_.InterfaceAlias
      $isWifi = $alias -match "(?i)wi-?fi|wlan|无线"
      if ($isWifi -and $wifiSsid -ne $WifiSsidRequired) { return }
      [PSCustomObject]@{ Alias = $alias; IP = $_.IPAddress }
    }
}

function Captive-Check([string]$srcIp, [string]$outFile) {
  $code = & curl.exe --noproxy '' -sS --interface $srcIp --connect-timeout 4 --max-time 8 `
    $Canary -o $outFile -w '%{http_code}' 2>$null
  return ($code -replace '\D','')
}

function Extract-PortalIp([string]$bodyFile) {
  if (-not (Test-Path $bodyFile)) { return $null }
  $m = Select-String -Path $bodyFile -Pattern 'https?://(\d+\.\d+\.\d+\.\d+)' | Select-Object -First 1
  if ($m) { return $m.Matches[0].Groups[1].Value }
  return $null
}

# portal 身份四重指纹校验(全部通过才交凭据)
function Test-PortalIdentity([string]$srcIp, [string]$portal) {
  $tmp = Join-Path $env:TEMP "drcom_page_$portal.html"
  & curl.exe --noproxy '' -sS --interface $srcIp --connect-timeout 3 --max-time 6 "http://$portal/" -o $tmp 2>$null | Out-Null
  $page = Decode-GB2312 $tmp
  if ($page -notmatch "DrCOMWebLoginID") { return $false }
  if ($page -match "DrCOMWebLoginID_3|已经成功登录") { return $true }   # 已在线页同样是真 portal 指纹
  if ($page -notmatch "portalname='$([regex]::Escape($SchoolName))") { return $false }
  if ($page -notmatch "portalid='$([regex]::Escape($PortalIdPrefix))\d+") { return $false }
  if ($page -notmatch "ss5='$([regex]::Escape($srcIp))'") { return $false }
  return $true
}

function Test-HintIp([string]$ip) { return $ip -match '^172\.(1[6-9]|2[0-9]|3[01])\.\d+\.\d+$' }

function Get-Md5Hex([string]$s) {
  $md5 = [System.Security.Cryptography.MD5]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
  return ([BitConverter]::ToString($md5.ComputeHash($bytes))).Replace("-", "").ToLower()
}

$script:LoginMsg = ""
function Invoke-Login([string]$srcIp, [string]$portal) {
  # 返回: 0=成功 1=失败 2=失败且 LoginMsg 有服务端原因
  $jsRaw = & curl.exe --noproxy '' -sS --interface $srcIp --connect-timeout 3 --max-time 6 "http://$portal/a41.js" 2>$null | Select-Object -First 1
  $pid_v = "2"; $calg = "12345678"; $ps = "1"
  if ($jsRaw -match "pid='([^']*)'") { $pid_v = $Matches[1] }
  if ($jsRaw -match "calg='([^']*)'") { $calg = $Matches[1] }
  if ($jsRaw -match "ps=(\d)") { $ps = $Matches[1] }
  if ($ps -eq "0") {
    $upass = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Conf.Pass)); $r2 = "0"
  } else {
    $upass = (Get-Md5Hex("$pid_v$($Conf.Pass)$calg")) + $calg + $pid_v; $r2 = "1"
  }
  $respFile = Join-Path $env:TEMP "drcom_login_resp.html"
  & curl.exe --noproxy '' -sS --interface $srcIp --connect-timeout 5 --max-time 12 -X POST "http://$portal/0.htm" `
    --data-urlencode "DDDDD=$($Conf.Acc)" --data-urlencode "upass=$upass" `
    --data-urlencode "R1=0" --data-urlencode "R2=$r2" --data-urlencode "para=00" `
    --data-urlencode "0MKKey=123456" --data-urlencode "v6ip=" -o $respFile 2>$null | Out-Null
  $resp = Decode-GB2312 $respFile
  # 先解析服务端 msga(失败原因): 非空即失败, 页面模板里的"成功"字样不算数
  if ($resp -match "msga='([^']+)'") { $script:LoginMsg = $Matches[1]; return 2 }
  if ($resp -match "成功") { return 0 }
  return 1
}

$CurfewFile = Join-Path $Base ".curfew_seen"
function Curfew-Active {
  if (-not (Test-Path $CurfewFile)) { return $false }
  return ((Get-Date) - (Get-Item $CurfewFile).LastWriteTime).TotalSeconds -lt 1800
}

function Run-Pass {
  foreach ($leg in Get-ActiveLegs) {
    $if = $leg.Alias; $ip = $leg.IP
    $page = Join-Path $env:TEMP "drcom_captive.html"
    $code = Captive-Check $ip $page
    if ($code -eq "204") { continue }
    if ($code -eq "000" -or $code -eq "") { Log "[$if/$ip] 无响应(链路不通), 跳过"; continue }
    Log "[$if/$ip] 检测到 portal 劫持 (HTTP $code), 开始认证"
    $hint = Extract-PortalIp $page
    $portal = $null
    foreach ($c in @($hint) + $PortalCandidates) {
      if ([string]::IsNullOrEmpty($c)) { continue }
      if ($c -eq $hint -and -not (Test-HintIp $c)) { Log "[$if/$ip] 劫持跳转到非校园地址 $c, 可疑, 跳过"; continue }
      if (Test-PortalIdentity $ip $c) { $portal = $c; break }
      Log "[$if/$ip] $c 身份校验未通过, 拒交凭据"
    }
    if (-not $portal) { Log "[$if/$ip] 未找到可信 portal (hint=$hint), 放弃本轮"; continue }
    if (Curfew-Active) { continue }
    $rc = Invoke-Login $ip $portal
    if ($rc -eq 0) {
      Remove-Item $CurfewFile -ErrorAction SilentlyContinue
      Start-Sleep 2
      $v = Captive-Check $ip $page
      if ($v -eq "204") { Log "[$if/$ip] 认证成功(portal=$portal), 链路已通" }
      else { Log "[$if/$ip] 登录响应成功但验证仍为 $v, 下轮重试(portal=$portal)" }
    } elseif ($rc -eq 2) {
      if ($script:LoginMsg -match "时段|禁止") {
        Set-Content -Path $CurfewFile -Value (Get-Date).ToString()
        Log "[$if/$ip] 校园网宵禁时段($($script:LoginMsg)), 30 分钟后再试"
      } else {
        Log "[$if/$ip] 登录被拒绝(portal=$portal): $($script:LoginMsg)"
      }
    } else {
      Log "[$if/$ip] 登录失败(portal=$portal), 下轮重试"
    }
  }
}

if ($Once) { Run-Pass } else { while ($true) { Run-Pass; Start-Sleep 20 } }
