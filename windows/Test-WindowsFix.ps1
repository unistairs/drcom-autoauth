$ErrorActionPreference='Stop'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'AutoAuth.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors.Message -join '; ') }
foreach ($name in @('Test-PortalIdentity','Get-CanaryResolveArgs')) {
  $node=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
  Invoke-Expression $node.Extent.Text
}
function Log { param($m) }
function curl.exe { $global:LASTEXITCODE=0 }
function Decode-GB2312 { return $script:page }
$SchoolName='合肥工业大学'; $PortalIdPrefix='AH'; $Conf=@{PortalCheck='normal'}
$script:page="Dr.COMWebLoginID authsuccess='Dr.COMWebLoginID_3.htm'; portalname='假学校'; portalid='AH123'; ss5='172.19.9.90'"
if (Test-PortalIdentity '172.19.9.90' '172.18.3.3') { throw 'Success-template identity bypass' }
$script:page="Dr.COMWebLoginID portalname='合肥工业大学'; portalid='AH123'; ss5='172.19.9.90'"
if (-not (Test-PortalIdentity '172.19.9.90' '172.18.3.3')) { throw 'Valid identity rejected' }
$Conf.PortalCheck='strict'
if (Test-PortalIdentity '172.19.9.91' '172.18.3.3') { throw 'Strict mismatch accepted' }
$Canary='http://connect.rom.miui.com/generate_204'
function Resolve-DnsName { [pscustomobject]@{IPAddress='198.18.1.88'} }
$script:CanaryRefresh=(Get-Date).AddMinutes(5); $script:CanaryAddress='120.133.85.84'
$result=@(Get-CanaryResolveArgs)
if ($result.Count -ne 2 -or $result[1] -ne 'connect.rom.miui.com:80:120.133.85.84') { throw 'Fake-IP resolve failed' }
function Resolve-DnsName { [pscustomobject]@{IPAddress='120.133.85.84'} }
if (@(Get-CanaryResolveArgs).Count -ne 0) { throw 'Normal DNS was overridden' }
'PASS: syntax, template bypass rejection, valid identity, strict binding, Fake-IP override, normal DNS unchanged'