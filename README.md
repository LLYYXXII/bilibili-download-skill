# bilibili-download (no watermark)

B 站视频/音频下载的 agent skill。默认 **1080P**（不足退 720P，有更高取更高），下载官方 DASH 源流，**无平台水印**。

> A Codex / Claude Code / DSH skill for downloading Bilibili videos at the highest quality your account is entitled to. Official DASH source streams are watermark-free.

## 为什么"无水印"

B 站 `playurl` 返回的源流本身不带平台水印，下载即无水印。唯一去不掉的是 UP 主烧进画面的"创作中心水印"。

## 安装

把本仓库内容放到你的 skills 目录（文件夹名建议 `bilibili-download`）：

| 宿主 | 路径 |
|---|---|
| Codex | `~/.codex/skills/bilibili-download/` |
| Claude Code | `~/.claude/skills/bilibili-download/` |
| DSH | `<DSH_HOME>/skills/bilibili-download/` |

## 依赖

```powershell
pip install -U yt-dlp                 # 必需
winget install Gyan.FFmpeg            # 必需
winget install OpenJS.NodeJS.LTS      # 1080P+ 登录需要
npm i -g playwright                   # 1080P+ 登录需要
```

可选：`BBDown`（仅匿名 720P 快速通道），从 [Releases](https://github.com/nilaoda/BBDown/releases) 下载 `win-x64.zip`。

## 用法

```powershell
# 1) 匿名（约 720P，最快，不需要登录）
BBDown.exe "<url>" --work-dir "$HOME\Downloads\Bilibili" -tv

# 2) 默认档（1080P 优先；不足回 720P；有 1080P+/4K 取更高）
./scripts/Start-BilibiliLogin.ps1              # 扫码登录，记下 SESSION_ROOT
./scripts/Download-Bilibili.ps1 -Url "<url>" -SessionRoot "<SESSION_ROOT>"

# 其它
./scripts/Download-Bilibili.ps1 -Url "<url>" -AudioOnly     # 只要音频
./scripts/Download-Bilibili.ps1 -Url "<url>" -ListFormats   # 查看可用清晰度
#   -Quality Best|1080|720|480（默认 1080）
```

成功会打印 `RESULT {...}`（分辨率/编码/时长/大小/路径）和 `ONE_TIME_SESSION_DELETED`。

## 码率说明

B 站同一分辨率提供 AVC / HEVC / AV1 多档，**同分辨率下 AVC 码率最高**（实测 720P：AVC 1604k / HEVC 805k / AV1 733k）。默认 `vcodec^=avc1`，即选码率最高、兼容最好的那条。

| 档位 | 典型码率 | 条件 |
|---|---|---|
| 720P | 1.2–1.6 Mbps | 匿名 |
| 1080P | ~1.2 Mbps | 登录 |
| 1080P 高码率(1080P+) | 3–6 Mbps | 大会员 |
| 4K / HDR / 杜比 | 10–20 Mbps+ | 大会员 |

## 合规

- 只下载你有权访问的公开视频。
- 不绕过 DRM、付费内容、地区限制或账号权限，本技能不做此类破解。

## License

MIT
