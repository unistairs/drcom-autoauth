$ErrorActionPreference='Stop'
$t=$null;$e=$null
$a=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'AutoAuth.ps1'),[ref]$t,[ref]$e)
if($e.Count){throw ($e.Message -join '; ')}
foreach($name in @('Run-Pass','Get-RetryDelay')){
$n=$a.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
Invoke-Expression $n.Extent.Text
}
function Get-ActiveLegs {[pscustomobject]@{Alias='WLAN';IP='172.21.0.69'}}
function Log {param($m)}
function Test-PortalIdentity {$script:PortalIsLoginPage=$true;return $true}
function Curfew-Active {return $false}
function Invoke-Login {$script:calls.Add('login');return 1}
function Captive-Check {$script:calls.Add('canary');return '204'}
$PortalCandidates=@('172.18.3.3');$script:NetworkChanged=$true
$script:calls=New-Object 'System.Collections.Generic.List[string]'
Run-Pass
if(($script:calls -join ',') -ne 'login'){throw 'Fast path did not precede public probe'}
$script:NetworkChanged=$false;$script:calls.Clear()
Run-Pass
if(($script:calls -join ',') -ne 'canary'){throw 'Online pass attempted login'}
foreach($case in @(@{Pending=0;Slow=$false;Failures=0;Expected=60},@{Pending=1;Slow=$false;Failures=1;Expected=5},@{Pending=1;Slow=$false;Failures=7;Expected=30},@{Pending=1;Slow=$true;Failures=1;Expected=60})){
$script:PendingLegs=$case.Pending;$script:SlowRetry=$case.Slow
if((Get-RetryDelay $case.Failures) -ne $case.Expected){throw 'Retry delay mismatch'}
}
'PASS: network-change portal-first, online canary-only, online/fast/backoff/rejection delays. Mocked requests only.'