import 'dart:async';

import 'package:pilipala/utils/live.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketStatus {
  connected,
  failed,
  closed,
}

class PlSocket {
  SocketStatus status = SocketStatus.closed;
  // 链接
  final String url;
  // 心跳时间
  final int heartTime;
  // 监听初始化完成
  final Function? onReadyCb;
  // 监听关闭
  final Function? onCloseCb;
  // 监听异常
  final Function? onErrorCb;
  // 监听消息
  final Function? onMessageCb;
  // 请求头
  final Map<String, dynamic>? headers;

  PlSocket({
    required this.url,
    required this.heartTime,
    this.onReadyCb,
    this.onCloseCb,
    this.onErrorCb,
    this.onMessageCb,
    this.headers,
  });

  WebSocketChannel? channel;
  StreamSubscription<dynamic>? channelStreamSub;
  // 心跳/重连定时器必须保存引用，否则重连一次就滞留一个心跳 Timer
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _connecting = false;
  int _retryCount = 0;
  // 断网时最多重连次数，避免无限重连
  static const int maxRetry = 5;

  // 建立连接
  Future connect() async {
    // 正在连接时不重复发起（原来 catch 里直接递归 connect（），
    // 断网时会指数级叠加并发连接并重复回调 onErrorCb）
    if (_connecting) return;
    _connecting = true;
    // 连接之前关闭上次连接
    onClose();
    try {
      channel = IOWebSocketChannel.connect(
        url,
        connectTimeout: const Duration(seconds: 15),
        headers: null,
      );
      await channel?.ready;
      _retryCount = 0;
      onReady();
    } catch (err) {
      onError(err);
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  // 延迟重连
  void _scheduleReconnect() {
    if (_retryCount >= maxRetry) return;
    _retryCount++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      connect();
    });
  }

  // 初始化完成
  void onReady() {
    status = SocketStatus.connected;
    onReadyCb?.call();
    channelStreamSub = channel?.stream.listen((message) {
      onMessageCb?.call(message);
    }, onDone: () {
      // 流被对端关闭：停止心跳并复位状态，避免往已关闭的 sink 里发心跳抛异常
      onClose(reconnect: true);
    }, onError: (err) {
      onError(err);
      onClose(reconnect: true);
    });
    // 先取消上一次的心跳，避免重连后多个心跳 Timer 并存
    _heartbeatTimer?.cancel();
    // 每30s发送心跳
    _heartbeatTimer = Timer.periodic(Duration(seconds: heartTime), (timer) {
      if (status == SocketStatus.connected) {
        sendMessage(LiveUtils.encodeData(
          "",
          2,
        ));
      } else {
        timer.cancel();
      }
    });
  }

  // 连接关闭
  // reconnect=true 仅在「对端断开/网络异常」时由数据流回调传入；
  // 主动关闭（connect() 开头重置、退出直播间）一律不重连。
  // 原来 onDone/onError 只调 onClose()，socket 一断就永久失联：
  // 直播间弹幕再也不更新，必须退出重进才恢复。
  void onClose({bool reconnect = false}) {
    status = SocketStatus.closed;
    onCloseCb?.call();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (!reconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    channelStreamSub?.cancel();
    channelStreamSub = null;
    channel?.sink.close();
    channel = null;
    if (reconnect) _scheduleReconnect();
  }

  // 连接异常
  void onError(err) {
    onErrorCb?.call(err);
  }

  // 接收消息
  void onMessage() {}

  void sendMessage(dynamic message) {
    if (status == SocketStatus.connected) {
      channel?.sink.add(message);
    }
  }
}
