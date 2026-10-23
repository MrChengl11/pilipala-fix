import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pilipala/common/constants.dart';
import 'package:pilipala/common/widgets/stat/danmu.dart';
import 'package:pilipala/common/widgets/stat/view.dart';
import 'package:pilipala/http/search.dart';
import 'package:pilipala/models/common/search_type.dart';
import 'package:pilipala/utils/image_save.dart';
import 'package:pilipala/utils/utils.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import '../../../common/widgets/badge.dart';
import '../../../models/user/sub_detail.dart';

// 收藏视频卡片 - 水平布局
class SubVideoCardH extends StatelessWidget {
  final SubDetailMediaItem videoItem;
  final int? searchType;

  const SubVideoCardH({
    Key? key,
    required this.videoItem,
    this.searchType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int id = videoItem.id!;
    String bvid = videoItem.bvid!;
    String heroTag = Utils.makeHeroTag(id);
    return InkWell(
      onTap: () async {
        int cid = await SearchHttp.ab2c(bvid: bvid);
        Map<String, String> parameters = {
          'bvid': bvid,
          'cid': cid.toString(),
        };

        Get.toNamed('/video', parameters: parameters, arguments: {
          'videoItem': videoItem,
          'heroTag': heroTag,
          'videoType': SearchType.video,
        });
      },
      onLongPress: () => imageSaveDialog(
        context,
        videoItem,
        SmartDialog.dismiss,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                StyleString.safeSpace, 5, StyleString.safeSpace, 5),
            child: LayoutBuilder(
              builder: (context, boxConstraints) {
                double width =
                    (boxConstraints.maxWidth - StyleString.cardSpace * 6) / 2;
                // 高度不再写死为「封面高」。卡片右侧文字区是 4~5 行
                // （标题 + [ogv 简介] + 收藏日期 + 作者 + 统计行），字体放大
                // 到 1.3 或存在 ogv 简介行时内容比封面高，固定高就会
                // RenderFlex overflow（实测 4/8/10 px）。
                // 改为最小高度 = 封面高，实际高度由内容撑开。
                return Container(
                  constraints: BoxConstraints(
                    minHeight: width / StyleString.aspectRatio,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: width,
                        height: width / StyleString.aspectRatio,
                        child: LayoutBuilder(
                          builder: (context, boxConstraints) {
                            double maxWidth = boxConstraints.maxWidth;
                            double maxHeight = boxConstraints.maxHeight;
                            return Stack(
                              children: [
                                Hero(
                                  tag: heroTag,
                                  child: NetworkImgLayer(
                                    src: videoItem.cover,
                                    width: maxWidth,
                                    height: maxHeight,
                                  ),
                                ),
                                PBadge(
                                  text: Utils.timeFormat(videoItem.duration!),
                                  right: 6.0,
                                  bottom: 6.0,
                                  type: 'gray',
                                ),
                                // if (videoItem.ogv != null) ...[
                                //   PBadge(
                                //     text: videoItem.ogv['type_name'],
                                //     top: 6.0,
                                //     right: 6.0,
                                //     bottom: null,
                                //     left: null,
                                //   ),
                                // ],
                              ],
                            );
                          },
                        ),
                      ),
                      VideoContent(
                        videoItem: videoItem,
                        searchType: searchType,
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VideoContent extends StatelessWidget {
  final dynamic videoItem;
  final int? searchType;
  const VideoContent({
    super.key,
    required this.videoItem,
    this.searchType,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 6, 0),
        child: Stack(
          children: [
            // 卡片高度改为由内容撑开（见上方 Container 注释）后，
            // Column 处于「高度无界」的约束下，不能再用 Spacer
            // （会抛 "RenderFlex children have non-zero flex but incoming
            // height constraints are unbounded"），也不能用 MainAxisSize.max。
            // 改为 min：内容按顺序紧排，卡片高度 = max(封面高, 内容高)。
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  videoItem.title,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  Utils.dateFormat(videoItem.pubtime),
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      StatView(view: videoItem.cntInfo['play']),
                      const SizedBox(width: 8),
                      StatDanMu(danmu: videoItem.cntInfo['danmaku']),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
