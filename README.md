# 无损音乐（FlacMusic）— iOS 原生音乐 APP

一个**不上架 App Store** 的 iOS 本地原生应用（SwiftUI），对接 flac.music.hi.cn 的多站音乐搜索接口：

- 🔍 **搜索**：酷我 / 网易云双音源，试听与无损下载
- ▶️ **播放页**：大封面 / LRC 歌词逐行滚动（当前行居中高亮、点行跳播）双模式，支持拖动进度、随机、列表循环、单曲循环
- 💾 **下载到本地**：自选音质（FLAC 无损 / 320K / 128K），实时进度、可取消，下载完自动保存同名 `.lrc` 歌词；本地歌曲可离线播放，文件在 iOS「文件」App 可见
- ❤️ **收藏**：一键收藏、播放全部
- 📃 **播放列表**：自建歌单、加入歌单、播放队列管理
- 🔒 **锁屏/后台**：后台连续播放，锁屏与耳机线控（播放/暂停/上下曲/拖进度）、锁屏封面与进度

详细设计见 [DESIGN.md](DESIGN.md)（信息架构、接口协议、数据模型、存储设计）。

---

## 目录结构

```
FlacMusic/
├── project.yml                  # XcodeGen 工程描述
├── .github/workflows/build-ios.yml   # 无 Mac 时云端出包（未签名 ipa）
└── FlacMusic/                   # 源码目标
    ├── Info.plist               # 后台播放 / ATS / 文件共享配置
    ├── App/                     # 入口 + 根视图（TabBar / 迷你播放条）
    ├── Models/                  # Song / MInfo / Playlist / LocalTrack
    ├── Networking/              # MusicAPI（search / getUrl / getLyric）
    ├── Services/                # PlayerManager / DownloadManager / LibraryStore / LyricParser
    └── Views/                   # 四大页面 + 播放页 + 歌词 + 弹层 + 公共组件
```

零第三方依赖，仅系统框架。

---

## 方式一：有 Mac（推荐，10 分钟出包）

1. 安装 [Xcode](https://apps.apple.com/app/xcode/id497799835)（App Store）。
2. 终端进入本目录，生成工程（推荐）：
   ```bash
   brew install xcodegen
   xcodegen generate        # 生成 FlacMusic.xcodeproj
   open FlacMusic.xcodeproj
   ```
   > 不想装 XcodeGen 也可以：Xcode 里 File → New → Project → iOS App（Interface 选 SwiftUI），
   > 建好后删掉模板 ContentView.swift，把 `FlacMusic/FlacMusic` 文件夹整个拖进工程即可（勾选 Copy items）。
3. Xcode 左上角选中 FlacMusic target → **Signing & Capabilities** → 勾选 *Automatically manage signing*，
   Team 选你登录的**个人 Apple ID**（None 时点 Add Account 用自己的 Apple ID 登录即可，免费）。
4. iPhone 用数据线连 Mac（手机上信任电脑），Xcode 顶部设备选你的 iPhone，点 ▶️ Run。
5. 首次安装手机会提示不受信任：设置 → 通用 → VPN与设备管理 → 信任你的开发者证书。

**免费签名限制**（个人 Apple ID）：签名 7 天有效，到期重新 Run 一次即可；最多同时 3 个应用。
若用 99 美元/年的开发者账号，签名 1 年有效。

---

## 方式二：没有 Mac（纯 Windows 也能装到 iPhone）

原理：GitHub Actions 的 macOS 云机器帮你编译出**未签名 ipa**，Windows 上用 Sideloadly 用自己的 Apple ID 签名并安装。

1. 把本目录推到你的 GitHub 仓库（包含 `.github/workflows/build-ios.yml`）。
2. 仓库页 → **Actions** → 左侧 *Build iOS (unsigned ipa)* → **Run workflow** → 等待完成。
3. 在该次运行页面的 **Artifacts** 下载 `FlacMusic-unsigned-ipa`，解压得到 `FlacMusic-unsigned.ipa`。
4. Windows 上安装 [Sideloadly](https://sideloadly.io/)（需先装 iTunes 与 iCloud 官网版），插上 iPhone：
   - 拖入 ipa → 输入你的 Apple ID → Start；
   - 完成后在手机上同样去 *VPN与设备管理* 信任证书。
5. 也可用 [AltStore](https://altstore.io/) / SideStore 替代 Sideloadly（它会在同一 Wi-Fi 下自动续签，免 7 天手动重签）。

---

## 常见问题

- **提示"未受信任的企业级开发者/无法验证"**：设置 → 通用 → VPN与设备管理 → 信任对应证书。
- **后台播放被停**：确认 Info.plist 保留 `UIBackgroundModes: audio`（本工程已配好），且锁屏前正在播放。
- **搜不到歌 / 播放失败**：站点接口若变化，改 `FlacMusic/Networking/MusicAPI.swift` 顶部的 `baseURLString`；
  播放地址 1 小时缓存过期会自动重新解析。
- **封面不显示**：网易云封面是 http，工程已放开 ATS（个人使用无碍）。
- **下载的歌在哪**：App 内「本地」Tab，或系统「文件」App → 我的 iPhone → FlacMusic → Music。

---

## 接口协议速查（实测 2026-10 可用）

`POST https://flac.music.hi.cn/ajax.php?act=<act>`，表单编码，响应 `{code:0, msg, data}`：

| act | 参数 | 返回 |
|---|---|---|
| search | platform=kuwo\|wyy, keyword, page, size | data.list[]（id/name/artist/album_name/pic_url/duration/minfo[]/time/sign）+ total |
| getUrl | platform, songid, format, bitrate, time, sign | data.url（CDN 直链，约 1h 有效） |
| getLyric | platform, songid, time, sign | data = LRC 文本 |

`time + sign` 必须使用搜索结果携带的原值（站点签名），不可自行构造。
