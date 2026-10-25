# 共享配置与工具函数（由其它脚本 dot-source）
$ErrorActionPreference = 'Stop'

function Resolve-Tool([string]$Name, [string[]]$Candidates) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($c in $Candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return $c }
    }
    throw "$Name is required but was not found. See SKILL.md > 依赖安装."
}

function Stop-EdgeForProfile([string]$ProfilePath) {
    # 只关闭属于该隔离 profile 的 Edge 进程；容忍 PID 竞态
    for ($i = 0; $i -lt 20; $i++) {
        $procs = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($ProfilePath, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
        if (!$procs.Count) { return }
        foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Milliseconds 250
    }
    throw 'The isolated Edge process is still running; cleanup withheld.'
}

$PythonExe = Resolve-Tool 'python' @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe')
)

# Node / BBDown 仅在特定路径用到，找不到不报错
$NodeExe = @(
    (Get-Command node -ErrorAction SilentlyContinue).Source,
    (Join-Path $env:ProgramFiles 'nodejs\node.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'nodejs\node.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1

$BBDownExe = @(
    $env:BBDOWN_EXE,
    (Get-Command BBDown -ErrorAction SilentlyContinue).Source,
    (Join-Path $env:LOCALAPPDATA 'BBDown\BBDown.exe'),
    (Join-Path $env:USERPROFILE 'BBDown\BBDown.exe'),
    'D:\CodexAutoEdit\tools\BBDown\BBDown.exe'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1

# ffmpeg：优先 PATH，其次常见安装位置
$ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegCmd) {
    $FFmpegBin = Split-Path -Parent $ffmpegCmd.Source
} else {
    $FFmpegBin = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'),
        'D:\CodexAutoEdit\tools\ffmpeg\ffmpeg-9.0.1-essentials_build\bin',
        'C:\ffmpeg\bin'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'ffmpeg.exe')) } | Select-Object -First 1
}
if (-not $FFmpegBin) { throw 'ffmpeg not found. Install: winget install Gyan.FFmpeg (or add ffmpeg to PATH).' }
$FFprobeExe = Join-Path $FFmpegBin 'ffprobe.exe'

# 临时会话/凭据统一放 D 盘，避免污染 C 盘
$SessionBase = 'D:\Temp\bilibili-download'
if (-not (Test-Path -LiteralPath $SessionBase)) { New-Item -ItemType Directory -Path $SessionBase -Force | Out-Null }
$CookieDir = Join-Path $SessionBase 'cookies'
if (-not (Test-Path -LiteralPath $CookieDir)) { New-Item -ItemType Directory -Path $CookieDir -Force | Out-Null }

# Playwright 只在高清登录时需要；找不到时留空
$Script:PlaywrightModule = @(
    $env:BILI_PW_MODULE,
    $env:CODEX_PLAYWRIGHT_MODULE,
    (Join-Path $env:APPDATA 'npm\node_modules\playwright'),
    (Join-Path $env:APPDATA 'npm\node_modules\@playwright\cli\node_modules\playwright'),
    (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules\playwright')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 1
if ($Script:PlaywrightModule) { $env:BILI_PW_MODULE = $Script:PlaywrightModule } else { $env:BILI_PW_MODULE = '' }
