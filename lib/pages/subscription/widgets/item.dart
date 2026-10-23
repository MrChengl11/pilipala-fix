import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/constants.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/utils/utils.dart';

import '../../../models/user/sub_folder.dart';

class SubItem extends StatelessWidget {
  final SubFolderItemData subFolderItem;
  final bool isOwner;
  final Function(SubFolderItemData) cancelSub;
  const SubItem({
    super.key,
    required this.subFolderItem,
    required this.isOwner,
    required this.cancelSub,
  });

  @override
  Widget build(BuildContext context) {
    String heroTag = Utils.makeHeroTag(subFolderItem.id);
    return InkWell(
      onTap: () => Get.toNamed(
        '/subDetail',
        arguments: subFolderItem,
        parameters: {
          'heroTag': heroTag,
          'seasonId': subFolderItem.id.toString(),
          'type': subFolderItem.type.toString(),
        },
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        child: LayoutBuilder(
          builder: (context, boxConstraints) {
            double width =
                (boxConstraints.maxWidth - StyleString.cardSpace * 6) / 2;
            // 历史实现把整行高度写死成「封面高度」(width / aspectRatio)，
            // 但右侧文字区是 标题 + 2 行元信息 + 底部取消订阅按钮，
            // 在 360dp 屏上需要的内容高度超过封面高度，
            // 于是每一行都 RenderFlex overflow（20px，收紧行高后仍有 13px）。
            // 靠估算高度总会有偏差（标题 1 行/2 行、字体缩放都会变），
            // 所以这里不再固定行高：封面用固定宽高保持比例，
            // 行高由 Row 里较高的子项决定，让内容自然撑开。
            final double coverWidth = width;
            final double coverHeight = coverWidth / StyleString.aspectRatio;
            return Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: coverWidth,
                  height: coverHeight,
                  child: Hero(
                    tag: heroTag,
                    child: NetworkImgLayer(
                      src: subFolderItem.cover,
                      width: coverWidth,
                      height: coverHeight,
                    ),
                  ),
                ),
                Expanded(
                  child: ConstrainedBox(
                    // 文字区至少与封面等高，保证左右视觉齐平
                    constraints: BoxConstraints(minHeight: coverHeight),
                    child: VideoContent(
                      subFolderItem: subFolderItem,
                      isOwner: isOwner,
                      cancelSub: cancelSub,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class VideoContent extends StatelessWidget {
  final SubFolderItemData subFolderItem;
  final bool isOwner;
  final Function(SubFolderItemData)? cancelSub;
  const VideoContent({
    super.key,
    required this.subFolderItem,
    required this.isOwner,
    this.cancelSub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 6, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subFolderItem.title!,
              textAlign: TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '合集 UP主：${subFolderItem.upper!.name!}',
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
                height: 1.2,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${subFolderItem.mediaCount}个视频',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
                height: 1.2,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 2),
            isOwner
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        // 不限制尺寸时 IconButton 会占满 48x48 的最小点击区，
                        // 直接把这一行撑到 48dp 高。这里收成 24x24。
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        padding: EdgeInsets.zero,
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                        ),
                        onPressed: () => cancelSub?.call(subFolderItem),
                        icon: Icon(
                          Icons.clear_outlined,
                          color: Theme.of(context).colorScheme.outline,
                          size: 18,
                        ),
                      )
                    ],
                  )
                : const SizedBox()
          ],
        ),
      ),
    );
  }
}
