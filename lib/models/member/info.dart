import 'package:pilipala/models/json_field.dart';

class MemberInfoModel {
  MemberInfoModel({
    this.mid,
    this.name,
    this.sex,
    this.face,
    this.sign,
    this.level,
    this.isFollowed,
    this.topPhoto,
    this.official,
    this.vip,
    this.liveRoom,
  });

  int? mid;
  String? name;
  String? sex;
  String? face;
  String? sign;
  int? level;
  bool? isFollowed;
  String? topPhoto;
  Map? official;
  Vip? vip;
  LiveRoom? liveRoom;

  MemberInfoModel.fromJson(Map<String, dynamic> json) {
    mid = json['mid'];
    name = json['name'];
    sex = json['sex'];
    face = json['face'];
    sign = json['sign'] == '' ? '该用户还没有签名' : json['sign'].replaceAll('\n', '');
    level = json['level'];
    isFollowed = json['is_followed'];
    topPhoto = json['top_photo'];
    official = json['official'];
    vip = Vip.fromJson(json['vip']);
    liveRoom =
        json['live_room'] != null ? LiveRoom.fromJson(json['live_room']) : null;
  }
}

class Vip {
  Vip({
    this.type,
    this.status,
    this.dueDate,
    this.label,
    this.nicknameColor,
  });

  int? type;
  int? status;
  int? dueDate;
  Map? label;
  int? nicknameColor;

  Vip.fromJson(Map<String, dynamic> json) {
    type = asInt(json['type']);
    status = asInt(json['status']);
    dueDate = asInt(json['due_date']);
    label = asMap(json['label']);
    // 原实现：nickname_color 为 null 时 null == '' 为 false，接着对 null 调
    // replaceAll → NoSuchMethodError，整篇专栏/图文解析失败。
    // 非 #RRGGBB 格式时 int.parse 也会抛，这里统一兜底。
    final String raw = asStr(json['nickname_color']) ?? '';
    final String hex = raw.replaceAll('#', '').trim();
    if (hex.isEmpty) {
      nicknameColor = null;
    } else {
      nicknameColor = int.tryParse('0xFF$hex');
    }
  }
}

class LiveRoom {
  LiveRoom({
    this.roomStatus,
    this.liveStatus,
    this.url,
    this.title,
    this.cover,
    this.roomId,
    this.roundStatus,
    this.watchedShow,
  });

  int? roomStatus;
  int? liveStatus;
  String? url;
  String? title;
  String? cover;
  int? roomId;
  int? roundStatus;
  Map? watchedShow;

  LiveRoom.fromJson(Map<String, dynamic> json) {
    roomStatus = json['roomStatus'];
    liveStatus = json['liveStatus'];
    url = json['url'];
    title = json['title'];
    cover = json['cover'];
    roomId = json['roomid'];
    roundStatus = json['roundStatus'];
    watchedShow = json['watched_show'];
  }
}
