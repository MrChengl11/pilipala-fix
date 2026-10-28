import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/download/download_manager.dart';
import 'package:pilipala/models/download/download_task.dart';

/// 离线缓存列表项
class DownloadCard extends StatelessWidget {
  const DownloadCard({super.key, required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DownloadManager manager = DownloadManager.instance;
    final bool completed = task.isCompleted;
    final bool downloading = task.status == DownloadStatus.downloading;

    return InkWell(
      onTap: () {
        if (completed) {
          Get.toNamed('/offline', arguments: task);
        } else if (task.status == DownloadStatus.paused ||
            task.status == DownloadStatus.failed) {
          manager.resume(task.cid);
          SmartDialog.showToast('已加入下载队列');
        }
      },
      onLongPress: () => _showActions(context, manager),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: NetworkImgLayer(
                src: task.cover,
                width: 118,
                height: 74,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.qualityDesc.isEmpty ? '未知画质' : task.qualityDesc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.outline),
                  ),
                  const SizedBox(height: 6),
                  if (downloading || task.status == DownloadStatus.waiting)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: task.totalBytes > 0 ? task.progress : null,
                          minHeight: 4,
                          backgroundColor: colors.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          task.statusText +
                              (task.totalBytes > 0
                                  ? '  ' +
                                      DownloadTask.sizeText(task.receivedBytes) +
                                      '/' +
                                      DownloadTask.sizeText(task.totalBytes)
                                  : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: task.status == DownloadStatus.failed
                                ? colors.error
                                : colors.outline,
                          ),
                        ),
                      ),
                      _actionButton(manager, colors),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(DownloadManager manager, ColorScheme colors) {
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.waiting) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: '暂停',
        onPressed: () => manager.pause(task.cid),
        icon: const Icon(Icons.pause_circle_outline, size: 20),
      );
    }
    if (task.status == DownloadStatus.completed) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: '播放',
        onPressed: () => Get.toNamed('/offline', arguments: task),
        icon: Icon(Icons.play_circle_outline, size: 20, color: colors.primary),
      );
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: '继续',
      onPressed: () => manager.resume(task.cid),
      icon: const Icon(Icons.download_outlined, size: 20),
    );
  }

  void _showActions(BuildContext context, DownloadManager manager) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline, size: 20),
                title: const Text('删除任务', style: TextStyle(fontSize: 14)),
                onTap: () async {
                  Get.back();
                  final bool deleteFile =
                      await _askDeleteFile(context) ?? true;
                  await manager.removeTask(task.cid, deleteFile: deleteFile);
                  SmartDialog.showToast('已删除');
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_open_outlined, size: 20),
                title: const Text('文件位置', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  manager.videoPathOf(task.cid),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _askDeleteFile(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除离线缓存'),
        content: const Text('是否同时删除已下载的视频文件？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('仅删记录'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('一起删除'),
          ),
        ],
      ),
    );
  }
}
