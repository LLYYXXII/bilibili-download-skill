[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_config.ps1')

$sessionRoot = Join-Path $SessionBase ([guid]::NewGuid().ToString())
$profileDir  = Join-Path $sessionRoot 'profile'
$edge = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (!$edge) { throw 'Microsoft Edge is required for the isolated login session.' }

try {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sessionRoot '.bilibili-download-session.json') -Value '{"owner":"bilibili-download","version":1}' -Encoding UTF8
    $arguments = @(
        '--user-data-dir=' + $profileDir,
        '--profile-directory=Default',
        '--no-first-run',
        '--disable-features=msEdgeFirstRunExperience',
        'https://passport.bilibili.com/login'
    )
    $process = Start-Process -FilePath $edge -ArgumentList $arguments -PassThru
    Write-Output "SESSION_ROOT=$sessionRoot"
    Write-Output "TEMP_EDGE_PID=$($process.Id)"
    Write-Output 'Sign in inside this isolated Edge window, then run Download-Bilibili.ps1 -SessionRoot <SESSION_ROOT>.'
} catch {
    if (Test-Path -LiteralPath $sessionRoot) { Remove-Item -LiteralPath $sessionRoot -Recurse -Force }
    throw
}
