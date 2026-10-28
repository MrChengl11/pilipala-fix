import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/download/download_task.dart';
import 'package:pilipala/pages/danmaku/index.dart';
import 'package:pilipala/pages/offline/index.dart';
import 'package:pilipala/plugin/pl_player/index.dart';
import 'package:pilipala/plugin/pl_player/utils/fullscreen.dart';

class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  late final DownloadTask _task = Get.arguments as DownloadTask;
  late final OfflineController _offlineController =
      Get.put(OfflineController(_task));

  /// 播放器区域高度：竖屏 16:9，全屏时铺满
  final RxDouble videoHeight = (Get.size.width * 9 / 16).obs;

  @override
  void dispose() {
    Get.delete<OfflineController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PlPlayerController playerCtr = _offlineController.plPlayerController;
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (videoHeight.value <= 0) {
      videoHeight.value = Get.size.width * 9 / 16;
    }

    return PopScope(
      canPop: playerCtr.isFullScreen.value != true,
      onPopInvoked: (bool didPop) {
        if (playerCtr.isFullScreen.value == true) {
          playerCtr.triggerFullScreen(status: false);
        }
        if (MediaQuery.of(context).orientation == Orientation.landscape) {
          verticalScreen();
        }
      },
      child: Obx(
        () {
          final bool fullscreen = playerCtr.isFullScreen.value;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            // 全屏时画面铺满、顶栏是白字，状态栏固定浅色图标；
            // 非全屏时跟应用主题走，避免浅色主题下状态栏图标看不见
            value: fullscreen || Get.isDarkMode
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: Scaffold(
              // 与全站一致：用主题面底色，视频区域自己保持黑
              backgroundColor: colors.surface,
              body: SafeArea(
                top: !fullscreen,
                bottom: false,
                left: false,
                right: false,
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      width: Get.size.width,
                      height: fullscreen ? Get.size.height : videoHeight.value,
                      child: _buildPlayer(playerCtr),
                    ),
                    if (!fullscreen) Expanded(child: _buildInfo(context)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayer(PlPlayerController playerCtr) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      // 视频区域保持纯黑（媒体画面观感统一）
      color: Colors.black,
      child: Obx(
        () => !_offlineController.isAvailable.value
            ? _buildError()
            : !_offlineController.isInit.value
                ? Center(
                    child: Text(
                      '加载中',
                      style: TextStyle(fontSize: 13, color: colors.outline),
                    ),
                  )
                : PLVideoPlayer(
                    controller: playerCtr,
                    headerControl: OfflineHeader(
                      title: _task.title,
                      controller: playerCtr,
                    ),
                    danmuWidget: PlDanmaku(
                      key: Key(_task.cid.toString()),
                      cid: _task.cid,
                      playerController: playerCtr,
                      offlineSegMap: _offlineController.danmakuSegMap,
                    ),
                    fullScreenCb: (bool status) {
                      videoHeight.value =
                          status ? Get.size.height : Get.size.width * 9 / 16;
                    },
                  ),
      ),
    );
  }

  Widget _buildError() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.error_outline, color: colors.outline, size: 40),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _offlineController.errMsg.value,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.outline, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 16),
      children: <Widget>[
        Text(
          _task.title,
          style: textTheme.titleSmall!.copyWith(height: 1.4),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Icon(Icons.download_done_outlined, size: 13, color: colors.outline),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '已缓存 · ' +
                    (_task.qualityDesc.isEmpty ? '未知画质' : _task.qualityDesc) +
                    (_task.audioDesc.isEmpty ? '' : ' · ' + _task.audioDesc),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.outline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Icon(Icons.subtitles_outlined, size: 13, color: colors.outline),
            const SizedBox(width: 4),
            Text(
              _offlineController.danmakuSegMap.isEmpty
                  ? '弹幕未缓存'
                  : '弹幕 ' +
                      _offlineController.danmakuSegMap.length.toString() +
                      ' 段已缓存',
              style: TextStyle(fontSize: 12, color: colors.outline),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Icon(Icons.folder_open_outlined, size: 13, color: colors.outline),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _offlineController.videoPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.outline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _offlineController.saveProgress();
                  Get.back();
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('返回列表'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                ),
                onPressed: () async {
                  final bool? delete = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext ctx) => AlertDialog(
                      title: const Text('删除离线缓存'),
                      content: const Text('删除后需要重新下载，确定继续？'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (delete == true) {
                    await _offlineController.manager
                        .removeTask(_task.cid, deleteFile: true);
                    Get.back();
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除缓存'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
