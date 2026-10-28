import 'dart:io';

import 'package:get/get.dart';
import 'package:pilipala/models/danmaku/dm.pb.dart';
import 'package:pilipala/models/download/download_manager.dart';
import 'package:pilipala/models/download/download_task.dart';
import 'package:pilipala/plugin/pl_player/index.dart';

class OfflineController extends GetxController {
  OfflineController(this.task);

  final DownloadTask task;
  final DownloadManager manager = DownloadManager.instance;
  final PlPlayerController plPlayerController = PlPlayerController();

  final RxBool isInit = false.obs;
  final RxBool isAvailable = true.obs;
  final RxString errMsg = ''.obs;
  Map<int, List<DanmakuElem>> danmakuSegMap = <int, List<DanmakuElem>>{};

  String get videoPath => manager.videoPathOf(task.cid);
  String get audioPath => manager.audioPathOf(task.cid);

  @override
  void onInit() {
    super.onInit();
    initPlayer();
  }

  Future<void> initPlayer() async {
    final File videoFile = File(videoPath);
    final File audioFile = File(audioPath);
    if (!videoFile.existsSync() || videoFile.lengthSync() < 1024) {
      isAvailable.value = false;
      errMsg.value = '视频文件不存在或已损坏，请重新下载';
      return;
    }
    danmakuSegMap = manager.loadDanmaku(task.cid);
    final bool hasAudio = audioFile.existsSync() && audioFile.lengthSync() > 1024;
    try {
      await plPlayerController.setDataSource(
        DataSource(
          file: videoFile,
          videoSource: videoPath,
          audioSource: hasAudio ? audioPath : null,
          type: DataSourceType.file,
          httpHeaders: null,
        ),
        autoplay: true,
        enableHA: true,
        seekTo: Duration(milliseconds: task.lastPosition),
        duration: task.duration > 0
            ? Duration(milliseconds: task.duration)
            : null,
        direction: 'horizontal',
        bvid: task.bvid,
        cid: task.cid,
        // 离线不再打心跳上报
        enableHeart: false,
        isFirstTime: true,
      );
      isInit.value = true;
    } catch (e) {
      isAvailable.value = false;
      errMsg.value = '播放失败：' + e.toString();
    }
  }

  /// 记录播放进度，下次进入时续播
  void saveProgress() {
    final Duration position = plPlayerController.position.value;
    if (position.inMilliseconds > 0) {
      manager.savePlayPosition(task.cid, position.inMilliseconds);
    }
  }

  @override
  void onClose() {
    saveProgress();
    plPlayerController.dispose();
    super.onClose();
  }
}
