import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/msg.dart';
import 'package:pilipala/models/msg/account.dart';
import 'package:pilipala/models/msg/session.dart';

class WhisperController extends GetxController {
  RxList<SessionList> sessionList = <SessionList>[].obs;
  RxList<AccountListModel> accountList = <AccountListModel>[].obs;
  bool isLoading = false;
  RxList noticesList = [
    {
      'icon': Icons.message_outlined,
      'title': '回复我的',
      'path': '/messageReply',
      'count': 0,
    },
    {
      'icon': Icons.alternate_email,
      'title': '@我的',
      'path': '/messageAt',
      'count': 0,
    },
    {
      'icon': Icons.thumb_up_outlined,
      'title': '收到的赞',
      'path': '/messageLike',
      'count': 0,
    },
    {
      'icon': Icons.notifications_none_outlined,
      'title': '系统通知',
      'path': '/messageSystem',
      'count': 0,
    }
  ].obs;

  @override
  void onInit() {
    unread();
    super.onInit();
  }

  Future querySessionList(String? type) async {
    if (isLoading) return;
    // 上拉加载时如果本地会话列表为空（首次加载失败后下拉重试等），
    // sessionList.last 会抛 StateError 让整页私信列表永久空白
    if (type == 'onLoad' && sessionList.isEmpty) return;
    var res = await MsgHttp.sessionList(
        endTs: type == 'onLoad' ? sessionList.last.sessionTs : null);
    if (res['status'] != true) {
      // 接口失败时 MsgHttp.sessionList 返回的 data 是空 List，
      // 原来这里直接 res['data'].sessionList 会抛
      // NoSuchMethodError（List 没有 sessionList 成员）→ 断网进私信直接崩
      isLoading = false;
      return res;
    }
    final SessionDataModel? sessionData = res['data'];
    if (sessionData?.sessionList != null &&
        sessionData!.sessionList!.isNotEmpty) {
      await queryAccountList(sessionData.sessionList!);
      // 将 accountList 转换为 Map 结构
      Map<int, dynamic> accountMap = {};
      for (var j in accountList) {
        accountMap[j.mid!] = j;
      }

      // 遍历 sessionList，通过 mid 查找并赋值 accountInfo
      for (var i in sessionData.sessionList!) {
        var accountInfo = accountMap[i.talkerId];
        if (accountInfo != null) {
          i.accountInfo = accountInfo;
        }
        if (i.talkerId == 844424930131966) {
          i.accountInfo = AccountListModel(
            name: 'UP主小助手',
            face:
                'https://message.biliimg.com/bfs/im/489a63efadfb202366c2f88853d2217b5ddc7a13.png',
          );
        }
      }
    }
    final List<SessionList>? list = sessionData?.sessionList;
    if (list != null) {
      if (type == 'onLoad') {
        sessionList.addAll(list);
      } else {
        sessionList.value = list;
      }
    }
    isLoading = false;
    return res;
  }

  Future queryAccountList(sessionList) async {
    List midsList = sessionList.map((e) => e.talkerId!).toList();
    var res = await MsgHttp.accountList(midsList.join(','));
    if (res['status']) {
      accountList.value = res['data'];
    }
    return res;
  }

  Future onLoad() async {
    querySessionList('onLoad');
  }

  Future onRefresh() async {
    querySessionList('onRefresh');
  }

  void refreshLastMsg(int talkerId, String content) {
    // 会话可能已被删除/服务端已移除（或列表还没加载完），
    // 原来无 orElse 的 first 会抛 StateError，导致发送成功后整个会话列表不刷新
    final Iterable<SessionList> matched =
        sessionList.where((p0) => p0.talkerId == talkerId);
    if (matched.isEmpty) return;
    final SessionList currentItem = matched.first;
    // lastMsg / content 都可能是 null（接口不返回），content 还可能是空串
    // （Lib/models/msg/session.dart:145-147 解析失败时给 ''），
    // 直接下标赋值会抛 NoSuchMethodError
    currentItem.lastMsg ??= LastMsg();
    final dynamic msgContent = currentItem.lastMsg!.content;
    if (msgContent is Map) {
      msgContent['content'] = content;
    } else {
      currentItem.lastMsg!.content = <String, dynamic>{'content': content};
    }
    sessionList.removeWhere((p0) => p0.talkerId == talkerId);
    sessionList.insert(0, currentItem);
    sessionList.refresh();
  }

  // 移除会话
  void removeSessionMsg(int talkerId) {
    sessionList.removeWhere((p0) => p0.talkerId == talkerId);
    sessionList.refresh();
  }

  // 消息未读数
  void unread() async {
    var res = await MsgHttp.unread();
    if (res['status']) {
      noticesList[0]['count'] = res['data']['reply'];
      noticesList[1]['count'] = res['data']['at'];
      noticesList[2]['count'] = res['data']['like'];
      noticesList[3]['count'] = res['data']['sys_msg'];
      noticesList.refresh();
    }
  }
}
