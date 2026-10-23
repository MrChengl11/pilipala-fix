import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/http/search.dart';

/// 转折发动态里的附加卡片（UGC/预约/商品/比赛/游戏）
/// - UGC：跳投稿视频
/// - 预约：跳预约活动页（优先 reserve.jump_url，缺失则用 rid 拼活动页）
/// - 商品/比赛/游戏/投票：接口字段尚不稳定，暂不渲染（返回 SizedBox，不保留假入口）
Widget addWidget(item, context, type, {floor = 1}) {
  Map<dynamic, dynamic> dynamicProperty = {
    'ADDITIONAL_TYPE_UGC': item.modules.moduleDynamic.additional.ugc,
    // 直播预约
    'ADDITIONAL_TYPE_RESERVE': item.modules.moduleDynamic.additional.reserve,
    // 商品
    'ADDITIONAL_TYPE_GOODS': item.modules.moduleDynamic.additional.goods,
    // 比赛信息
    'ADDITIONAL_TYPE_MATCH': item.modules.moduleDynamic.additional.match,
    // 游戏信息
    'ADDITIONAL_TYPE_COMMON': item.modules.moduleDynamic.additional.common,
  };
  Color bgColor = floor == 1
      ? Theme.of(context).dividerColor.withOpacity(0.08)
      : Theme.of(context).colorScheme.surface;
  switch (type) {
    case 'ADDITIONAL_TYPE_UGC':
      // 转发的投稿
      return InkWell(
        onTap: () async {
          String text = dynamicProperty[type].jumpUrl;
          RegExp bvRegex = RegExp(r'BV[0-9A-Za-z]{10}', caseSensitive: false);
          Iterable<Match> matches = bvRegex.allMatches(text);
          if (matches.isNotEmpty) {
            Match match = matches.first;
            String bvid = match.group(0)!;
            String cover = dynamicProperty[type].cover;
            try {
              int cid = await SearchHttp.ab2c(bvid: bvid);
              Get.toNamed('/video?bvid=$bvid&cid=$cid',
                  arguments: {'pic': cover, 'heroTag': bvid});
            } catch (err) {
              SmartDialog.showToast(err.toString());
            }
          } else {
            print("No match found.");
          }
        },
        child: Container(
          padding:
              const EdgeInsets.only(left: 12, top: 8, right: 12, bottom: 8),
          color: bgColor,
          child: Row(
            children: [
              NetworkImgLayer(
                width: 120,
                height: 75,
                src: dynamicProperty[type].cover,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      dynamicProperty[type].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dynamicProperty[type].descSecond,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize:
                            Theme.of(context).textTheme.labelMedium!.fontSize,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    case 'ADDITIONAL_TYPE_RESERVE':
      {
        // additional.reserve 可能整体为空，先取出来判空，避免对 null 取 .state 崩
        final dynamic reserveItem = dynamicProperty[type];
        if (reserveItem == null) return const SizedBox();
        return dynamicProperty[type].state != -1
            ? dynamicProperty[type].title != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      // 预约卡：优先用接口给的 jump_url，缺失时用 rid 拼预约活动页
                      onTap: () {
                        final String reserveJumpUrl =
                            (reserveItem.jumpUrl ?? '').toString().trim();
                        final String reserveUrl = reserveJumpUrl.isNotEmpty
                            ? reserveJumpUrl
                            : reserveItem.rid != null
                                ? 'https://www.bilibili.com/blackboard/activity-reserve.html?oid=${reserveItem.rid}&type=2'
                                : '';
                        if (reserveUrl.isEmpty) return;
                        Get.toNamed(
                          '/webview',
                          parameters: {
                            'url': reserveUrl,
                            'type': 'url',
                            'pageTitle': '预约'
                          },
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(
                            left: 12, top: 10, right: 12, bottom: 10),
                        color: bgColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dynamicProperty[type].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                    fontSize: Theme.of(context)
                                        .textTheme
                                        .labelMedium!
                                        .fontSize),
                                children: [
                                  if (dynamicProperty[type].desc1 != null)
                                    TextSpan(
                                        text: dynamicProperty[type]
                                            .desc1['text']),
                                  const TextSpan(text: '  '),
                                  if (dynamicProperty[type].desc2 != null)
                                    TextSpan(
                                        text: dynamicProperty[type]
                                            .desc2['text']),
                                ],
                              ),
                            )
                          ],
                        ),
                        // TextButton(onPressed: () {}, child: Text('123'))
                      ),
                    ),
                  )
                : const SizedBox()
            : const SizedBox();
      }
    case 'ADDITIONAL_TYPE_GOODS':
      // 商品
      return const SizedBox();
    // return Padding(
    //     padding: const EdgeInsets.only(top: 6),
    //     child: InkWell(
    //       onTap: () {},
    //       child: Container(
    //         padding:
    //             const EdgeInsets.only(left: 12, top: 8, right: 12, bottom: 8),
    //         decoration: BoxDecoration(
    //           color: bgColor,
    //           borderRadius: const BorderRadius.all(Radius.circular(6)),
    //         ),
    //         child: Row(
    //           children: [
    //             NetworkImgLayer(
    //               width: 75,
    //               height: 75,
    //               src: dynamicProperty[type].items.first.cover,
    //             ),
    //             const SizedBox(width: 10),
    //             Expanded(
    //               child: Column(
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 mainAxisAlignment: MainAxisAlignment.start,
    //                 children: [
    //                   Text(
    //                     dynamicProperty[type].items.first.name,
    //                     maxLines: 1,
    //                     overflow: TextOverflow.ellipsis,
    //                   ),
    //                   Text(
    //                     dynamicProperty[type].items.first.brief,
    //                     maxLines: 1,
    //                     style: TextStyle(
    //                       color: Theme.of(context).colorScheme.outline,
    //                       fontSize: Theme.of(context)
    //                           .textTheme
    //                           .labelMedium!
    //                           .fontSize,
    //                     ),
    //                   ),
    //                   const SizedBox(height: 2),
    //                   Text(
    //                     dynamicProperty[type].items.first.price,
    //                     style: TextStyle(
    //                       color: Theme.of(context).colorScheme.primary,
    //                     ),
    //                   ),
    //                 ],
    //               ),
    //             ),
    //           ],
    //         ),
    //       ),
    //     ),);
    case 'ADDITIONAL_TYPE_MATCH':
      return const SizedBox();
    case 'ADDITIONAL_TYPE_COMMON':
      return const SizedBox();
    case 'ADDITIONAL_TYPE_VOTE':
      return const SizedBox();
    default:
      // 原来是调试用的 const Text('11')，会在动态卡片上渲染出裸字符串
      return const SizedBox.shrink();
  }
}
