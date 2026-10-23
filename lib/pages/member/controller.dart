import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/http/member.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/member/archive.dart';
import 'package:pilipala/models/member/coin.dart';
import 'package:pilipala/models/member/info.dart';
import 'package:pilipala/models/member/like.dart';
import 'package:pilipala/models/member/seasons.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:share_plus/share_plus.dart';

class MemberController extends GetxController {
  late int mid;
  Rx<MemberInfoModel> memberInfo = MemberInfoModel().obs;
  Map userStat = {};
  RxString face = ''.obs;
  String? heroTag;
  Box userInfoCache = GStrorage.userInfo;
  late int ownerMid;
  // 投稿列表
  RxList<VListItemModel>? archiveList = <VListItemModel>[].obs;
  dynamic userInfo;
  RxInt attribute = (-1).obs;
  RxString attributeText = '关注'.obs;
  RxList<MemberCoinsDataModel> recentCoinsList = <MemberCoinsDataModel>[].obs;
  RxList<MemberLikeDataModel> recentLikeList = <MemberLikeDataModel>[].obs;
  RxBool isOwner = false.obs;

  @override
  void onInit() {
    super.onInit();
    mid = int.parse(Get.parameters['mid']!);
    userInfo = userInfoCache.get('userInfoCache');
    ownerMid = userInfo != null ? userInfo.mid : -1;
    isOwner.value = mid == ownerMid;
    face.value = Get.arguments?['face'] ?? '';
    heroTag = Get.arguments?['heroTag'] ?? '';
    relationSearch();
  }

  // 获取用户信息
  Future<Map<String, dynamic>> getInfo() async {
    await getMemberStat();
    await getMemberView();
    var res = await MemberHttp.memberInfo(mid: mid);
    if (res['status']) {
      memberInfo.value = res['data'];
      face.value = res['data'].face;
    }
    return res;
  }

  // 获取用户状态
  Future<Map<String, dynamic>> getMemberStat() async {
    var res = await MemberHttp.memberStat(mid: mid);
    if (res['status']) {
      userStat = res['data'];
    }
    return res;
  }

  // 获取用户播放数 获赞数
  Future<Map<String, dynamic>> getMemberView() async {
    var res = await MemberHttp.memberView(mid: mid);
    if (res['status'] && res['data'] is Map) {
      userStat.addAll(res['data']);
    }
    return res;
  }

  // 关注/取关up
  Future actionRelationMod() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    if (attribute.value == 128) {
      blockUser();
      return;
    }
    SmartDialog.show(
      useSystem: true,
      animationType: SmartAnimationType.centerFade_otherSlide,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(memberInfo.value.isFollowed! ? '取消关注UP主?' : '关注UP主?'),
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
                final res = await VideoHttp.relationMod(
                  mid: mid,
                  act: memberInfo.value.isFollowed! ? 2 : 1,
                  reSrc: 11,
                );
                SmartDialog.dismiss();
                if (res['status'] != true) {
                  SmartDialog.showToast(res['msg'] ?? '操作失败');
                  return;
                }
                memberInfo.value.isFollowed = !memberInfo.value.isFollowed!;
                relationSearch();
                memberInfo.update((val) {});
              },
              child: const Text('确认'),
            )
          ],
        );
      },
    );
  }

  // 关系查询
  Future relationSearch() async {
    if (userInfo == null) return;
    if (mid == ownerMid) return;
    var res = await UserHttp.hasFollow(mid);
    if (res['status']) {
      attribute.value = res['data']['attribute'];
      switch (attribute.value) {
        case 1:
          attributeText.value = '悄悄关注';
          break;
        case 2:
          attributeText.value = '已关注';
          break;
        case 6:
          attributeText.value = '已互关';
          break;
        case 128:
          attributeText.value = '已拉黑';
          break;
        default:
          attributeText.value = '关注';
      }
      // data 里不一定带 special 字段（未登录/接口降级），强解会 NoSuchMethod
      if (res['data'] is Map && res['data']['special'] == 1) {
        attributeText.value += 'SP';
      }
    }
  }

  // 拉黑用户
  Future blockUser() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    SmartDialog.show(
      useSystem: true,
      animationType: SmartAnimationType.centerFade_otherSlide,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(attribute.value != 128 ? '确定拉黑UP主?' : '从黑名单移除UP主'),
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
                  mid: mid,
                  act: attribute.value != 128 ? 5 : 6,
                  reSrc: 11,
                );
                SmartDialog.dismiss();
                if (res['status']) {
                  attribute.value = attribute.value != 128 ? 128 : 0;
                  attributeText.value = attribute.value == 128 ? '已拉黑' : '关注';
                  memberInfo.value.isFollowed = false;
                  relationSearch();
                  memberInfo.update((val) {});
                }
              },
              child: const Text('确认'),
            )
          ],
        );
      },
    );
  }

  void shareUser() {
    Share.share('${memberInfo.value.name} - https://space.bilibili.com/$mid');
  }

  // 请求合集
  Future getMemberSeasons() async {
    if (userInfo == null) return;
    var res = await MemberHttp.getMemberSeasons(mid, 1, 10);
    if (!res['status']) {
      SmartDialog.showToast("用户合集请求异常：${res['msg']}");
    } else {
      // 只取前四个专栏（seasonsList / archives 都可能为 null）
      final List<MemberSeasonsList> seasons =
          (res['data'] as MemberSeasonsDataModel).seasonsList ??
              <MemberSeasonsList>[];
      for (final e in seasons) {
        final List<MemberArchiveItem> archives =
            e.archives ?? <MemberArchiveItem>[];
        e.archives = archives.length > 4 ? archives.sublist(0, 4) : archives;
      }
    }
    return res;
  }

  // 请求投币视频
  Future getRecentCoinVideo() async {
    if (userInfo == null) return;
    var res = await MemberHttp.getRecentCoinVideo(mid: mid);
    // 接口失败时 data 是空 List，直接赋给 RxList<MemberCoinsDataModel>
    // 会抛类型错误（个人页「最近投币」白屏）
    if (res['status'] == true && res['data'] is List) {
      recentCoinsList.value =
          List<MemberCoinsDataModel>.from(res['data'] as List);
    }
    return res;
  }

  // 请求点赞视频
  Future getRecentLikeVideo() async {
    if (userInfo == null) return;
    var res = await MemberHttp.getRecentLikeVideo(mid: mid);
    if (res['status'] == true && res['data'] is List) {
      recentLikeList.value =
          List<MemberLikeDataModel>.from(res['data'] as List);
    }
    return res;
  }

  // 跳转查看动态
  void pushDynamicsPage() => Get.toNamed('/memberDynamics?mid=$mid');

  // 跳转查看投稿
  void pushArchivesPage() => Get.toNamed('/memberArchive?mid=$mid');

  // 跳转查看专栏
  void pushSeasonsPage() {}
  // 跳转查看最近投币
  void pushRecentCoinsPage() async {
    if (recentCoinsList.isNotEmpty) {}
  }

  void pushfavPage() => Get.toNamed('/fav?mid=$mid');
  // 跳转图文专栏
  void pushArticlePage() => Get.toNamed('/memberArticle?mid=$mid');
}
