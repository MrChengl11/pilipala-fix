import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/http/live.dart';
import 'package:pilipala/models/live/message.dart';
import 'package:pilipala/models/live/quality.dart';
import 'package:pilipala/models/live/room_info.dart';
import 'package:pilipala/plugin/pl_player/index.dart';
import 'package:pilipala/plugin/pl_socket/index.dart';
import 'package:pilipala/utils/live.dart';
import '../../models/live/room_info_h5.dart';
import '../../utils/storage.dart';
import '../../utils/video_utils.dart';

class LiveRoomController extends GetxController {
  String cover = '';
  int roomId = 0;
  dynamic liveItem;
  String heroTag = '';
  // join/follow 提示用的 Timer，onClose 里统一取消，避免退出直播间后还在写已释放的 Rx
  final List<Timer> _joinTipTimers = <Timer>[];
  double volume = 0.0;
  // 静音状态
  RxBool volumeOff = false.obs;
  PlPlayerController plPlayerController = PlPlayerController(videoType: 'live');
  Rx<RoomInfoH5Model> roomInfoH5 = RoomInfoH5Model().obs;
  late bool enableCDN;
  late int currentQn;
  int? tempCurrentQn;
  late List<Map<String, dynamic>> acceptQnList;
  RxString currentQnDesc = ''.obs;
  Box userInfoCache = GStrorage.userInfo;
  int userId = 0;
  PlSocket? plSocket;
  List<String> danmuHostList = [];
  String token = '';
  // 弹幕消息列表
  RxList<LiveMessageModel> messageList = <LiveMessageModel>[].obs;
  DanmakuController? danmakuController;
  // 输入控制器
  TextEditingController inputController = TextEditingController();
  // 加入直播间提示
  RxMap<String, String> joinRoomTip = {'userName': '', 'message': ''}.obs;
  // 直播间弹幕开关 默认打开
  RxBool danmakuSwitch = true.obs;
  String buvid = '';
  StreamSubscription? danmakuSwitchSub;
  RxBool isPortrait = false.obs;

  @override
  void onInit() {
    super.onInit();
    currentQn = setting.get(SettingBoxKey.defaultLiveQa,
        defaultValue: LiveQuality.values.last.code);
    // 深链(app_scheme)/参数缺失时 roomid 可能不是数字，int.parse 会抛
    // FormatException 导致整个直播间打不开，这里用 tryParse 兜底。
    roomId = int.tryParse(Get.parameters['roomid'] ?? '') ?? 0;
    if (Get.arguments != null) {
      liveItem = Get.arguments['liveItem'];
      heroTag = Get.arguments['heroTag'] ?? '';
      if (liveItem != null) {
        cover = (liveItem.pic != null && liveItem.pic != '')
            ? liveItem.pic
            : (liveItem.cover != null && liveItem.cover != '')
                ? liveItem.cover
                : '';
      }
    }
    // buvid 与 arguments 无关：深链进入时也要取，否则 joinRoom 上报空 buvid
    Request.getBuvid().then((value) => buvid = value);
    // CDN优化
    enableCDN = setting.get(SettingBoxKey.enableCDN, defaultValue: true);
    final userInfo = userInfoCache.get('userInfoCache');
    if (userInfo != null && userInfo.mid != null) {
      userId = userInfo.mid;
    }
    liveDanmakuInfo().then((value) {
      // 弹幕鉴权信息取不到时不要连 socket：连上也收不到任何推送，
      // 反而让用户以为「直播间没弹幕」，这里直接给出可见提示。
      if (danmuHostList.isEmpty || token.isEmpty) {
        print('liveDanmakuInfo failed: $value');
        SmartDialog.showToast('弹幕连接失败，请稍后重试');
        return;
      }
      initSocket();
    });
    danmakuSwitchSub = danmakuSwitch.listen((p0) {
      plPlayerController.isOpenDanmu.value = p0;
    });
  }

  playerInit(source) async {
    await plPlayerController.setDataSource(
      DataSource(
        videoSource: source,
        audioSource: null,
        type: DataSourceType.network,
        httpHeaders: {
          'user-agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
          'referer': HttpString.baseUrl
        },
      ),
      // 硬解
      enableHA: true,
      autoplay: true,
    );
    plPlayerController.isOpenDanmu.value = danmakuSwitch.value;
    heartBeat();
  }

  Future queryLiveInfo() async {
    dynamic res;
    try {
      res = await LiveHttp.liveRoomInfo(roomId: roomId, qn: currentQn);
    } catch (e) {
      // 模型层解析(playurl_info 任意一层为 null 会 noSuchMethod)或网络异常
      return {'status': false, 'msg': '直播间信息获取失败'};
    }
    if (res is! Map || res['status'] != true) {
      return res is Map ? res : {'status': false, 'msg': '直播间信息获取失败'};
    }
    final dynamic data = res['data'];
    isPortrait.value = data?.isPortrait == true;

    // playurl / stream / format / codec 任意一层为空都会抛异常，逐层判空
    List<CodecItem> codec = [];
    final dynamic stream = data?.playurlInfo?.playurl?.stream;
    if (stream is List && stream.isNotEmpty) {
      final dynamic format = stream.first.format;
      if (format is List && format.isNotEmpty) {
        final dynamic codecList = format.first.codec;
        if (codecList is List) {
          codec = codecList.whereType<CodecItem>().toList();
        }
      }
    }
    // 区分「主播未开播」和「真的取不到流」：未开播时 playurl_info 为 null，
    // live_status=2，直接提示"直播流获取失败"会让用户以为 app 出问题。
    final int liveStatus = data?.liveStatus ?? 0;
    if (codec.isEmpty) {
      if (liveStatus == 2) {
        return {'status': false, 'msg': '主播未开播，稍后再来看看吧'};
      }
      if (liveStatus == 1 && data?.playurlInfo == null) {
        return {'status': false, 'msg': '当前无法获取播放地址，请稍后重试'};
      }
      final String msg = liveStatus == 0 ? '直播间不存在或已下播' : '直播流获取失败，请重试';
      return {'status': false, 'msg': msg};
    }

    CodecItem item = codec.first;
    // 以服务端返回的码率为准
    currentQn = item.currentQn ?? currentQn;
    if (tempCurrentQn != null && tempCurrentQn == currentQn) {
      SmartDialog.showToast('画质切换失败，请检查登录状态');
    }
    final List acceptQn = item.acceptQn ?? [];
    acceptQnList = acceptQn.map((e) {
      return {
        'code': e,
        // 服务端返回的 qn 未必都在本地枚举里（如新增画质），
        // 缺少 orElse 会抛 StateError: No element
        'desc': LiveQuality.values
            .firstWhere(
              (element) => element.code == e,
              orElse: () => LiveQuality.values.last,
            )
            .description,
      };
    }).toList();
    currentQnDesc.value = LiveQuality.values
        .firstWhere(
          (element) => element.code == currentQn,
          orElse: () => LiveQuality.values.last,
        )
        .description;

    final List<UrlInfoItem> urlInfo = item.urlInfo ?? [];
    final String? baseUrl = item.baseUrl;
    String videoUrl = '';
    if (baseUrl != null && urlInfo.isNotEmpty) {
      if (enableCDN) {
        videoUrl = VideoUtils.getCdnUrl(item);
      } else {
        videoUrl = '${urlInfo.first.host ?? ''}$baseUrl'
            '${urlInfo.first.extra ?? ''}';
      }
    } else {
      videoUrl = baseUrl ?? '';
    }
    if (videoUrl.isEmpty) {
      SmartDialog.showToast('直播流获取失败，请重试');
      return {'status': false, 'msg': '直播流获取失败'};
    }
    await playerInit(videoUrl);
    return res;
  }

  void setVolumn(value) {
    if (value == 0) {
      // 设置音量
      volumeOff.value = false;
    } else {
      // 取消音量
      volume = value;
      volumeOff.value = true;
    }
  }

  Future queryLiveInfoH5() async {
    var res = await LiveHttp.liveRoomInfoH5(roomId: roomId);
    if (res['status']) {
      roomInfoH5.value = res['data'];
    }
    return res;
  }

  // 修改画质
  void changeQn(int qn) async {
    tempCurrentQn = currentQn;
    if (currentQn == qn) {
      return;
    }
    currentQn = qn;
    currentQnDesc.value = LiveQuality.values
        .firstWhere(
          (element) => element.code == currentQn,
          orElse: () => LiveQuality.values.last,
        )
        .description;
    await queryLiveInfo();
  }

  Future liveDanmakuInfo() async {
    final res = await LiveHttp.liveDanmakuInfo(roomId: roomId);
    if (res['status']) {
      // host_list / token 任一不是预期类型时保持空列表，走下面的容错分支
      final dynamic data = res['data'];
      final dynamic rawHosts = data is Map ? data['host_list'] : null;
      final dynamic rawToken = data is Map ? data['token'] : null;
      if (rawHosts is List && rawHosts.isNotEmpty) {
        danmuHostList = rawHosts
            .whereType<Map>()
            .map<String>((e) => '${e["host"]}:${e['wss_port']}')
            .toList();
      }
      token = rawToken?.toString() ?? '';
      return res;
    }
    // 鉴权接口挂掉时不再带着空 token 去连硬编码域名
    // （服务端不推任何数据，表现为弹幕永久空白，用户毫无提示）
    danmuHostList = [];
    token = '';
    return res;
  }

  // 建立socket
  void initSocket() async {
    final wsUrl = danmuHostList.isNotEmpty
        ? danmuHostList.first
        : "broadcastlv.chat.bilibili.com";
    plSocket = PlSocket(
      url: 'wss://$wsUrl/sub',
      heartTime: 30,
      onReadyCb: () {
        joinRoom();
      },
      onMessageCb: (message) {
        final List<LiveMessageModel>? liveMsg =
            LiveUtils.decodeMessage(message);
        if (liveMsg != null && liveMsg.isNotEmpty) {
          if (liveMsg.first.type == LiveMessageType.online) {
            print('当前直播间人气：${liveMsg.first.data}');
          } else if (liveMsg.first.type == LiveMessageType.join ||
              liveMsg.first.type == LiveMessageType.follow) {
            // 每隔一秒依次liveMsg中的每一项赋给activeUserName

            int index = 0;
            // Timer 必须存起来：既要在播完后移除，也要在退出直播间(onClose)
            // 时取消，否则会继续写已释放的 Rx，且多条消息会叠加多个 Timer。
            late Timer joinTipTimer;
            joinTipTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
              if (index < liveMsg.length) {
                if (liveMsg[index].type == LiveMessageType.join ||
                    liveMsg[index].type == LiveMessageType.follow) {
                  joinRoomTip.value = {
                    'userName': liveMsg[index].userName,
                    'message': liveMsg[index].message ?? '',
                  };
                }
                index++;
              } else {
                timer.cancel();
                _joinTipTimers.remove(joinTipTimer);
              }
            });
            _joinTipTimers.add(joinTipTimer);

            return;
          }
          // 过滤出聊天消息
          var chatMessages =
              liveMsg.where((msg) => msg.type == LiveMessageType.chat).toList();

          // 添加到 messageList
          messageList.addAll(chatMessages);

          // 将 chatMessages 转换为 danmakuItems 列表
          List<DanmakuItem> danmakuItems = chatMessages.map<DanmakuItem>((e) {
            return DanmakuItem(
              e.message ?? '',
              color: Color.fromARGB(
                255,
                e.color.r,
                e.color.g,
                e.color.b,
              ),
            );
          }).toList();

          // 添加到 danmakuController
          if (danmakuSwitch.value) {
            danmakuController?.addItems(danmakuItems);
          }
        }
      },
      onErrorCb: (e) {
        print('error: $e');
      },
    );
    await plSocket?.connect();
  }

  void joinRoom() async {
    var joinData = LiveUtils.encodeData(
      json.encode({
        "uid": userId,
        "roomid": roomId,
        "protover": 3,
        "buvid": buvid,
        "platform": "web",
        "type": 2,
        "key": token,
      }),
      7,
    );
    plSocket?.sendMessage(joinData);
  }

  // 发送弹幕
  void sendMsg() async {
    final msg = inputController.text;
    if (msg.isEmpty) {
      return;
    }
    final res = await LiveHttp.sendDanmaku(
      roomId: roomId,
      msg: msg,
    );
    if (res['status']) {
      inputController.clear();
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  // 历史记录
  void heartBeat() {
    LiveHttp.liveRoomEntry(roomId: roomId);
  }

  String encodeToBase64(String input) {
    List<int> bytes = utf8.encode(input);
    String base64Str = base64.encode(bytes);
    return base64Str;
  }

  @override
  void onClose() {
    heartBeat();
    danmakuSwitchSub?.cancel();
    // 退出直播间时取消所有 join/follow 提示 Timer
    for (final timer in _joinTipTimers) {
      timer.cancel();
    }
    _joinTipTimers.clear();
    inputController.dispose();
    plSocket?.onClose();
    super.onClose();
  }
}
