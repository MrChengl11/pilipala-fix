import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:brotli/brotli.dart';
import 'package:pilipala/models/live/message.dart';
import 'package:pilipala/utils/binary_writer.dart';

class LiveUtils {
  static List<int> encodeData(String msg, int action) {
    var data = utf8.encode(msg);
    //头部长度固定16
    var length = data.length + 16;
    var buffer = Uint8List(length);

    var writer = BinaryWriter([]);

    //数据包长度
    writer.writeInt(buffer.length, 4);
    //数据包头部长度,固定16
    writer.writeInt(16, 2);

    //协议版本，0=JSON,1=Int32,2=Buffer
    writer.writeInt(0, 2);

    //操作类型
    writer.writeInt(action, 4);

    //数据包头部长度,固定1

    writer.writeInt(1, 4);

    writer.writeBytes(data);

    return writer.buffer;
  }

  // 解析 socket 数据包。B 站直播的 protover=2/3（zlib/brotli）会把**若干个完整
  // 数据包**（各自带 16 字节头）压进一个包里，解压后必须按包头继续逐个解析。
  // 原实现是把解压结果当纯文本，用「控制字符」去切分 JSON —— 一旦某条弹幕
  // 文本里出现控制字符就会把 JSON 切成两半、parseMessage 抛异常，这条弹幕静默丢失。
  static List<LiveMessageModel>? decodeMessage(List<int> data) {
    try {
      final List<LiveMessageModel> messages = <LiveMessageModel>[];
      _decodeFrames(data, messages);
      return messages.isEmpty ? null : messages;
    } catch (e) {
      print(e);
    }
    return null;
  }

  static void _decodeFrames(List<int> data, List<LiveMessageModel> out) {
    int offset = 0;
    while (offset + 16 <= data.length) {
      //操作类型。3=心跳回应，内容为房间人气值；5=通知，弹幕、广播等全部信息；8=进房回应，空
      final int packLen = readInt(data, offset, 4);
      final int headLen = readInt(data, offset + 4, 2);
      //协议版本。0为JSON，可以直接解析；1为房间人气值,Body为4位Int32；2为压缩过Buffer，需要解压再处理
      final int ver = readInt(data, offset + 6, 2);
      final int op = readInt(data, offset + 8, 4);
      // 脏包/截断包：长度不合法时停止，避免死循环或越界抛异常
      if (packLen < 16 || headLen < 16 || offset + packLen > data.length) break;
      final List<int> body = data.sublist(offset + headLen, offset + packLen);
      if (op == 3) {
        if (body.length >= 4) {
          out.add(LiveMessageModel(
            type: LiveMessageType.online,
            userName: '',
            message: '',
            color: LiveMessageColor.white,
            data: readInt(body, 0, 4),
          ));
        }
      } else if (op == 5) {
        List<int> payload = body;
        if (ver == 2) {
          payload = zlib.decode(body);
        } else if (ver == 3) {
          payload = brotli.decode(body);
        }
        if (ver == 2 || ver == 3) {
          // 解压出来的仍是一串完整数据包（各自带包头），递归解析
          _decodeFrames(payload, out);
        } else {
          final String text = utf8.decode(payload, allowMalformed: true);
          // 同一包内可能存在多个以 \u0000 分隔的 JSON，逐个解析
          for (final String seg in text.split('\u0000')) {
            final String jsonStr = seg.trim();
            if (jsonStr.length > 2 && jsonStr.startsWith('{')) {
              final LiveMessageModel? msg = parseMessage(jsonStr);
              if (msg != null) out.add(msg);
            }
          }
        }
      }
      offset += packLen;
    }
  }
  static LiveMessageModel? parseMessage(String jsonMessage) {
    try {
      var obj = json.decode(jsonMessage);
      var cmd = obj["cmd"].toString();
      if (cmd.contains("DANMU_MSG")) {
        // 弹幕包结构：info[0]=元信息数组，info[1]=弹幕文本，info[2]=发送者[uid,uname,...]
        // 老实现死取 info[0][15]['extra']/'user'，一旦被风控降级成精简包就整条丢弃，
        // 这里改成逐层判空 + 用 info[2] 兜底用户名。
        final dynamic info = obj["info"];
        if (info is List && info.length > 1) {
          final String message = info[1]?.toString() ?? "";
          final dynamic meta = info[0];
          final int color = (meta is List && meta.length > 3)
              ? (asT<int?>(meta[3]) ?? 0)
              : 0;
          String userName = "";
          String? face;
          Map<String, dynamic>? extraMap;
          int userId = 0;
          if (meta is List && meta.length > 15 && meta[15] is Map) {
            final dynamic extra = meta[15]['extra'];
            try {
              if (extra is String && extra.isNotEmpty) {
                final dynamic decoded = jsonDecode(extra);
                if (decoded is Map) {
                  extraMap = Map<String, dynamic>.from(decoded);
                }
              }
            } catch (_) {}
            final dynamic user =
                (meta[15]['user'] is Map) ? meta[15]['user']['base'] : null;
            if (user is Map) {
              userName = user['name']?.toString() ?? "";
              face = user['face']?.toString();
            }
          }
          final dynamic sender = info[2];
          if (sender is List && sender.isNotEmpty) {
            userId = asT<int?>(sender[0]) ?? 0;
            if (userName.isEmpty && sender.length > 1) {
              userName = sender[1]?.toString() ?? "";
            }
          }
          if (userName.isEmpty && message.isEmpty) return null;
          {
            final LiveMessageModel liveMsg = LiveMessageModel(
              type: LiveMessageType.chat,
              userName: userName,
              message: message,
              color: color == 0
                  ? LiveMessageColor.white
                  : LiveMessageColor.numberToColor(color),
              face: face,
              uid: userId,
              emots: (extraMap != null && extraMap['emots'] is Map)
                  ? Map<String, dynamic>.from(extraMap['emots'])
                  : null,
            );
            return liveMsg;
          }
        }
      } else if (cmd.startsWith("SUPER_CHAT_MESSAGE")) {
        final dynamic data = obj["data"];
        final dynamic userInfo = (data is Map) ? data["user_info"] : null;
        if (data is! Map || userInfo is! Map) {
          return null;
        }
        final String backgroundBottomColor =
            data["background_bottom_color"].toString();
        final String backgroundColor = data["background_color"].toString();
        final DateTime endTime =
            DateTime.fromMillisecondsSinceEpoch(data["end_time"] * 1000);
        final String face = "${userInfo["face"]}@200w.jpg";
        final String message = data["message"].toString();
        final String price = data["price"]?.toString() ?? "";
        final DateTime startTime =
            DateTime.fromMillisecondsSinceEpoch(data["start_time"] * 1000);
        final String userName = userInfo["uname"].toString();

        final LiveMessageModel liveMsg = LiveMessageModel(
          type: LiveMessageType.superChat,
          userName: "SUPER_CHAT_MESSAGE",
          message: "SUPER_CHAT_MESSAGE",
          color: LiveMessageColor.white,
          data: {
            "backgroundBottomColor": backgroundBottomColor,
            "backgroundColor": backgroundColor,
            "endTime": endTime,
            "face": face,
            "message": message,
            "price": price,
            "startTime": startTime,
            "userName": userName,
          },
        );
        return liveMsg;
      } else if (cmd == 'INTERACT_WORD') {
        final dynamic data = obj["data"];
        if (data is! Map) return null;
        final String userName = data['uname']?.toString() ?? "";
        if (userName.isEmpty) return null;
        final int msgType = asT<int?>(data['msg_type']) ?? 0;
        // msg_type: 1=进入 2=关注 3=分享 4=特别关注 5=互粉
        final String tip = msgType == 2
            ? '关注了主播'
            : msgType == 3
                ? '分享了直播间'
                : msgType == 4
                    ? '特别关注了主播'
                    : '进入直播间';
        return LiveMessageModel(
          type: msgType == 1 ? LiveMessageType.join : LiveMessageType.follow,
          userName: userName,
          message: tip,
          color: LiveMessageColor.white,
        );
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  static T? asT<T>(dynamic value) {
    if (value is T) {
      return value;
    }
    return null;
  }

  static int readInt(List<int> buffer, int start, int len) {
    var data = _getByteData(buffer, start, len);
    return _readIntFromByteData(data, len);
  }

  static ByteData _getByteData(List<int> buffer, int start, int len) {
    var bytes =
        Uint8List.fromList(buffer.getRange(start, start + len).toList());
    return ByteData.view(bytes.buffer);
  }

  static int _readIntFromByteData(ByteData data, int len) {
    switch (len) {
      case 1:
        return data.getUint8(0);
      case 2:
        return data.getInt16(0, Endian.big);
      case 4:
        return data.getInt32(0, Endian.big);
      case 8:
        return data.getInt64(0, Endian.big);
      default:
        throw ArgumentError('Invalid length: $len');
    }
  }
}
