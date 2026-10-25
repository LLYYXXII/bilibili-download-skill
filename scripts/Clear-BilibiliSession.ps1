[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$SessionRoot)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_config.ps1')

$resolved = [IO.Path]::GetFullPath($SessionRoot)
if (!(Test-Path -LiteralPath (Join-Path $resolved '.bilibili-download-session.json') -PathType Leaf)) {
    throw 'Session root failed ownership checks.'
}
$profile = Join-Path $resolved 'profile'
if (Test-Path -LiteralPath $profile) { Stop-EdgeForProfile $profile }
Remove-Item -LiteralPath $resolved -Recurse -Force
Write-Output 'ONE_TIME_SESSION_DELETED'