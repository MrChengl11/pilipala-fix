import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/download/download_manager.dart';
import 'package:pilipala/models/download/download_task.dart';

class DownloadController extends GetxController {
  final DownloadManager manager = DownloadManager.instance;
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    manager.init();
  }

  List<DownloadTask> get tasks => manager.tasks;

  /// 已完成任务的总体积
  int get usedBytes {
    int total = 0;
    for (final DownloadTask task in manager.tasks) {
      if (task.isCompleted) total += task.totalBytes;
    }
    return total;
  }

  bool get hasActive =>
      manager.tasks.any((DownloadTask e) => e.status == DownloadStatus.downloading);

  void pauseAll() {
    if (manager.tasks.isEmpty) return;
    manager.pauseAll();
  }

  void resumeAll() {
    if (manager.tasks.isEmpty) return;
    manager.resumeAll();
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
