# 无损音乐 APP（FlacMusic）设计方案

> 一个不上架 App Store 的 iOS 本地原生应用，对接 flac.music.hi.cn 的多站音乐搜索接口，
> 支持 FLAC 无损试听、歌词滚动播放页、搜索下载到本地、收藏与自建歌单。

---

## 1. 技术选型

| 项 | 选择 | 理由 |
|---|---|---|
| 语言 / UI | **Swift 5.9 + SwiftUI** | 原生体验、开发量小；最低支持 iOS 16.0 |
| 播放内核 | **AVPlayer（AVFoundation）** | 系统级播放，天然支持后台播放 + 锁屏控制 |
| 数据持久化 | **Codable JSON（Documents/library.json）** | 收藏/歌单/下载索引数据量小，无需数据库；iOS 16 可用（不依赖 SwiftData） |
| 下载 | **URLSession DownloadTask（委托回调）** | 可拿到实时进度；文件落盘到 Documents/Music |
| 构建工程 | **XcodeGen（project.yml）** | 纯文本描述工程，源码可直接在任何机器上生成 .xcodeproj |
| 第三方依赖 | **0 个** | 全部系统框架，避免签名与维护负担 |

---

## 2. 信息架构（4 个 Tab + 播放页）

```
TabView
├── 🔍 搜索（默认 Tab）
│     ├── 音源切换（K 酷我 / W 网易云）
│     ├── 关键词输入 + 搜索历史
│     ├── 结果列表（封面/名称/歌手/音质角标）
│     │     └── 每行「···」菜单：收藏 · 加入歌单 · 下载(选音质) · 下载歌词
│     └── 上拉加载更多（每页 20 条）
├── ❤️ 收藏
│     └── 收藏列表（点击整单入队播放，左滑取消收藏）
├── 💾 本地
│     └── 已下载歌曲（FLAC/MP3 + 大小，可离线播放，左滑删除文件）
├── 📃 播放列表
│     ├── 新建/删除歌单
│     └── 歌单详情（播放全部、移除歌曲）
└── ▶️ 播放页（全屏 fullScreenCover，任何页面经迷你播放条进入）
      ├── 模式一：大封面 + 进度条 + 播放控制
      │     控制：随机 / 上一首 / 播放暂停 / 下一首 / 循环(关·全部·单曲)
      │     扩展：下载(选音质) · 收藏 · 加入歌单 · 当前队列
      └── 模式二：LRC 歌词逐行滚动（当前行居中高亮，点行跳播）
```

迷你播放条常驻 Tab 栏上方（封面缩略图 + 歌名 + 播放/下一首 + 细进度线）。

---

## 3. 网络协议（实测通过的接口）

统一入口 `POST https://flac.music.hi.cn/ajax.php?act=<动作>`，
`Content-Type: application/x-www-form-urlencoded`，响应统一 `{code, msg, data}`（code=0 成功）。

### 3.1 搜索 `act=search`
- 参数：`platform`（`kuwo`｜`wyy`）、`keyword`、`page`（从 1 起）、`size`（20）
- 返回 `data.list[]`：`id`（kuwo 为字符串 / wyy 为数字 → 客户端统一转 String）、
  `name`、`artist`、`album_name`、`pic_url`、`duration`（秒）、`minfo[]`（`format/bitrate/size`）、
  `time`（签名时间戳）、`sign`（请求签名）、`link`

### 3.2 取播放/下载直链 `act=getUrl`
- 参数：`platform`、`songid`、`format`（flac|mp3）、`bitrate`、`time`、`sign`（搜索结果携带）
- 返回 `data.url` = CDN 直链（如 `.../xxx.flac?...`），有效期约 1 小时 → 客户端内存缓存 1h

### 3.3 歌词 `act=getLyric`
- 参数：`platform`、`songid`、`time`、`sign`
- 返回 `data` = 标准 LRC 文本（`[mm:ss.xxx]歌词`），客户端解析后驱动滚动歌词

**客户端约束**：所有拼接 URL 仅接受 http/https，且拒绝 localhost/环回/私有/保留网段
（`URLValidator`），防 SSRF 类注入；解析地址与歌词都依赖搜索结果里的 `time+sign`，
不可自行伪造。

---

## 4. 数据模型与存储

```
Song          platform + songID(id) + name + artist + albumName + picURL
              + duration + minfo[MInfo] + link + time + sign
              id 计算属性 = "\(platform)-\(songID)"，跨平台唯一
MInfo         format / bitrate / size（下载音质候选）
Playlist      id(UUID) + name + songs[Song] + createdAt
LocalTrack    id(=Song.id) + song + fileName + format + bitrate + size
              + downloadedAt + lyricFileName
LyricLine     time(Double) + text（LRC 解析产物，多时间戳行自动展开）
```

- **library.json**（Documents 下）：`favorites[] + playlists[] + locals[] + searchHistory[]`，
  每次变更立即落盘（ISO8601 日期、UTF-8）。
- **Music/**（Documents 下）：`歌手 - 歌名 [FLAC].flac` 与同名 `.lrc` 歌词文件；
  开启了 `UIFileSharingEnabled`，用户可在「文件」App 里直接看到这些音频文件。
- 本地歌曲离线播放：PlayerManager 命中 LocalTrack 时直接用文件 URL，不请求接口。

---

## 5. 播放器架构（PlayerManager）

```
AVPlayer ── 周期时间观察(0.5s) ──▶ @Published currentTime/progress/duration
   │
   ├── play(song, in: list) → 入队 → 有本地文件? 本地URL : API解析直链
   │                          → AVPlayerItem → play + 更新锁屏信息
   ├── 队列：queue[] + repeatMode(off/all/one) + shuffleOn → next()/previous()
   ├── AVAudioSession(.playback) → 后台保活
   ├── MPNowPlayingInfoCenter → 锁屏标题/歌手/封面/进度
   ├── MPRemoteCommandCenter → 耳机线控/锁屏 播放·暂停·上下曲·拖动进度
   └── 歌词：切歌即取 LRC → LyricParser 解析 → lyrics[]；播放失败给 errorMessage
```

---

## 6. 下载流程（DownloadManager）

```
点下载选音质 → API 解析直链 → URLSessionDownloadTask(委托)
   → didWriteData → @Published active[songID] = 0~1（行内进度显示，可取消）
   → didFinishDownloadingTo → 重名自动 (2) → 移入 Music/
   → 异步取歌词写同名 .lrc → 写入 locals 索引
失败：移除进度并提示
```

---

## 7. 关键配置（Info.plist）

| Key | 值 | 作用 |
|---|---|---|
| UIBackgroundModes | audio | 后台继续播放 |
| NSAppTransportSecurity | NSAllowsArbitraryLoads | 网易云封面/部分 CDN 是 http |
| UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace | true | 「文件」App 可见下载的音频 |
| UILaunchScreen | {} | 现代启动屏 |
| CFBundleDisplayName | 无损音乐 | 桌面名称 |

---

## 8. 构建、签名与安装（不上架 App Store）

个人 Apple ID 即可真机安装（免费，7 天有效，到期用 Xcode/AltStore 重新签）：

1. **有 Mac（推荐）**：装 Xcode → `xcodegen generate`（或手动新建工程拖入源码）→
   Signing & Capabilities 选个人 Team → 插 iPhone 点 Run。
2. **没有 Mac（Windows-only）**：仓库自带 `.github/workflows/build-ios.yml`，
   GitHub Actions 的 macOS 机器自动产出**未签名 .ipa**（Actions 工件下载）；
   Windows 上用 **Sideloadly / AltServer** + 自己的 Apple ID 签名并 USB 安装到 iPhone。
3. 上架豁免：本应用纯个人使用，走免费开发者签名分发，不涉及 App Store 审核。

---

## 9. 版本规划

- v1（本次交付）：搜索/试听/歌词滚动/下载(FLAC)/收藏/本地/自建歌单/锁屏控制
- v1.1：专辑与歌单链接解析（站内 `act=album`、`act=playlist` 已预留）、播放队列拖动排序
- v1.2：均衡器、定时关闭、iCloud 同步 library.json、文件 App 导入本地音频
