import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/http/live.dart';
import 'package:pilipala/models/live/follow.dart';
import 'package:pilipala/models/live/item.dart';
import 'package:pilipala/utils/storage.dart';

class LiveController extends GetxController {
  final ScrollController scrollController = ScrollController();
  int count = 12;
  int _currentPage = 1;
  RxInt crossAxisCount = 2.obs;
  RxList<LiveItemModel> liveList = <LiveItemModel>[].obs;
  RxList<LiveFollowingItemModel> liveFollowingList =
      <LiveFollowingItemModel>[].obs;
  bool flag = false;
  bool hasMore = true; // 是否还有下一页
  bool _isLoading = false; // 防止同一页被并发重复请求
  OverlayEntry? popupDialog;
  Box setting = GStrorage.setting;

  @override
  void onInit() {
    super.onInit();
    crossAxisCount.value =
        setting.get(SettingBoxKey.customRows, defaultValue: 2);
  }

  // 获取推荐
  Future queryLiveList(type) async {
    if (type == 'init') {
      _currentPage = 1;
      hasMore = true;
    } else if (!hasMore) {
      // 已经到底，别再空请求（否则滚到底会无限请求下一页）
      return {'status': true, 'data': []};
    }
    if (_isLoading) {
      return {'status': true, 'data': []};
    }
    _isLoading = true;
    try {
      var res = await LiveHttp.liveList(
        pn: _currentPage,
      );
      if (res['status']) {
        final List data = res['data'] is List ? res['data'] as List : const [];
        if (type == 'init') {
          liveList.value = data.cast<LiveItemModel>().toList();
        } else if (type == 'onLoad') {
          if (data.isEmpty) {
            // 空页即停，避免到底后还在不停请求
            hasMore = false;
          } else {
            liveList.addAll(data.cast<LiveItemModel>());
            // page_size 是 30，不满一页说明后面没有了
            if (data.length < 30) hasMore = false;
          }
        }
        _currentPage += 1;
      }
      return res;
    } finally {
      _isLoading = false;
    }
  }

  // 下拉刷新
  Future onRefresh() async {
    await queryLiveList('init');
    await fetchLiveFollowing();
  }

  // 上拉加载
  Future onLoad() async {
    return queryLiveList('onLoad');
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

  //
  Future fetchLiveFollowing() async {
    var res = await LiveHttp.liveFollowing(pn: 1, ps: 20);
    if (res['status'] && res['data'] != null) {
      // 模型里 list 允许为 null，直接 as List 会 TypeError
      final List list = res['data'].list ?? const [];
      liveFollowingList.value = list
          .whereType<LiveFollowingItemModel>()
          .where((LiveFollowingItemModel item) =>
              item.liveStatus == 1 && item.recordLiveTime == 0) // 根据条件过滤
          .toList();
    }
    return res;
  }
}
