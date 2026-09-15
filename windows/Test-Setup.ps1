$ErrorActionPreference='Stop'
$dir=Join-Path $env:TEMP ('drcom-setup-test-'+[guid]::NewGuid())
New-Item -ItemType Directory $dir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'Setup.ps1') $dir
$path=Join-Path $dir 'config.psd1'
@"
@{ Acc='test-account'; PassHash='test-hash'; WifiSsids=@('existing'); PortalCheck='strict' }
"@ | Set-Content $path -Encoding UTF8
$global:DrComSetupTestAnswers=New-Object 'System.Collections.Generic.Queue[string]'
foreach($v in @('','','new-network','existing',"cafe's `$wifi",'')){ $global:DrComSetupTestAnswers.Enqueue($v) }
function Read-Host { param($Prompt,[switch]$AsSecureString)
 $v=$global:DrComSetupTestAnswers.Dequeue()
 if($AsSecureString){$sec=New-Object Security.SecureString;foreach($ch in $v.ToCharArray()){$sec.AppendChar($ch)};return $sec}
 return $v
}
& (Join-Path $dir 'Setup.ps1')
$c=Import-PowerShellDataFile $path
if($c.Acc -ne 'test-account' -or $c.PassHash -ne 'test-hash' -or $c.PortalCheck -ne 'strict'){throw 'Existing settings changed'}
if($c.WifiSsids.Count -ne 4 -or $c.WifiSsids -notcontains 'hfut-wlan' -or $c.WifiSsids -notcontains "cafe's `$wifi"){throw 'SSID merge/escaping failure'}
foreach($v in @('','','')){$global:DrComSetupTestAnswers.Enqueue($v)}
& (Join-Path $dir 'Setup.ps1')
$d=Import-PowerShellDataFile $path
if(($c.WifiSsids -join '|') -ne ($d.WifiSsids -join '|')){throw 'Enter-only changed SSIDs'}
foreach($v in @('new-account','synthetic-test-password','')){$global:DrComSetupTestAnswers.Enqueue($v)}
& (Join-Path $dir 'Setup.ps1')
$c=Import-PowerShellDataFile $path
if($c.Acc -ne 'new-account' -or -not $c.PassProtected -or $c.ContainsKey('PassHash')){throw 'Credential replacement failed'}
'PASS: keep credentials/settings, append/deduplicate/default SSID, quote escaping, Enter-only rerun, DPAPI replacement. Isolated synthetic configuration only.'