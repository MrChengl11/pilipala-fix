import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/utils/feed_back.dart';
import 'package:pilipala/utils/image_save.dart';
import 'package:pilipala/utils/route_push.dart';
import 'package:pilipala/utils/url_utils.dart';
import '../../http/search.dart';
import '../../http/user.dart';
import '../../http/video.dart';
import '../../utils/utils.dart';
import '../constants.dart';
import 'badge.dart';
import 'network_img_layer.dart';
import 'stat/danmu.dart';
import 'stat/view.dart';

// 视频卡片 - 水平布局
class VideoCardH extends StatelessWidget {
  const VideoCardH({
    super.key,
    required this.videoItem,
    this.onPressedFn,
    this.source = 'normal',
    this.showOwner = true,
    this.showView = true,
    this.showDanmaku = true,
    this.showPubdate = false,
    this.showCharge = false,
  });
  // ignore: prefer_typing_uninitialized_variables
  final videoItem;
  final Function()? onPressedFn;
  // normal 推荐, later 稍后再看, search 搜索
  final String source;
  final bool showOwner;
  final bool showView;
  final bool showDanmaku;
  final bool showPubdate;
  final bool showCharge;

  @override
  Widget build(BuildContext context) {
    final int aid = videoItem.aid;
    final String bvid = videoItem.bvid;
    String type = 'video';
    try {
      type = videoItem.type;
    } catch (_) {}
    final String heroTag = Utils.makeHeroTag(aid);
    return InkWell(
      onTap: () async {
        try {
          if (type == 'ketang') {
            SmartDialog.showToast('课堂视频暂不支持播放');
            return;
          }
          if (showCharge && videoItem?.typeid == 33) {
            final String redirectUrl = await UrlUtils.parseRedirectUrl(
                '${HttpString.baseUrl}/video/$bvid/');
            final String lastPathSegment = redirectUrl.split('/').last;
            if (lastPathSegment.contains('ss')) {
              RoutePush.bangumiPush(
                  Utils.matchNum(lastPathSegment).first, null);
            }
            if (lastPathSegment.contains('ep')) {
              RoutePush.bangumiPush(
                  null, Utils.matchNum(lastPathSegment).first);
            }
            return;
          }
          final int cid =
              videoItem.cid ?? await SearchHttp.ab2c(aid: aid, bvid: bvid);
          Get.toNamed('/video?bvid=$bvid&cid=$cid',
              arguments: {'videoItem': videoItem, 'heroTag': heroTag});
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
      },
      onLongPress: () => imageSaveDialog(
        context,
        videoItem,
        SmartDialog.dismiss,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            StyleString.safeSpace, 5, StyleString.safeSpace, 5),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints boxConstraints) {
            final double coverWidth = (boxConstraints.maxWidth -
                    StyleString.cardSpace *
                        6 /
                        MediaQuery.textScalerOf(context).scale(1.0)) /
                2;
            final double coverHeight = coverWidth / StyleString.aspectRatio;
            // 高度不再写死。
            // 历史问题：以前用 height = max(封面高, 手算的文字区高)，
            // 手算「字号 × 行高系数」永远比真实渲染矮一点（字体放大到 1.3 后
            // 标题两行实测 44~48dp、发布日期 19dp、作者 19dp、统计行 22dp，
            // 合计 104~108dp，而公式只给 102.6dp），于是每张卡片底部固定
            // 溢出 2~8px；换成 TextPainter 精确测量后仍残留 2~6px
            // （主题 leading / 字体 ascent / 中英混排带来额外行高）。
            // 因此改成高度由内容自然决定：Row 的高度 = max(封面, 文字区)，
            // 文字再高也只是把卡片撑高，永远不会出现 RenderFlex overflow。
            return Container(
              constraints: const BoxConstraints(minHeight: 88),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: coverWidth,
                    height: coverHeight,
                    child: LayoutBuilder(
                      builder: (BuildContext context,
                          BoxConstraints boxConstraints) {
                        final double maxWidth = boxConstraints.maxWidth;
                        final double maxHeight = boxConstraints.maxHeight;
                        return Stack(
                          children: [
                            Hero(
                              tag: heroTag,
                              child: NetworkImgLayer(
                                src: videoItem.pic as String,
                                width: maxWidth,
                                height: maxHeight,
                              ),
                            ),
                            if (videoItem.duration != 0)
                              PBadge(
                                text: Utils.timeFormat(videoItem.duration!),
                                right: 6.0,
                                bottom: 6.0,
                                type: 'gray',
                              ),
                            if (type != 'video')
                              PBadge(
                                text: type,
                                left: 6.0,
                                bottom: 6.0,
                                type: 'primary',
                              ),
                            // if (videoItem.rcmdReason != null &&
                            //     videoItem.rcmdReason.content != '')
                            //   pBadge(videoItem.rcmdReason.content, context,
                            //       6.0, 6.0, null, null),
                            if (showCharge && videoItem?.isChargingSrc)
                              const PBadge(
                                text: '充电专属',
                                right: 6.0,
                                top: 6.0,
                                type: 'primary',
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  VideoContent(
                    videoItem: videoItem,
                    source: source,
                    showOwner: showOwner,
                    showView: showView,
                    showDanmaku: showDanmaku,
                    showPubdate: showPubdate,
                    onPressedFn: onPressedFn,
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class VideoContent extends StatelessWidget {
  // ignore: prefer_typing_uninitialized_variables
  final videoItem;
  final String source;
  final bool showOwner;
  final bool showView;
  final bool showDanmaku;
  final bool showPubdate;
  final Function()? onPressedFn;

  const VideoContent({
    super.key,
    required this.videoItem,
    this.source = 'normal',
    this.showOwner = true,
    this.showView = true,
    this.showDanmaku = true,
    this.showPubdate = false,
    this.onPressedFn,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // 行高统一收紧（height: 1.15~1.25），让 4 行内容刚好填满
          // 与封面等高的卡片；Spacer 换成固定 gap，避免大屏把内容拉散。
          // 注意不能再用 MainAxisSize.min + Flexible 标题：Column 在
          // 有界高度下会先按「尽量小」布局，Flexible 子项被压到 0，
          // 第二行标题会被硬裁掉（稍后再看/搜索结果里标题下半截消失）。
          mainAxisSize: MainAxisSize.max,
          children: [
            if (source == 'normal' || source == 'later') ...[
              // 标题最多 2 行，空间不足时省略号收尾，绝不硬裁。
              // 注意：这里不能用 FittedBox(BoxFit.scaleDown) 包 Text ——
              // FittedBox 会以「无限约束」测量子级，子级一旦是
              // SizedBox(width: double.infinity) 就抛
              // "BoxConstraints forces an infinite width"，直接让
              // 整个列表（排行榜/搜索/稍后再看）布局失败变白屏。
              // 列高已由 StyleString.horizontalContentExtent 兜底，
              // maxLines + ellipsis 足以保证不溢出。
              // 必须显式给出 lineHeight：原写法只写 height 但没指定字号时，
              // 实际行高会跟随主题 bodyMedium（M3 下 height=1.43，20/14），
              // 而 StyleString.horizontalContentExtent 是按 1.2 估算的，
              // 字体放大到 1.3 后标题两行就多出 ~8.3dp → BOTTOM OVERFLOWED
              // BY 8.4 PIXELS。这里和常量表对齐，行高固定为 1.2。
              Text(
                videoItem.title as String,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              RichText(
                maxLines: 2,
                text: TextSpan(
                  children: [
                    for (final i in videoItem.titleList) ...[
                      TextSpan(
                        text: i['text'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                          color: i['type'] == 'em'
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
            const SizedBox(height: 2),
            // if (videoItem.rcmdReason != null &&
            //     videoItem.rcmdReason.content != '')
            //   Container(
            //     padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
            //     decoration: BoxDecoration(
            //       borderRadius: BorderRadius.circular(4),
            //       border: Border.all(
            //           color: Theme.of(context).colorScheme.surfaceTint),
            //     ),
            //     child: Text(
            //       videoItem.rcmdReason.content,
            //       style: TextStyle(
            //           fontSize: 9,
            //           color: Theme.of(context).colorScheme.surfaceTint),
            //     ),
            //   ),
            // const SizedBox(height: 4),
            if (showPubdate)
              Text(
                Utils.dateFormat(videoItem.pubdate!),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            if (showOwner)
              Row(
                children: [
                  Text(
                    videoItem.owner.name as String,
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.labelMedium!.fontSize,
                      height: 1.2,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                if (showView) ...[
                  StatView(view: videoItem.stat.view as int),
                  const SizedBox(width: 8),
                ],
                if (showDanmaku)
                  StatDanMu(danmu: videoItem.stat.danmaku as int),
                const Spacer(),
                if (source == 'normal')
                  SizedBox(
                    // 从 24 收到 20，与统计文字行高对齐，省下 4dp 给标题
                    width: 20,
                    height: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        feedBack();
                        showModalBottomSheet(
                          context: context,
                          useRootNavigator: true,
                          isScrollControlled: true,
                          builder: (context) {
                            return MorePanel(videoItem: videoItem);
                          },
                        );
                      },
                      icon: Icon(
                        Icons.more_vert_outlined,
                        color: Theme.of(context).colorScheme.outline,
                        size: 14,
                      ),
                    ),
                  ),
                if (source == 'later') ...[
                  IconButton(
                    style: ButtonStyle(
                      padding: MaterialStateProperty.all(EdgeInsets.zero),
                    ),
                    onPressed: () => onPressedFn?.call(),
                    icon: Icon(
                      Icons.clear_outlined,
                      color: Theme.of(context).colorScheme.outline,
                      size: 18,
                    ),
                  )
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MorePanel extends StatelessWidget {
  final dynamic videoItem;
  const MorePanel({super.key, required this.videoItem});

  Future<dynamic> menuActionHandler(String type) async {
    switch (type) {
      case 'block':
        blockUser();
        break;
      case 'watchLater':
        var res = await UserHttp.toViewLater(bvid: videoItem.bvid as String);
        SmartDialog.showToast(res['msg']);
        Get.back();
        break;
      default:
    }
  }

  void blockUser() async {
    SmartDialog.show(
      useSystem: true,
      animationType: SmartAnimationType.centerFade_otherSlide,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text('确定拉黑:${videoItem.owner.name}(${videoItem.owner.mid})?'
              '\n\n注：被拉黑的Up可以在隐私设置-黑名单管理中解除'),
          actions: [
            TextButton(
              onPressed: () => SmartDialog.dismiss(),
              child: Text(
                '点错了',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                var res = await VideoHttp.relationMod(
                  mid: videoItem.owner.mid,
                  act: 5,
                  reSrc: 11,
                );
                SmartDialog.dismiss();
                SmartDialog.showToast(res['msg'] ?? '成功');
              },
              child: const Text('确认'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => Get.back(),
            child: Container(
              height: 35,
              padding: const EdgeInsets.only(bottom: 2),
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: const BorderRadius.all(Radius.circular(3))),
                ),
              ),
            ),
          ),
          ListTile(
            onTap: () async => await menuActionHandler('block'),
            minLeadingWidth: 0,
            leading: const Icon(Icons.block, size: 19),
            title: Text(
              '拉黑up主 「${videoItem.owner.name}」',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ListTile(
            onTap: () async => await menuActionHandler('watchLater'),
            minLeadingWidth: 0,
            leading: const Icon(Icons.watch_later_outlined, size: 19),
            title:
                Text('添加至稍后再看', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            onTap: () =>
                imageSaveDialog(context, videoItem, SmartDialog.dismiss),
            minLeadingWidth: 0,
            leading: const Icon(Icons.photo_outlined, size: 19),
            title:
                Text('查看视频封面', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

