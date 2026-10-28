import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/plugin/pl_player/index.dart';

/// 离线播放页的顶栏：返回 / 标题 / 弹幕开关
class OfflineHeader extends StatelessWidget implements PreferredSizeWidget {
  const OfflineHeader({
    super.key,
    required this.title,
    required this.controller,
  });

  final String title;
  final PlPlayerController controller;

  @override
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: kToolbarHeight,
      automaticallyImplyLeading: false,
      titleSpacing: 6,
      title: Row(
        children: <Widget>[
          ComBtn(
            icon: const Icon(
              Icons.arrow_back,
              size: 20,
              color: Colors.white,
            ),
            fuc: () {
              if (controller.isFullScreen.value) {
                controller.triggerFullScreen(status: false);
              } else {
                Get.back();
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
          Obx(
            () => ComBtn(
              icon: Icon(
                controller.isOpenDanmu.value
                    ? Icons.subtitles
                    : Icons.subtitles_off_outlined,
                size: 20,
                color: Colors.white,
              ),
              fuc: () {
                controller.isOpenDanmu.value = !controller.isOpenDanmu.value;
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
