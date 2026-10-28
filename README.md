<div align="center">
    <img width="200" height="200" src="https://github.com/guozhigq/pilipala/blob/main/assets/images/logo/logo_android.png">
</div>

<div align="center">
    <h1>PiliPala Fix</h1>
    <p>修复了若干已知 bug 的 PiliPala 二次开发版</p>
    <p>基于 <a href="https://github.com/guozhigq/pilipala">guozhigq/pilipala</a> 1.0.27.0402</p>
</div>

---

## ⚠️ 关于本项目

**这是一个二次开发（fork）项目，不是 PiliPala 官方版本。**

- 上游项目：[guozhigq/pilipala](https://github.com/guozhigq/pilipala)，作者 [@guozhigq](https://github.com/guozhigq)
- 本项目（PiliPala Fix）基于上游 **1.0.27.0402** 源码，目标是**修复上游已存在但尚未修复的 bug**，不改变原有交互设计
- 所有新增/修改代码的版权与许可沿用上游：**GPL-3.0**（见 [LICENSE](LICENSE)）
- 本项目与上游作者无关，问题请提到本仓库，不要打扰上游
- 请支持上游项目，有条件的话给上游点个 ⭐

### 与上游的关系

| 项目 | 说明 |
| --- | --- |
| 上游仓库 | [guozhigq/pilipala](https://github.com/guozhigq/pilipala) |
| 本项目基础版本 | 1.0.27.0402 |
| 改动范围 | bug 修复 + 少量防御性加固 + 补全上游未实现的「离线缓存」 |
| 签名 | 使用本项目自建签名，**与上游 APK 不兼容**，安装前需卸载旧版 |

## 📦 下载与安装

从本仓库的 **Releases** 页面下载 `pilipala-1.0.27-fix3.apk`。

**注意：本项目使用独立签名。**

- 若你已安装官方版（或 F-Droid 版），需要**先卸载再安装**，否则会报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`
- 卸载会清除本地数据（登录态、设置、观看记录缓存），需要重新登录
- 支持架构：`arm64-v8a` / `armeabi-v7a` / `x86` / `x86_64`

## ⬇️ 离线缓存（v1.0.27-fix3 新增）

上游 1.0.27.0402 的「离线缓存」只是一个灰色不可点、右侧标着「暂未支持」的假入口。本轮把它完整实现了。

**入口**

- 视频详情页 → 播放器右上「更多」→ 面板第二项「离线缓存」（副标题显示当前画质与已缓存状态）
- 媒体库 → 「离线缓存」（原假入口，现已可点）

**能力**

| 项目 | 说明 |
| --- | --- |
| 下载内容 | DASH 视频流 + 音频流（分文件）+ 弹幕卡片（Protobuf 原样存盘） |
| 断点续传 | 按 `Range` 分片请求，中断后从已下载字节继续，失败自动换备用 CDN 镜像 |
| 并发与排队 | 同时下载 2 个任务，其余排队；支持单个暂停/继续、全部暂停/继续 |
| 网络策略 | 可选「仅 Wi-Fi 下载」，非 Wi-Fi 时自动暂停并说明原因 |
| 任务持久化 | Hive `download` box 存任务表，杀进程后重启仍在 |
| 播放 | 独立离线播放页，DASH 双文件经 media_kit `audio-files` 挂音轨；弹幕走本地 Protobuf，不再联网 |
| 进度记忆 | 退出离线播放页时记住播放位置，下次从上次位置继续 |
| 清理 | 长按任务卡片或播放页「删除缓存」，可连带删除文件 |

**存储布局**（应用私有目录，无需存储权限）

```
<ApplicationSupportDirectory>/offline/<cid>/
├── video.m4s       # DASH 视频流
├── audio.m4s       # DASH 音频流
├── meta.json       # 画质/音质/时长/体积等元信息
└── danmaku/
    ├── 1.pb        # 第 1 段（0–6 分钟）弹幕 Protobuf
    └── 2.pb ...
```

> DASH 分文件而非合并 mp4：B 站 playurl 的 DASH 流本身就是 m4s 分片容器，音视频轨天然分离；media_kit 可以直接把第二个文件挂成音轨，因此不需要 ffmpeg 合流，也不需要引入新的原生依赖。

## 🐛 已修复的问题

完整清单见 [FIXES.md](FIXES.md)。以下是摘要。

### P0 · 崩溃与红屏

| # | 问题 | 根因 |
| --- | --- | --- |
| 1 | 图文（`/opus`）页面必现红屏 `type 'String' is not a subtype of type 'int?'` | `lib/models/read/opus.dart` 的 `Basic.uid` 直接接收接口返回的字符串 `"130061363"`，而字段声明为 `int?` |
| 2 | 图文页 `NoSuchMethodError` on null（作者信息缺失时） | `lib/models/read/read.dart` 无条件调用 `Author.fromJson(json['author'])`；`lib/models/member/info.dart` 的 `Vip.fromJson` 对 `nickname_color` 为 `null` 时仍调用 `replaceAll` |
| 3 | 图文页正文 `RangeError` | `lib/pages/opus/text_helper.dart` 对颜色值 `''` 执行 `substring(1, 7)` |
| 4 | **所有 cv 专栏页面**显示「专栏内容缺失」或红屏 | B 站已把 `/read/cvXXX` 迁移到 `detail.modules` 新结构，旧 `readInfo` 字段在新页面完全不存在，而解析器只读旧字段 |
| 5 | 动态页 UP 主面板报 `type 'String' is not a subtype of type 'int?'` | `lib/models/dynamics/up.dart` 多个模型直接把 `json['mid']`/`count` 赋给 `int?`，portal 接口偶发返回字符串 |
| 6 | 动态富文本 `NoSuchMethodError: The getter 'summary' was called on null` | `lib/pages/dynamics/widgets/rich_node_panel.dart` 未判空 `opus.summary` |
| 7 | 登录页关闭二维码弹窗必崩 | `lib/pages/login/view.dart` 的 `validTimer!.cancel()`，二维码接口失败时 `validTimer` 为 null |
| 8 | 视频详情页偶发「双重 dispose」崩溃 | `lib/pages/video/detail/controller.dart` 播放器可能被释放两次 |
| 9 | 选择解码格式时 `StateError` | `firstWhere` 缺 `orElse`（`header_control.dart`、`video/detail/controller.dart`） |
| 10 | 启动白屏 / 主题越界崩溃 | `lib/main.dart` 读取历史版本存入的 `customColor`/`themeMode` 时未做范围校验 |
| 11 | 首页图片位 `LateInitializationError` | `GlobalDataCache().initialize()` 在 `runApp` 之后才执行，首帧 `NetworkImgLayer` 读缓存时未初始化 |

### P1 · 功能不可用

| # | 问题 | 根因 |
| --- | --- | --- |
| 12 | **直播间弹幕完全不加载** | WBI 签名缺失 + 弹幕包头未递归解包 + `DANMU_MSG` 解析未容错；同时 socket 断开后不重连 |
| 13 | 首页/排行榜/搜索/订阅卡片文字放大后 `RenderFlex overflowed` | 卡片内容区高度写死，字体放大（设置里可调到 1.3+）后撑爆 |
| 14 | 搜索无结果时白屏 | 空结果未渲染空状态 |
| 15 | 视频操作菜单「下载封面」「复制链接」是假入口 | `lib/pages/video/detail/introduction/view.dart` 里对应项为 `null`，渲染时被跳过 |
| 16 | 一批假入口点了没反应 | 动态页话题/抽奖/商品/直播卡/文章作者、黑名单跳主页、媒体库「离线缓存」、个人页「编辑资料」等 |

### P2 · 体验缺陷

| # | 问题 |
| --- | --- |
| 17 | 未登录时专栏页提示「解析失败」而非「请先登录」——风控验证页被当作解析失败 |
| 18 | 历史记录里已看完的视频进度条显示 `10000%`（`LinearProgressIndicator` 收到 100） |
| 19 | 视频操作栏「不喜欢」是空回调的假入口，现已移除 |
| 20 | 一批 `firstWhere` 缺 `orElse`、用 `!` 强解空值导致的潜在崩溃，已补兜底 |

### P0 · 第二轮修复（v1.0.27-fix2）

| # | 问题 | 根因 |
| --- | --- | --- |
| 21 | 进入直播间/切解码格式后显示「播放失败，请返回重试」，实际播放正常 | `lib/plugin/pl_player/controller.dart` 把 `stream.error` 直接当致命错误：media_kit 会把 mpv 中所有 `level=error` 日志（含 ffmpeg/tcp 重连、直播流首次探测等可恢复告警）都从这里抛出，一旦置 `DataStatus.error` 就再没有任何地方复位 |
| 22 | 切换解码格式 AV1 报播放失败；选 DVH1 直接被打回 AVC | `lib/models/video/play/quality.dart` 的 `VideoDecodeFormatsCode.fromString` 解析失败时**默认返回 `values.first`（DVH1）**，导致 `hvc1.*` 等未知 codecs 全被当成 DVH1，选它就必然失败；`updatePlayer()` 又用 `startsWith(code)` 匹配，与 `supportFormats` 的写法不一致时对不上 |
| 23 | 部分弹幕滚动到一半消失 | 内置弹幕引擎 `Duration(seconds: widget.duration.floor())`：duration < 1s 时得 `Duration.zero`，`AnimationController.forward()` 同步完成 → `onComplete` 立刻移除；另有 id 用 `key.toString()` 在 release AOT 下 20 位截断碰撞覆盖、以及迭代中修改 Map 的 `ConcurrentModificationError` |
| 24 | 外观设置「图片质量」拖滑块无效 | `lib/pages/setting/style_setting.dart` 把临时值 `int tempQuality = picQuality` 声**在 `StatefulBuilder` 的 builder 内**，每次 rebuild 都被重置，滑块一拖就弹回 |
| 25 | 登录成功后仍滚动弹出「登录遇到问题」对话框，需重启才正常 | `lib/utils/login.dart` 直接 `Get.find<MediaController>()` / `DynamicsController` / `MineController`：这些控制器只在对应底部导航项开启时才 `Get.put`，媒体库 tab 关闭时 `find` 抛异常并被外层 `catch` 弹成「登录遇到问题」（登录其实已成功） |

修复方式分别见 [FIXES.md](FIXES.md) 第 21–25 节：播放器改为「宽限期 + 进展判定」、解码格式改为前缀归一表 + 真实选流、弹幕引擎改为本地 vendored 并修 duration/id/迭代、图片质量把临时值提到 builder 外、登录状态同步改为 `_tryFind<T>()` 容错且失败只记日志。

> 补充依赖变更：`ns_danmaku` 由 `git` 依赖改为 `path: packages/ns_danmaku`（内置已打补丁的引擎副本），因此本仓库构建**不需要**再联网拉取该 git 依赖。

## 🔧 技术说明

### 新增的通用工具

- **`lib/models/json_field.dart`** — JSON 类型归一工具，提供 `asInt` / `asStr` / `asDouble` / `asBool` / `asMap` / `asMapList`。
  上游多个模型直接把 `dynamic` 赋给强类型字段，接口字段类型漂移（数字变字符串等）就会崩。遇到新的类型崩溃，优先用它改写对应模型。
- **`lib/pages/opus/widgets/module_view.dart`** — `OpusModuleView`，把「`detail.modules` 新结构」的渲染逻辑抽出复用，`/opus`（图文）和 `/read`（cv 专栏）现在共用同一套渲染。
- **`lib/models/download/download_manager.dart`** — 离线下载管理器（单例）：任务表持久化、并发调度、Range 断点续传、弹幕拉取与落盘。播放侧只需拿到本地绝对路径，全程不联网。

### 改动统计

相对上游 1.0.27.0402：**180 个文件，+7178 / -2551 行**（截至 v1.0.27-fix3）。

## 🏗️ 构建

环境：Flutter 3.22.x + Android SDK 34 + JDK 17。

```bash
flutter pub get
flutter build apk --release
```

Release 签名需要自备，在 `android/app/` 下放 keystore 并配置 `android/key.properties`：

```properties
storeFile=your-release.jks
storePassword=******
keyAlias=your-alias
keyPassword=******
```

> keystore 必须放在 `android/app/` 目录下（`build.gradle` 里的 `file(...)` 相对 app 模块解析），放 `android/` 根目录会构建失败。

## 📄 许可证

GPL-3.0，与上游一致。见 [LICENSE](LICENSE)。

本项目包含的代码来自 [guozhigq/pilipala](https://github.com/guozhigq/pilipala)，版权归原作者所有。

## 声明

此项目仅用于学习和测试。
所用 API 皆从官方网站收集，不提供任何破解内容。

## 致谢

- [guozhigq/pilipala](https://github.com/guozhigq/pilipala) — 本项目的全部基础
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
