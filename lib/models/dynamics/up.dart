import 'result.dart';

// ---------------------------------------------------------------------------
// 关注动态「UP 主 / 直播」面板的数据模型。
// 这些字段在不同端/版本上可能是 int / String / double（真实遇到：
// portal 接口返回的 mid、count 偶发是字符串 → "type 'String' is not a
// subtype of type 'int?'"，整个动态页 UP 主面板变成错误卡片）。
// 统一走 result.dart 里的 asInt/asStr 做类型归一。
// ---------------------------------------------------------------------------
class FollowUpModel {
  FollowUpModel({
    this.liveUsers,
    this.upList,
    this.liveList,
    this.myInfo,
  });

  LiveUsers? liveUsers;
  List<UpItem>? upList;
  List<LiveUserItem>? liveList;
  MyInfo? myInfo;

  FollowUpModel.fromJson(Map<String, dynamic> json) {
    liveUsers = json['live_users'] is Map
        ? LiveUsers.fromJson(Map<String, dynamic>.from(json['live_users']))
        : null;
    final dynamic liveItems = json['live_users'] is Map
        ? json['live_users']['items']
        : null;
    liveList = liveItems is List
        ? liveItems
            .whereType<Map>()
            .map<LiveUserItem>(
                (e) => LiveUserItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : [];
    final dynamic upList = json['up_list'];
    this.upList = upList is List
        ? upList
            .whereType<Map>()
            .map<UpItem>((e) => UpItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : [];
    myInfo = json['my_info'] is Map
        ? MyInfo.fromJson(Map<String, dynamic>.from(json['my_info']))
        : null;
  }
}

class LiveUsers {
  LiveUsers({
    this.count,
    this.group,
    this.items,
  });

  int? count;
  String? group;
  List<LiveUserItem>? items;

  LiveUsers.fromJson(Map<String, dynamic> json) {
    count = asInt(json['count']);
    group = asStr(json['group']);
    final dynamic list = json['items'];
    items = list is List
        ? list
            .whereType<Map>()
            .map<LiveUserItem>(
                (e) => LiveUserItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : [];
  }
}

class LiveUserItem {
  LiveUserItem({
    this.face,
    this.isReserveRecall,
    this.jumpUrl,
    this.mid,
    this.roomId,
    this.title,
    this.uname,
  });

  String? face;
  bool? isReserveRecall;
  String? jumpUrl;
  int? mid;
  int? roomId;
  String? title;
  String? uname;
  bool hasUpdate = false;
  String type = 'live';

  LiveUserItem.fromJson(Map<String, dynamic> json) {
    face = asStr(json['face']);
    isReserveRecall = json['is_reserve_recall'] is bool
        ? json['is_reserve_recall']
        : asInt(json['is_reserve_recall']) == 1;
    jumpUrl = asStr(json['jump_url']);
    mid = asInt(json['mid']);
    roomId = asInt(json['room_id']);
    title = asStr(json['title']);
    uname = asStr(json['uname']);
  }
}

class UpItem {
  UpItem({
    this.face,
    this.hasUpdate,
    this.isReserveRecall,
    this.mid,
    this.uname,
  });

  String? face;
  bool? hasUpdate;
  bool? isReserveRecall;
  int? mid;
  String? uname;
  String type = 'up';

  UpItem.fromJson(Map<String, dynamic> json) {
    face = asStr(json['face']);
    hasUpdate = json['has_update'] is bool
        ? json['has_update']
        : asInt(json['has_update']) == 1;
    isReserveRecall = json['is_reserve_recall'] is bool
        ? json['is_reserve_recall']
        : asInt(json['is_reserve_recall']) == 1;
    mid = asInt(json['mid']);
    uname = asStr(json['uname']);
  }
}

class MyInfo {
  MyInfo({
    this.face,
    this.mid,
    this.name,
  });

  String? face;
  int? mid;
  String? name;

  MyInfo.fromJson(Map<String, dynamic> json) {
    face = asStr(json['face']);
    mid = asInt(json['mid']);
    name = asStr(json['name']);
  }
}
