import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/reply.dart';
import 'package:pilipala/models/common/reply_type.dart';
import 'package:pilipala/models/video/reply/item.dart';

class VideoReplyReplyController extends GetxController {
  VideoReplyReplyController(this.aid, this.rpid, this.replyType);
  final ScrollController scrollController = ScrollController();
  // 视频aid 请求时使用的oid
  int? aid;
  // rpid 请求楼中楼回复
  String? rpid;
  ReplyType replyType = ReplyType.video;
  RxList<ReplyItemModel> replyList = <ReplyItemModel>[].obs;
  // 当前页
  int currentPage = 0;
  bool isLoadingMore = false;
  RxString noMore = ''.obs;
  // 当前回复的回复
  ReplyItemModel? currentReplyItem;

  @override
  void onInit() {
    super.onInit();
    currentPage = 0;
  }

  Future queryReplyList({type = 'init', currentReply}) async {
    if (type == 'init') {
      currentPage = 0;
    }
    if (isLoadingMore) {
      return;
    }
    isLoadingMore = true;
    try {
      final res = await ReplyHttp.replyReplyList(
        oid: aid!,
        root: rpid!,
        pageNum: currentPage + 1,
        type: replyType.index,
      );
      if (res['status']) {
        final List<ReplyItemModel> replies = res['data'].replies;
        if (replies.isNotEmpty) {
          noMore.value = '加载中...';
          final int? totalCount = res['data'].page?.count;
          if (totalCount != null && replies.length == totalCount) {
            noMore.value = '没有更多了';
          }
          currentPage++;
        } else {
          // 未登录状态replies可能返回null
          noMore.value = currentPage == 0 ? '还没有评论' : '没有更多了';
        }
        if (type == 'init') {
          replyList.value = replies;
        } else {
          // 每次回复之后，翻页请求有且只有相同的一条回复数据
          if (replies.length == 1 &&
              replyList.isNotEmpty &&
              replies.last.rpid == replyList.last.rpid) {
            noMore.value = '没有更多了';
            return res;
          }
          replyList.addAll(replies);
          // res['data'].replies.addAll(replyList);
        }
      }
      if (replyList.isNotEmpty && currentReply != null) {
        int indexToRemove =
            replyList.indexWhere((item) => currentReply.rpid == item.rpid);
        // 如果找到了指定ID的项，则移除
        if (indexToRemove != -1) {
          replyList.removeAt(indexToRemove);
        }
        if (currentPage == 1 && type == 'init') {
          replyList.insert(0, currentReply);
        }
      }
      return res;
    } catch (e) {
      // 网络/接口异常：返回失败结构让 UI 显示错误并可重试，避免 isLoadingMore 永久卡死
      return {
        'status': false,
        'code': -1,
        'msg': '回复加载失败，请稍后重试',
      };
    } finally {
      isLoadingMore = false;
    }
  }

  @override
  void onClose() {
    currentPage = 0;
    super.onClose();
  }
}
