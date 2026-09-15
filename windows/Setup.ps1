# 交互配置：回车保留已有凭据，SSID 只追加。
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$path = Join-Path $PSScriptRoot 'config.psd1'
function Quote-Data([string]$value) { return "'" + $value.Replace("'", "''") + "'" }
function Format-Data($value) {
  if ($null -eq $value) { return '$null' }
  if ($value -is [string]) { return (Quote-Data $value) }
  if ($value -is [bool]) { if ($value) { return '$true' }; return '$false' }
  if ($value -is [array]) { return '@(' + (($value | ForEach-Object { Format-Data $_ }) -join ', ') + ')' }
  if ($value -is [int] -or $value -is [double]) { return $value.ToString([Globalization.CultureInfo]::InvariantCulture) }
  throw '配置中存在不支持的数据类型，原文件未修改。'
}
$conf = @{
  WifiSsids=@('hfut-wlan'); PortalCandidates=@('172.18.3.3','172.18.2.2')
  Canary='http://connect.rom.miui.com/generate_204'; PortalSchoolName='合肥工业大学'
  PortalIdPrefix='AH'; PortalCheck='normal'
}
if (Test-Path $path) { $conf = Import-PowerShellDataFile -LiteralPath $path }
Write-Host '=== 校园网配置：已有内容可直接回车保留 ==='
$acc = Read-Host '校园网账号（已有账号时回车保留）'
if ($acc) { $conf.Acc = $acc }
if (-not $conf.Acc) { throw '首次配置必须输入账号，原配置未修改。' }
$sec = Read-Host '校园网密码（输入不显示；已有密码时回车保留）' -AsSecureString
if ($sec.Length -gt 0) {
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    $bytes = [Text.Encoding]::UTF8.GetBytes($plain)
    $protected = [Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    $conf.PassProtected = [Convert]::ToBase64String($protected)
    $conf.Remove('Pass'); $conf.Remove('PassHash')
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    if ($bytes) { [Array]::Clear($bytes,0,$bytes.Length) }
    $plain = $null
  }
} elseif (-not $conf.Pass -and -not $conf.PassProtected -and -not $conf.PassHash) {
  throw '首次配置必须输入密码，原配置未修改。'
}
$ssids = New-Object 'System.Collections.Generic.List[string]'
foreach ($ssid in @('hfut-wlan') + @($conf.WifiSsids) + @($conf.WifiSsidRequired)) {
  if ($ssid -and -not $ssids.Contains([string]$ssid)) { $ssids.Add([string]$ssid) }
}
Write-Host ('当前允许的 Wi-Fi：' + ($ssids -join '、'))
Write-Host '每次输入一个完整 Wi-Fi 名称，按回车添加；可继续添加，空白回车结束。'
while ($true) {
  $ssid = Read-Host '追加 Wi-Fi 名称（回车保留并继续启动）'
  if ([string]::IsNullOrEmpty($ssid)) { break }
  if (-not $ssids.Contains($ssid)) { $ssids.Add($ssid); Write-Host '已加入列表。' }
  else { Write-Host '已存在，无需重复添加。' }
}
$conf.WifiSsids = $ssids.ToArray()
$lines = @('@{') + @($conf.Keys | Sort-Object | ForEach-Object { '    ' + (Quote-Data $_) + ' = ' + (Format-Data $conf[$_]) }) + @('}')
$temp = $path + '.tmp.psd1'
try {
  [IO.File]::WriteAllLines($temp,$lines,[Text.UTF8Encoding]::new($true))
  $null = Import-PowerShellDataFile -LiteralPath $temp
  Move-Item -LiteralPath $temp -Destination $path -Force
} finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp } }
Write-Host '配置已保存：未重新输入的凭据保持不变，Wi-Fi 名单只追加。'
Write-Host '接下来试跑并启动后台。'