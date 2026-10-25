---
name: bilibili-download
description: 下载 B 站视频/音频的官方源流（无平台水印）。默认 1080P：不足则降 720P，有更高（1080P+/4K）则取更高；高清需一次性扫码登录并自动清理凭据。用于"下载B站视频""去水印""要1080P/4K""只要音频"等请求。
---

# Bilibili Download（无水印）

B 站 playurl 返回的 DASH 源流本身不带平台水印，下载即无水印。唯一去不掉的是 UP 主烧进画面的"创作中心水印"——遇到直接说明，下载器无法处理。

## 选路

| 需求 | 做法 |
|---|---|
| **默认（推荐）** | 1080P 优先：≥1080 取最高，没有 1080 才退回 720 |
| 1080P / 4K / HDR / 杜比 | 一次性登录 → Download-Bilibili.ps1（默认档） |
| 不想登录、要快 | BBDown 匿名（约 720P，见下） |
| 只要音频 | Download-Bilibili.ps1 -AudioOnly |
| 字幕 / 弹幕 / 封面 | BBDown 的 --sub-only / --danmaku-only / --cover-only |

## 依赖安装（新机器）

```powershell
pip install -U yt-dlp                 # 必需：下载核心
winget install Gyan.FFmpeg            # 必需：合并音视频
winget install OpenJS.NodeJS.LTS      # 高清登录需要（导出 cookie）
npm i -g playwright                   # 高清登录需要
```

BBDown（可选，仅"匿名 720P 快速通道"用）：从 `https://github.com/nilaoda/BBDown/releases` 下载 `win-x64.zip`，解压到任意目录并加入 PATH，或放到 `%LOCALAPPDATA%\BBDown\BBDown.exe`。

脚本会自动在 PATH 和常见安装位置找 python / node / ffmpeg / BBDown / Playwright；找不到时按上面的命令装。特殊路径可改 `scripts/_config.ps1`。

## 分发说明

**只发 SKILL.md 不能用**——它只是说明书，真正的下载逻辑在 `scripts/` 里。给别人请发**整个 `bilibili-download` 文件夹**，并让对方先装上面四项依赖。

## 匿名 720P（最快）

```powershell
& "D:\CodexAutoEdit\tools\BBDown\BBDown.exe" "<url>" --work-dir "E:\B站下载" -tv
```

## 1080P+

1) 打开隔离登录窗口，记下输出的 SESSION_ROOT：

```powershell
& "<skill-dir>\scripts\Start-BilibiliLogin.ps1"
```

2) 让用户在该窗口扫码登录；确认登录后下载：

```powershell
& "<skill-dir>\scripts\Download-Bilibili.ps1" -Url "<url>" -OutputDirectory "E:\B站下载" -SessionRoot "<SESSION_ROOT>"
```

成功会打印 `RESULT {...}` 和 `ONE_TIME_SESSION_DELETED`；失败会保留会话（`SESSION_KEPT_FOR_RETRY`），可重试，用完再删：

```powershell
& "<skill-dir>\scripts\Clear-BilibiliSession.ps1" -SessionRoot "<SESSION_ROOT>"
```

参数：`-Quality 1080`（默认，≥1080 取最高、否则退回最佳）、`Best`（绝对最高）、`720`/`480`（限高）、`-AudioOnly`、`-ListFormats`、`-KeepSession`。

## 码率

B 站同一分辨率会提供多条流（AVC / HEVC / AV1），**同分辨率下 AVC 码率最高**（实测这条视频 720P：AVC 1604k、HEVC 805k、AV1 733k）。本技能默认 `vcodec^=avc1`，即"选该清晰度下码率最高、兼容最好"的那条——文件更大，但画质最稳。

档位参考（qn 越高码率越高）：

| 档位 | 典型码率 | 条件 |
|---|---|---|
| 720P | 1.2–1.6 Mbps | 匿名可用 |
| 1080P | ~1.2 Mbps | 登录可用 |
| 1080P 高码率(1080P+) | 3–6 Mbps | 大会员 |
| 4K / HDR / 杜比 | 10–20 Mbps+ | 大会员 |

判断依据以 ffprobe 的 `bit_rate` 为准；1200k 说明只拿到标准 1080P，想要 3 Mbps 以上必须大会员登录。

## 校验

脚本用 ffprobe 输出真实分辨率/编码/时长/大小；以 `RESULT` 为准，不要只看 yt-dlp 进度条。

## 坑（都踩过）

1. `.part` 长时间 0 字节不是卡死，是写盘延迟——等 2 分钟再看；中断后用 `-c` 续传。
2. `yt-dlp --cookies-from-browser edge` 在 Edge 运行时必失败（cookie 库被锁）；所以用隔离 profile 导出。
3. BBDown 自带登录已失效（仓库已归档），只当匿名快速通道，别用它登 1080P。
4. 认证流首包可能慢，重试即可；连续失败时放慢 2-3 秒，避免 412 风控。
5. 编码优先 H.264（`vcodec^=avc1`），兼容性最好；HEVC/AV1 只在画质更高时用。
6. cookie 只存在于临时文件，脚本 finally 删除；绝不打印 cookie 值。
