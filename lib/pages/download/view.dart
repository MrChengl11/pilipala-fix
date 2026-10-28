import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/no_data.dart';
import 'package:pilipala/models/download/download_manager.dart';
import 'package:pilipala/models/download/download_task.dart';
import 'package:pilipala/pages/download/index.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final DownloadController _downloadController = Get.put(DownloadController());

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Obx(
          () => Text(
            _downloadController.tasks.isEmpty
                ? '离线缓存'
                : '离线缓存 (${_downloadController.tasks.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        actions: <Widget>[
          Obx(
            () => _downloadController.tasks.isEmpty
                ? const SizedBox()
                : IconButton(
                    tooltip: _downloadController.hasActive ? '全部暂停' : '全部继续',
                    onPressed: () => _downloadController.hasActive
                        ? _downloadController.pauseAll()
                        : _downloadController.resumeAll(),
                    icon: Icon(
                      _downloadController.hasActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 21,
                      color: colors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(
        () {
          final List<DownloadTask> tasks = _downloadController.tasks;
          if (tasks.isEmpty) {
            // NoData 本身是 SliverToBoxAdapter，必须放在 CustomScrollView 里
            return const CustomScrollView(
              slivers: <Widget>[NoData()],
            );
          }
          return CustomScrollView(
            controller: _downloadController.scrollController,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 15, top: 10, bottom: 6),
                  child: Text(
                    '已占用 ${DownloadTask.sizeText(_downloadController.usedBytes)}'
                    ' · ${DownloadManager.instance.rootPath}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.outline),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    return DownloadCard(
                      key: ValueKey<int>(tasks[index].cid),
                      task: tasks[index],
                    );
                  },
                  childCount: tasks.length,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 16,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
