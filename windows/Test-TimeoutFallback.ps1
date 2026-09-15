$ErrorActionPreference='Stop'
$t=$null;$e=$null
$a=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'AutoAuth.ps1'),[ref]$t,[ref]$e)
$n=$a.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Run-Pass'},$true)
Invoke-Expression $n.Extent.Text
function Get-ActiveLegs { [pscustomobject]@{Alias='WLAN';IP='172.21.0.69'} }
function Captive-Check {return $script:code}
function Log {param($m)}
function Extract-PortalIp {return $null}
function Test-PortalIdentity {$script:PortalIsLoginPage=$script:loginPage;return $script:trusted}
function Curfew-Active {return $false}
function Invoke-Login {$script:attempts++;return 1}
$PortalCandidates=@('172.18.3.3');$Once=$true
foreach($case in @(
 @{Code='000';Trusted=$true;Login=$true;Expected=1},
 @{Code='000';Trusted=$true;Login=$false;Expected=0},
 @{Code='000';Trusted=$false;Login=$true;Expected=0},
 @{Code='204';Trusted=$true;Login=$true;Expected=0}
)) {
 $script:code=$case.Code;$script:trusted=$case.Trusted;$script:loginPage=$case.Login;$script:attempts=0
 Run-Pass
 if($script:attempts -ne $case.Expected){throw 'Timeout fallback regression'}
}
'PASS: timeout + trusted login page attempts login; status page/untrusted page/HTTP 204 do not. Mocked requests only.'