// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/http/dynamics.dart';
import 'package:pilipala/http/search.dart';
import 'package:pilipala/models/common/dynamics_type.dart';
import 'package:pilipala/models/dynamics/result.dart';
import 'package:pilipala/models/dynamics/up.dart';
import 'package:pilipala/models/live/item.dart';
import 'package:pilipala/utils/feed_back.dart';
import 'package:pilipala/utils/id_utils.dart';
import 'package:pilipala/utils/route_push.dart';
import 'package:pilipala/utils/storage.dart';

class DynamicsController extends GetxController {
  int page = 1;
  String? offset = '';
  RxList<DynamicItemModel> dynamicsList = <DynamicItemModel>[].obs;
  Rx<DynamicsType> dynamicsType = DynamicsType.values[0].obs;
  RxString dynamicsTypeLabel = '全部'.obs;
  final ScrollController scrollController = ScrollController();
  Rx<FollowUpModel> upData = FollowUpModel().obs;
  // 默认获取全部动态
  RxInt mid = (-1).obs;
  Rx<UpItem> upInfo = UpItem().obs;
  List filterTypeList = [
    {
      'label': DynamicsType.all.labels,
      'value': DynamicsType.all,
      'enabled': true
    },
    {
      'label': DynamicsType.video.labels,
      'value': DynamicsType.video,
      'enabled': true
    },
    {
      'label': DynamicsType.pgc.labels,
      'value': DynamicsType.pgc,
      'enabled': true
    },
    {
      'label': DynamicsType.article.labels,
      'value': DynamicsType.article,
      'enabled': true
    },
  ];
  bool flag = false;
  RxInt initialValue = 0.obs;
  Box userInfoCache = GStrorage.userInfo;
  RxBool userLogin = false.obs;
  var userInfo;
  RxBool isLoadingDynamic = false.obs;
  Box setting = GStrorage.setting;

  @override
  void onInit() {
    userInfo = userInfoCache.get('userInfoCache');
    userLogin.value = userInfo != null;
    super.onInit();
    initialValue.value =
        setting.get(SettingBoxKey.defaultDynamicType, defaultValue: 0);
    dynamicsType = DynamicsType.values[initialValue.value].obs;
  }

  Future queryFollowDynamic({type = 'init'}) async {
    if (!userLogin.value) {
      return {'status': false, 'msg': '账号未登录', 'code': -101};
    }
    if (type == 'init') {
      dynamicsList.clear();
    }
    // 下拉刷新数据渲染时会触发onLoad
    if (type == 'onLoad' && page == 1) {
      return;
    }
    isLoadingDynamic.value = true;
    var res = await DynamicsHttp.followDynamic(
      page: type == 'init' ? 1 : page,
      type: dynamicsType.value.values,
      offset: offset,
      mid: mid.value,
    );
    isLoadingDynamic.value = false;
    if (res['status']) {
      if (type == 'onLoad' && res['data'].items.isEmpty) {
        SmartDialog.showToast('没有更多了');
        return;
      }
      if (type == 'init') {
        dynamicsList.value = res['data'].items;
      } else {
        dynamicsList.addAll(res['data'].items);
      }
      offset = res['data'].offset;
      page++;
    }
    return res;
  }

  onSelectType(value) async {
    dynamicsType.value = filterTypeList[value]['value'];
    dynamicsList.value = <DynamicItemModel>[];
    page = 1;
    initialValue.value = value;
    await queryFollowDynamic();
    scrollController.jumpTo(0);
  }

  pushDetail(item, floor, {action = 'all'}) async {
    feedBack();

    /// 点击评论action 直接查看评论
    if (action == 'comment') {
      Get.toNamed('/dynamicDetail',
          arguments: {'item': item, 'floor': floor, 'action': action});
      return false;
    }
    switch (item!.type) {
      /// 转发的动态
      case 'DYNAMIC_TYPE_FORWARD':
        Get.toNamed('/dynamicDetail',
            arguments: {'item': item, 'floor': floor});
        break;

      /// 图文动态查看
      case 'DYNAMIC_TYPE_DRAW':
        Get.toNamed('/dynamicDetail',
            arguments: {'item': item, 'floor': floor});
        break;
      case 'DYNAMIC_TYPE_AV':
        String bvid = item.modules.moduleDynamic.major.archive.bvid;
        String cover = item.modules.moduleDynamic.major.archive.cover;
        try {
          int cid = await SearchHttp.ab2c(bvid: bvid);
          Get.toNamed('/video?bvid=$bvid&cid=$cid',
              arguments: {'pic': cover, 'heroTag': bvid});
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;

      /// 专栏文章查看
      case 'DYNAMIC_TYPE_ARTICLE':
        String title = item.modules.moduleDynamic.major.opus.title;
        String jumpUrl = item.modules.moduleDynamic.major.opus.jumpUrl;
        String url =
            jumpUrl.startsWith('//') ? jumpUrl.split('//').last : jumpUrl;
        if (jumpUrl.contains('opus') || jumpUrl.contains('read')) {
          RegExp digitRegExp = RegExp(r'\d+');
          Iterable<Match> matches = digitRegExp.allMatches(jumpUrl);
          String number = matches.first.group(0)!;
          if (jumpUrl.contains('read')) {
            Get.toNamed('/read', parameters: {
              'title': title,
              'id': number,
              'articleType': url.split('/')[1]
            });
          } else {
            Get.toNamed('/opus', parameters: {
              'title': title,
              'id': number,
              'articleType': 'opus'
            });
          }
        } else {
          Get.toNamed(
            '/webview',
            parameters: {
              'url': 'https:$url',
              'type': 'note',
              'pageTitle': title
            },
          );
        }

        break;
      case 'DYNAMIC_TYPE_PGC':
      /// 番剧查看（PGC 与 PGC_UNION 的卡片结构一致，major.pgc 里带 epid）
      case 'DYNAMIC_TYPE_PGC_UNION':
        final DynamicArchiveModel? pgc =
            item.modules.moduleDynamic.major.pgc;
        if (pgc?.epid != null) {
          RoutePush.bangumiPush(null, pgc!.epid);
        } else if (pgc?.seasonId != null) {
          RoutePush.bangumiPush(pgc!.seasonId, null);
        } else {
          SmartDialog.showToast('番剧信息缺失，无法打开');
        }
        break;

      /// 纯文字动态查看
      case 'DYNAMIC_TYPE_WORD':
        print('纯文本');
        Get.toNamed('/dynamicDetail',
            arguments: {'item': item, 'floor': floor});
        break;
      case 'DYNAMIC_TYPE_LIVE_RCMD':
        DynamicLiveModel liveRcmd = item.modules.moduleDynamic.major.liveRcmd;
        ModuleAuthorModel author = item.modules.moduleAuthor;
        LiveItemModel liveItem = LiveItemModel.fromJson({
          'title': liveRcmd.title,
          'uname': author.name,
          'cover': liveRcmd.cover,
          'mid': author.mid,
          'face': author.face,
          'roomid': liveRcmd.roomId,
          'watched_show': liveRcmd.watchedShow,
        });
        Get.toNamed('/liveRoom?roomid=${liveItem.roomId}', arguments: {
          'liveItem': liveItem,
          'heroTag': liveItem.roomId.toString()
        });
        break;

      /// 合集查看
      case 'DYNAMIC_TYPE_UGC_SEASON':
        DynamicArchiveModel? ugcSeason =
            item.modules.moduleDynamic.major.ugcSeason;
        // 合集卡有时只有 bvid、有时只有 aid，原来 aid! 强解会崩
        final int? seasonAid = ugcSeason?.aid;
        final String? seasonBvid =
            (ugcSeason?.bvid?.isNotEmpty ?? false) ? ugcSeason!.bvid : null;
        final String? resolvedBvid =
            seasonBvid ?? (seasonAid != null ? IdUtils.av2bv(seasonAid) : null);
        if (resolvedBvid == null) {
          SmartDialog.showToast('合集信息缺失，无法打开');
          break;
        }
        final String cover = ugcSeason?.cover ?? '';
        try {
          final int cid = await SearchHttp.ab2c(bvid: resolvedBvid);
          Get.toNamed('/video?bvid=$resolvedBvid&cid=$cid',
              arguments: {'pic': cover, 'heroTag': resolvedBvid});
        } catch (err) {
          SmartDialog.showToast('合集视频获取失败');
        }
        break;

      default:
        // 兜底：未识别的动态类型至少让用户看到原始详情，而不是点了没反应
        Get.toNamed('/dynamicDetail',
            arguments: {'item': item, 'floor': floor});
        break;
    }
  }

  Future queryFollowUp({type = 'init'}) async {
    if (!userLogin.value) {
      return {'status': false, 'msg': '账号未登录', 'code': -101};
    }
    if (type == 'init') {
      upData.value.upList = <UpItem>[];
      upData.value.liveList = <LiveUserItem>[];
    }
    var res = await DynamicsHttp.followUp();
    if (res['status']) {
      upData.value = res['data'];
      if (upData.value.upList!.isEmpty) {
        mid.value = -1;
      }
      upData.value.upList!.insertAll(0, [
        UpItem(face: '', uname: '全部动态', mid: -1),
        UpItem(face: userInfo.face, uname: '我', mid: userInfo.mid),
      ]);
    }
    return res;
  }

  onSelectUp(mid) async {
    dynamicsType.value = DynamicsType.values[0];
    dynamicsList.value = <DynamicItemModel>[];
    page = 1;
    queryFollowDynamic();
  }

  onRefresh() async {
    page = 1;
    await queryFollowUp();
    await queryFollowDynamic();
  }

  // 返回顶部并刷新
  void animateToTop() async {
    if (scrollController.offset >=
        MediaQuery.of(Get.context!).size.height * 5) {
      scrollController.jumpTo(0);
    } else {
      await scrollController.animateTo(0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  // 重置搜索
  void resetSearch() {
    mid.value = -1;
    dynamicsType.value = DynamicsType.values[0];
    initialValue.value = 0;
    SmartDialog.showToast('还原默认加载');
    dynamicsList.value = <DynamicItemModel>[];
    queryFollowDynamic();
  }

  // 点击up主
  void onTapUp(data) {
    mid.value = data.mid;
    upInfo.value = data;
    onSelectUp(data.mid);
  }
}
