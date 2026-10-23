import 'package:pilipala/models/live/follow.dart';

import '../models/live/item.dart';
import '../models/live/room_info.dart';
import '../models/live/room_info_h5.dart';
import '../utils/wbi_sign.dart';
import 'api.dart';
import 'init.dart';

class LiveHttp {
  static Future liveList(
      {int? vmid, int? pn, int? ps, String? orderType}) async {
    // 说明：原接口 /xlive/web-interface/v1/second/getUserRecommend 已被 B 站风控，
    // 无条件返回 {"code":-352}，导致首页「直播」tab 永远空白并直接显示 -352。
    // 改用仍可用的 /room/v1/room/get_user_recommend。
    var res = await Request().get(Api.liveList,
        data: {'page': pn, 'page_size': 30, 'platform': 'web'});
    if (res.data['code'] == 0) {
      final dynamic list = res.data['data'];
      if (list is! List) {
        return {'status': false, 'data': [], 'msg': '直播列表格式异常'};
      }
      return {
        'status': true,
        'data': list
            .whereType<Map>()
            .map<LiveItemModel>(
                (e) => LiveItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': _liveErrorMessage(res.data['code'], res.data['message']),
      };
    }
  }

  /// 把直播接口的错误码转成用户能看懂的文案，避免直接显示 -352 / -101 这类数字。
  static String _liveErrorMessage(dynamic code, dynamic message) {
    switch (code) {
      case -352:
        return '直播推荐接口被风控拦截，请稍后重试';
      case -101:
        return '账号未登录';
      case -400:
        return '请求参数错误';
      default:
        final String msg = (message ?? '').toString();
        if (msg.isEmpty || RegExp(r'^-?\d+$').hasMatch(msg)) {
          return '直播列表加载失败';
        }
        return msg;
    }
  }

  static Future liveRoomInfo({roomId, qn}) async {
    var res = await Request().get(Api.liveRoomInfo, data: {
      'room_id': roomId,
      'protocol': '0, 1',
      'format': '0, 1, 2',
      'codec': '0, 1',
      'qn': qn,
      'platform': 'web',
      'ptype': 8,
      'dolby': 5,
      'panorama': 1,
    });
    if (res.data['code'] == 0) {
      return {'status': true, 'data': RoomInfoModel.fromJson(res.data['data'])};
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }

  static Future liveRoomInfoH5({roomId, qn}) async {
    var res = await Request().get(Api.liveRoomInfoH5, data: {
      'room_id': roomId,
    });
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': RoomInfoH5Model.fromJson(res.data['data'])
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }

  // 获取弹幕信息
  // 说明：/xlive/web-room/v1/index/getDanmuInfo 已接入风控，不带 wbi 签名
  // 无条件返回 {"code":-352}。原来只传 id 一个参数，导致 host_list 与 token
  // 都是空的 —— initSocket 只能退回硬编码域名、joinRoom 带空 key，
  // 鉴权失败后服务端不推任何消息，表现就是「直播间弹幕一直不加载」。
  static Future liveDanmakuInfo({roomId}) async {
    try {
      final Map<String, dynamic> params = await WbiSign().makSign({
        'id': roomId,
        'type': 0,
        'web_location': 444.8,
      });
      final res = await Request().get(Api.getDanmuInfo, data: params);
      if (res.data['code'] == 0) {
        final dynamic data = res.data['data'];
        if (data is! Map) {
          return {'status': false, 'data': [], 'msg': '弹幕服务器信息格式异常'};
        }
        return {'status': true, 'data': data};
      }
      return {
        'status': false,
        'data': [],
        'msg': res.data['message']?.toString() ?? '弹幕服务器信息获取失败',
      };
    } catch (e) {
      return {'status': false, 'data': [], 'msg': '弹幕服务器信息获取失败'};
    }
  }

  // 发送弹幕
  static Future sendDanmaku({roomId, msg}) async {
    var res = await Request().post(
      Api.sendLiveMsg,
      data: {
        'bubble': 0,
        'msg': msg,
        'color': 16777215, // 颜色
        'mode': 1, // 模式
        'room_type': 0,
        'jumpfrom': 71001, // 直播间来源
        'reply_mid': 0,
        'reply_attr': 0,
        'replay_dmid': '',
        'statistics': {"appId": 100, "platform": 5},
        'fontsize': 25, // 字体大小
        'rnd': DateTime.now().millisecondsSinceEpoch ~/ 1000, // 时间戳
        'roomid': roomId,
        'csrf': await Request.getCsrf(),
        'csrf_token': await Request.getCsrf(),
      },
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }

  // 我的关注 正在直播
  static Future liveFollowing({int? pn, int? ps}) async {
    var res = await Request().get(Api.getFollowingLive, data: {
      'page': pn,
      'page_size': ps,
      'platform': 'web',
      'ignoreRecord': 1,
      'hit_ab': true,
    });
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': LiveFollowingModel.fromJson(res.data['data'])
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }

  // 直播历史记录
  static Future liveRoomEntry({required int roomId}) async {
    await Request().post(
      Api.liveRoomEntry,
      data: {
        'room_id': roomId,
        'platform': 'pc',
        'csrf_token': await Request.getCsrf(),
        'csrf': await Request.getCsrf(),
        'visit_id': '',
      },
    );
  }
}
