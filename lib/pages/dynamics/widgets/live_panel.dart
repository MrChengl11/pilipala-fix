import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/live/item.dart';
import 'package:pilipala/utils/utils.dart';

import 'rich_node_panel.dart';

Widget livePanel(item, context, {floor = 1}) {
  dynamic content = item.modules.moduleDynamic.major;
  TextStyle authorStyle =
      TextStyle(color: Theme.of(context).colorScheme.primary);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (floor == 2) ...[
        Row(
          children: [
            GestureDetector(
              onTap: () => Get.toNamed(
                  '/member?mid=${item.modules.moduleAuthor.mid}',
                  arguments: {'face': item.modules.moduleAuthor.face}),
              child: Text(
                '@${item.modules.moduleAuthor.name}',
                style: authorStyle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              Utils.dateFormat(item.modules.moduleAuthor.pubTs),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: Theme.of(context).textTheme.labelSmall!.fontSize),
            ),
          ],
        ),
      ],
      const SizedBox(height: 4),
      if (item.modules.moduleDynamic.topic != null) ...[
        Padding(
          padding: floor == 2
              ? EdgeInsets.zero
              : const EdgeInsets.only(left: 12, right: 12),
          child: GestureDetector(
            onTap: () {
              final String topic = (item.modules.moduleDynamic.topic.name ?? '')
                  .toString()
                  .replaceAll('#', '')
                  .trim();
              if (topic.isEmpty) return;
              Get.toNamed('/searchResult', parameters: {'keyword': topic});
            },
            child: Text(
              '#${item.modules.moduleDynamic.topic.name}',
              style: authorStyle,
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
      if (floor == 2 && item.modules.moduleDynamic.desc != null) ...[
        Text.rich(richNode(item, context)),
        const SizedBox(height: 6),
      ],
      GestureDetector(
        // DYNAMIC_TYPE_LIVE：直接进直播间，roomId 取自 major.live.id
        onTap: () {
          final dynamic live = content.live;
          final int? roomId = live?.id;
          if (roomId == null) return;
          final LiveItemModel liveItem = LiveItemModel.fromJson({
            'title': live.title,
            'uname': item.modules.moduleAuthor.name,
            'cover': live.cover,
            'mid': item.modules.moduleAuthor.mid,
            'face': item.modules.moduleAuthor.face,
            'roomid': roomId,
          });
          Get.toNamed(
            '/liveRoom?roomid=$roomId',
            arguments: {
              'liveItem': liveItem,
              'heroTag': roomId.toString(),
            },
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkImgLayer(
              width: 120,
              height: 75,
              src: content.live.cover,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    content.live.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.live.descFirst,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize:
                          Theme.of(context).textTheme.labelMedium!.fontSize,
                    ),
                  )
                ],
              ),
            ),
            Text(
              content.live.badge['text'],
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
              ),
            )
          ],
        ),
      ),
    ],
  );
}
