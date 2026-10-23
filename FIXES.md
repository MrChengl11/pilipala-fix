# 修复清单

本文件记录 PiliPala Fix 相对上游 [guozhigq/pilipala](https://github.com/guozhigq/pilipala) 1.0.27.0402 的全部改动。

统计：**158 个文件，+5014 / -2052 行**。

---

## P0 · 崩溃与红屏

### 1. 图文（/opus）页面必现红屏

**现象**：从动态页「专栏」分类点开任意图文，整页深红 + `type 'String' is not a subtype of type 'int?'`。

**根因**：B 站 `/opus` 接口的 `detail.basic.uid` 返回的是**字符串**（如 `"130061363"`），而模型把它声明为 `int?`。异常被 `lib/http/read.dart:86` 的 `catch` 吞成「专栏内容解析失败」，或直接冒泡成红屏。

**修复**：`lib/models/read/opus.dart` 全文件改用新增的 `lib/models/json_field.dart` 做类型归一（`asInt` / `asStr` / `asMap` / `asMapList`）。

---

### 2. 图文页作者信息缺失时 `NoSuchMethodError`

**根因**：
- `lib/models/read/read.dart` 无条件调用 `Author.fromJson(json['author'])`，`author` 缺失时直接抛异常
- `lib/models/member/info.dart` 的 `Vip.fromJson` 在 `nickname_color` 为 `null` 时，`null == ''` 判为 false，接着对 `null` 调 `replaceAll` → `NoSuchMethodError`

**修复**：`author` 改为先 `asMap` 判空再解析；`Vip.fromJson` 的 `nickname_color` 改为 `asStr ?? ''` 后再解析十六进制，空串返回 `null`。

---

### 3. 图文页正文 `RangeError`

**现象**：正文渲染时抛 `RangeError (start): Invalid value: Only valid value is 0: 1`。

**根因**：`lib/pages/opus/text_helper.dart:52` 执行
`int.parse(node.word!.color!.substring(1, 7), radix: 16)`，
但接口实际返回的颜色值是 `''`（空串，实测 6 个节点）和 `'var(--Ga9, #2F3238)'`（CSS 变量写法，实测 29 个节点），`substring(1,7)` 对空串直接抛 `RangeError`。

**修复**：新增 `static Color? parseHexColor(String? raw)`，处理 `#RRGGBB` / `#RGB`（展开为 6 位）/ `#AARRGGBB` / `0x` 前缀 / 无前缀，无法解析时返回 `null`，由调用方回退到主题色。同时修正 `fontWeight`：原来只判 `style.bold != null`（`bold: false` 也会加粗），改为 `style.bold == true`。

---

### 4. 所有 cv 专栏页面「内容缺失」

**现象**：`bilibili://article/cvXXXXXXX` 打开后显示「专栏内容缺失」或红屏，**全站所有 cv 文章**都这样。

**根因**：B 站已把 `/read/cvXXX` 页面迁移到 `detail.modules` 新结构（与 `/opus` 同构），旧 `readInfo` 字段在新页面**完全不存在**。实测 `cv5337643`、`cv7000000` 的 `__INITIAL_STATE__` 里 `detail` 的 key 只有 `id_str/type/basic/modules`，`modules` 有 8 个元素；而 `parseArticleCv` 只解析 `readInfo`。

**修复**：
- 新建 `lib/pages/opus/widgets/module_view.dart`（`OpusModuleView`），把 `detail.modules` 结构的渲染逻辑从 opus 页面抽出来复用
- `lib/http/read.dart` 的 `parseArticleCv` 同时尝试解析 `ReadDataModel` 和 `OpusDataModel`，任一成功即返回（返回 `{'status': true, 'data': ..., 'opus': ...}`）
- `lib/pages/read/controller.dart` 新增 `Rx<OpusDataModel> opusData`
- `lib/pages/read/view.dart` 在 `readInfo == null` 且 `opusData.detail.modules` 非空时渲染 `OpusModuleView`

---

### 5. 动态页 UP 主面板报 `type 'String' is not a subtype of type 'int?'`

**现象**：进入动态 tab，顶部 UP 主面板整块变成错误卡片。

**根因**：`lib/models/dynamics/up.dart` 中 `FollowUpModel` / `LiveUsers` / `LiveUserItem` / `UpItem` / `MyInfo` 全部直接 `json['mid']` / `json['count']` 赋给 `int?`，而 portal 接口偶发返回字符串。

**修复**：整文件重写，全部字段走 `asInt` / `asStr` / `asMap`，`up_list` / `live_users` 用 `is List` + `whereType<Map>()` 守卫；`lib/http/dynamics.dart` 的 `followUp()` 加 `try/catch`，解析失败时返回空模型而非 `status: false`（避免整个面板变错误卡片）。

---

### 6. 动态富文本 `NoSuchMethodError: The getter 'summary' was called on null`

**根因**：`lib/pages/dynamics/widgets/rich_node_panel.dart` 判断了 `major != null` 就直接访问 `major.opus.summary.richTextNodes`，未判空 `opus.summary`。

**修复**：改判 `major?.opus != null`，内部再取 `opus.summary?.richTextNodes`。

---

### 7. 登录页关闭二维码弹窗必崩

**根因**：`lib/pages/login/view.dart` 的 `dispose` 里 `validTimer!.cancel()`，而二维码接口失败时 `validTimer` 从未被赋值，为 `null`。

**修复**：改为 `validTimer?.cancel()`。

---

### 8. 视频详情页偶发「双重 dispose」

**根因**：`lib/pages/video/detail/controller.dart` 的播放器释放路径可能被触发两次。

**修复**：新增幂等的 `releasePlayer()`，`view.dart` 的 `dispose` 统一走它。同时 `lib/plugin/pl_player/controller.dart`：播放计数归零时置 `DataStatus.error` 代替永久 loading，并订阅 `player.stream.error`；`pl_player/view.dart` 错误分支提到 loading 判断之前。

---

### 9. 选择解码格式时 `StateError`

**根因**：`firstWhere` 缺 `orElse`：
- `lib/pages/video/detail/widgets/header_control.dart` 的 `videoFormat.firstWhere((e) => e.quality == firstVideo.quality!.code).codecs!`
- `lib/pages/video/detail/controller.dart` 的 `supportFormats.firstWhere((e) => e.quality == resVideoQa).codecs!`

**修复**：补 `orElse` 兜底，取第一个可用格式。

---

### 10. 启动白屏 / 主题越界

**根因**：`lib/main.dart` 直接 `colorThemeTypes[setting.get(customColor)]` 与 `ThemeType.values[setting.get(themeMode)]`，历史版本存入的值越界时抛 `RangeError`。

**修复**：加范围校验，越界回退到默认值。

---

### 11. 首页图片位 `LateInitializationError`

**根因**：`GlobalDataCache().initialize()` 在 `runApp` 之后才 `await`，而首帧就会构造 `NetworkImgLayer` 并读取 `GlobalDataCache().imgQuality`。

**修复**：把 `GlobalDataCache().initialize()` 移到 `runApp` 之前。

---

## P1 · 功能不可用

### 12. 直播间弹幕完全不加载

**现象**：进入任意直播间，弹幕列表永远空白（视频能播、人气正常）。

**根因**（三处叠加）：
1. 拉取弹幕配置时缺少 WBI 签名，接口直接拒绝
2. 弹幕 socket 的包体是**分片压缩**的，原实现只解一层，剩余数据被丢弃
3. `DANMU_MSG` 的字段结构有变化，解析未做容错，整个消息被丢弃

另外 socket 断开后不会重连。

**修复**：
- `lib/utils/wbi_sign.dart` + `lib/http/live.dart`：补齐 WBI 签名
- 按包头递归解包（brotli / zlib 分片）
- `DANMU_MSG` 解析加容错
- `lib/plugin/pl_socket/index.dart`：`onDone` / `onError` → `onClose(reconnect: true)`，`onClose` 签名改为 `void onClose({bool reconnect = false})`，非重连场景取消定时器，重连场景重新调度

---

### 13. 卡片 `RenderFlex overflowed`

**现象**：把「字体大小」调大（1.3+）后，首页 / 排行榜 / 搜索 / 订阅页的横版卡片底部溢出，debug 包显示黄黑条纹。

**根因**：`lib/common/widgets/video_card_h.dart` / `video_card_v.dart` 等内容区高度按默认字号写死，字体放大后文本行高增大撑爆容器。

**修复**：重写卡片布局约束，内容区随可用空间伸缩，避免固定高度。

---

### 14. 搜索无结果白屏

**根因**：搜索结果为空的路径没有渲染空状态。

**修复**：补空状态渲染。

---

### 15. 视频操作菜单「下载封面」「复制链接」是假入口

**根因**：`lib/pages/video/detail/introduction/view.dart` 的 `menuListWidgets` 里这两项为 `null`，渲染循环用 `menuItem!` 跳过时直接崩溃/被跳过；且「操作菜单设置」页在设置里被隐藏，无法配置。

**修复**：
- 新增 `_copyVideoLink()`：`Clipboard.setData('https://www.bilibili.com/video/$bvid')` + toast
- 新增 `_downloadCover()`：取 `videoDetail.value.pic` 去掉 `@` 后缀，调 `DownloadUtils.downloadImg`
- 渲染循环改为 `final Widget? menuItem = ...; if (menuItem != null) list.add(menuItem);`（去掉 `!`，防止老版本 hive 里残留非法枚举导致崩溃）
- `lib/models/common/action_type.dart` 删除 `actionMenuConfig` 里的 `dislike` 项（枚举保留兼容）
- `lib/pages/setting/style_setting.dart` 恢复「操作菜单设置」入口

---

### 16. 一批假入口点了没反应

| 位置 | 修复后行为 |
| --- | --- |
| 动态页话题标签 | 跳 `/searchResult`，搜 `#话题#` |
| 动态页抽奖卡 | 跳 `/webview` 打开 `h5/lottery/{rid}` |
| 动态页商品卡 | 优先用 `jump_url`，没有则降级为纯文本 |
| 动态页直播卡 | 跳 `/liveRoom?roomid=..` |
| 动态页文章 @作者 | 跳 `/member?mid=..` |
| 动态页预约卡 | `jump_url` 或按 `rid` 拼 `blackboard/activity-reserve` |
| 动态页「立即转发」 | 打开转发面板 |
| 黑名单条目 | 跳 `/member?mid=..` |
| 媒体库「离线缓存」 | 改为灰显 +「暂未支持」（原来点了弹「功能开发中」，属误导） |
| 个人页「编辑资料」 | 文案改为「暂未支持」，与其它假入口一致 |
| 登录页「中国大陆」 | 从按钮改为灰色说明文字 |
| 登录页「有效期」 | 从按钮改为普通文字 |
| 登录页「检查登录状态」 | 接上真实的 `checkLoginStatus()` |

---

## P2 · 体验缺陷

### 17. 未登录时专栏页提示「解析失败」

**根因**：未登录 / 无 buvid cookie 时，`/read/cvXXX` 返回的是约 3318 字节的**风控验证页**而不是文章页，解析器把它当「解析失败」。

**修复**：`parseArticleCv` 按响应长度区分，`html.length < 20000` 时提示「专栏加载失败，请先登录后重试」。

---

### 18. 历史记录已看完的进度条显示 `10000%`

**根因**：`lib/pages/history/widgets/item.dart` 的 `LinearProgressIndicator` 收到 `value: 100`，而该 widget 的合法域是 `0.0~1.0`，渲染出来是 10000%。

**修复**：`value: videoItem.progress == -1 ? 1.0 : (progress / duration).clamp(0.0, 1.0)`。

---

### 19. 视频操作栏「不喜欢」是假入口

**根因**：`lib/pages/video/detail/introduction/view.dart` 的 `dislike`（「不喜欢」）一项 `onTap: () {}` 为空实现，且在当前 cookie 架构下没有可用接口。

**修复**：从操作菜单移除 —— `lib/models/common/action_type.dart` 的 `actionMenuConfig` 删掉该配置项（枚举保留以防老版本 hive 反序列化失败），渲染循环同时改为判空跳过，老数据里残留的 `dislike` 不会再触发崩溃。

---

### 20. 其他防御性加固

- `lib/common/widgets/http_error.dart`：新增统一的 `HttpErrorBox`，按钮仅在回调非空时渲染（原来假入口会渲染一个点了没反应的按钮）
- `lib/models/json_field.dart`：新增 JSON 类型归一工具（见下）
- 各处 `firstWhere` 补 `orElse` 或 `try/catch`
- `lib/pages/dynamics/view.dart` 的 `_userLoginWorker` 字段类型修正

---

## 新增的通用工具

### `lib/models/json_field.dart`

上游大量模型直接把 `dynamic` 赋给强类型字段，B 站接口字段类型漂移（数字变字符串、对象变数组、字段缺失）就会崩。这个文件提供统一的归一函数：

```dart
int? asInt(dynamic v)        // "123" / 123.0 / null → 123 / 123 / null
int? asTs(dynamic v)         // 时间戳，0 或不可解析 → null
double? asDouble(dynamic v)
String? asStr(dynamic v)     // Map / Iterable → jsonEncode
bool? asBool(dynamic v)      // 支持 'true' / '1' / 'false' / '0'
Map<String, dynamic>? asMap(dynamic v)
List<Map<String, dynamic>> asMapList(dynamic v)  // 过滤非 Map 元素
```

遇到新的「类型不匹配」崩溃，优先用它改写对应模型的 `fromJson`。

### `lib/pages/opus/widgets/module_view.dart`

`OpusModuleView` 把「`detail.modules` 新结构」的渲染逻辑抽出复用，`/opus`（图文）和 `/read`（cv 专栏）共用。

---

## 已知未修

以下问题属于**功能缺失**而非 bug，本轮未处理：

| 问题 | 位置 |
| --- | --- |
| 代理开关改了不生效，也无提示 | `lib/pages/setting/extra_setting.dart` — `IOHttpClientAdapter` 只在 `Request` 单例构造时设置一次 |
| 自定义列数改了需要重启才生效 | `lib/pages/setting/style_setting.dart` — `ListTile` 类型设置项没有 `needReboot` 提示 |
| 收藏夹隐私设置不保存 | `lib/pages/fav_edit/controller.dart` — `editFolder` / `addFolder` 未传 `privacy` |
| 排行榜分区页上拉加载无新内容 | `lib/pages/rank/zone/controller.dart` — `onLoad` 是清空重来，且接口 URL 无 `pn` / `ps` 参数 |
| UP 主投稿搜索首次点搜索不发请求 | `lib/pages/member_search/controller.dart` |
| 收藏夹内搜索页进页面必显示无数据 | `lib/pages/fav_search/view.dart` — `initState` 无首次查询 |
| 动态转发后计数不 +1 | `lib/pages/dynamics/widgets/action_panel.dart` |
| 登录后番剧页「最近追番」仍隐藏 | `lib/utils/login.dart` — `refreshLoginStatus` 漏同步 `BangumiController` |
| 首页推荐流刷新会叠重复数据 | `lib/pages/rcmd/controller.dart` |
| 默认倍速本次运行不生效 | `lib/plugin/pl_player/controller.dart` — `setDataSource` 的 speed 参数未被使用 |
| 「@我的」是空壳页 | `lib/pages/message/at/view.dart` |
| 直播醒目留言（Super Chat）不显示 | `lib/pages/live_room/controller.dart:310` — `lib/utils/live.dart` 已解析出 `LiveMessageType.superChat`，但只 `where(type == chat)` 过滤 |
| 稍后再看添加后按钮无视觉反馈 | `lib/pages/video/detail/introduction/view.dart:611` — `selectStatus: false` 恒定，接口实际已调用成功 |
| 多账号切换无 UI | `lib/http/api.dart` 的 `sessionAccountList` 无入口 |
