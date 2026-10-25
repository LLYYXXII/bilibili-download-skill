[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [string]$OutputDirectory = 'E:\B站下载',
    [ValidateSet('Best','1080','720','480')][string]$Quality = '1080',
    [string]$SessionRoot,
    [switch]$AudioOnly,
    [switch]$ListFormats,
    [switch]$KeepSession
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_config.ps1')

if (!(Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$cookiesPath = $null
$resolvedSession = $null
$code = 1
try {
    if ($SessionRoot) {
        $resolvedSession = [IO.Path]::GetFullPath($SessionRoot)
        if (!(Test-Path -LiteralPath (Join-Path $resolvedSession '.bilibili-download-session.json') -PathType Leaf)) {
            throw 'Session root failed ownership checks.'
        }
        if (-not $NodeExe) { throw "Node.js not found; 1080P+ login needs it. Install: winget install OpenJS.NodeJS.LTS." }
        if (-not $env:BILI_PW_MODULE) {
            throw 'Playwright module not found; 1080P+ login needs it. Install: npm i -g playwright (or set BILI_PW_MODULE).'
        }
        Stop-EdgeForProfile (Join-Path $resolvedSession 'profile')
        $cookiesPath = Join-Path $CookieDir ('bili-cookies-' + [guid]::NewGuid().ToString('N') + '.txt')
        & $NodeExe (Join-Path $PSScriptRoot 'Export-Cookies.cjs') (Join-Path $resolvedSession 'profile') $cookiesPath
        if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $cookiesPath)) {
            throw 'Cookie export failed. Sign in again in the isolated window (Start-BilibiliLogin.ps1) and pass a fresh -SessionRoot.'
        }
    }

    $format = if ($AudioOnly) { 'ba/b' } else {
        switch ($Quality) {
            'Best' { 'bv*[vcodec^=avc1]+ba/bv*+ba/b' }
            '1080' { 'bv*[height>=1080][vcodec^=avc1]+ba/bv*[height>=1080]+ba/bv*[vcodec^=avc1]+ba/bv*+ba/b' }
            '720'  { 'bv*[height<=720][vcodec^=avc1]+ba/bv*[height<=720]+ba/b' }
            '480'  { 'bv*[height<=480][vcodec^=avc1]+ba/bv*[height<=480]+ba/b' }
        }
    }

    $ytArgs = @(
        '-m', 'yt_dlp', '--no-playlist', '-c',
        '--merge-output-format', 'mp4',
        '--ffmpeg-location', $FFmpegBin,
        '-o', (Join-Path $OutputDirectory '%(title)s [%(id)s].%(ext)s')
    )
    if ($ListFormats) { $ytArgs += '-F' }
    elseif ($AudioOnly) { $ytArgs += @('-x', '--audio-format', 'm4a', '--audio-quality', '0') }
    else { $ytArgs += @('-f', $format) }
    if ($cookiesPath) { $ytArgs += @('--cookies', $cookiesPath) }
    $ytArgs += $Url

    & $PythonExe @ytArgs
    $code = $LASTEXITCODE

    if ($code -eq 0 -and !$ListFormats) {
        $newest = Get-ChildItem -LiteralPath $OutputDirectory -File |
            Where-Object { $_.Extension -in '.mp4', '.m4a', '.mkv', '.webm' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($newest) {
            $probe = & $FFprobeExe -v error -show_entries 'format=duration,size:stream=codec_type,codec_name,width,height' -of json $newest.FullName
            $json = $probe | ConvertFrom-Json
            $v = $json.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
            $a = $json.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
            $summary = [PSCustomObject]@{
                path = $newest.FullName
                megabytes = [math]::Round($newest.Length / 1MB, 1)
                durationSeconds = [math]::Round([double]$json.format.duration, 1)
                video = if ($v) { "$($v.codec_name) $($v.width)x$($v.height)" } else { $null }
                audio = if ($a) { $a.codec_name } else { $null }
            }
            Write-Output ('RESULT ' + ($summary | ConvertTo-Json -Compress))
        }
    }
} finally {
    if ($cookiesPath -and (Test-Path -LiteralPath $cookiesPath)) { Remove-Item -LiteralPath $cookiesPath -Force }
}

if ($code -eq 0 -and $resolvedSession -and !$KeepSession) {
    Stop-EdgeForProfile (Join-Path $resolvedSession 'profile')
    Remove-Item -LiteralPath $resolvedSession -Recurse -Force
    Write-Output 'ONE_TIME_SESSION_DELETED'
}
if ($code -ne 0) {
    if ($resolvedSession) { Write-Output ('SESSION_KEPT_FOR_RETRY ' + $resolvedSession) }
    Write-Output 'HINT: anonymous tops out near 720P; for 1080P+ pass -SessionRoot (one-time QR login). On 412 risk control, wait 2-3s and retry.'
    exit $code
}
