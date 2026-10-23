import 'dart:async';
import 'dart:io';

import 'package:floating/floating.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/live/message.dart';
import 'package:pilipala/pages/danmaku/index.dart';
import 'package:pilipala/plugin/pl_player/index.dart';

import 'controller.dart';
import 'widgets/bottom_control.dart';

class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage>
    with TickerProviderStateMixin {
  final LiveRoomController _liveRoomController = Get.put(LiveRoomController());
  late PlPlayerController plPlayerController;
  late Future? _futureBuilder;
  late Future? _futureBuilderFuture;

  bool isShowCover = true;
  bool isPlay = true;
  Floating? floating;
  final ScrollController _scrollController = ScrollController();
  late AnimationController fabAnimationCtr;
  bool _shouldAutoScroll = true;
  StreamSubscription? _msgListSub;
  final int roomId = int.tryParse(Get.parameters['roomid'] ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      floating = Floating();
    }
    videoSourceInit();
    _futureBuilderFuture = _liveRoomController.queryLiveInfo();
    // 监听滚动事件
    _scrollController.addListener(_onScroll);
    fabAnimationCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.0,
    );
    // 只订阅一次，避免 didChangeDependencies 多次触发造成监听泄漏
    _msgListSub = _liveRoomController.messageList.listen((_) {
      if (_shouldAutoScroll) {
        _scrollToBottom();
      }
    });
  }

  Future<void> videoSourceInit() async {
    _futureBuilder = _liveRoomController.queryLiveInfoH5();
    plPlayerController = _liveRoomController.plPlayerController;
  }

  void _onScroll() {
    // 反向时，展示按钮
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      _shouldAutoScroll = false;
      fabAnimationCtr.forward();
    } else {
      _shouldAutoScroll = true;
      fabAnimationCtr.reverse();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController
          .animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      )
          .then((value) {
        _shouldAutoScroll = true;
        // fabAnimationCtr.forward();
      });
    }
  }

  @override
  void dispose() {
    _msgListSub?.cancel();
    plPlayerController.dispose();
    if (floating != null) {
      floating!.dispose();
    }
    _scrollController.dispose();
    fabAnimationCtr.dispose();
    // 页面退出时释放控制器（触发 onClose：关闭弹幕 socket、释放输入框等）
    Get.delete<LiveRoomController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget videoPlayerPanel = FutureBuilder(
      future: _futureBuilderFuture,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData && snapshot.data['status']) {
          plPlayerController = _liveRoomController.plPlayerController;
          return PLVideoPlayer(
            controller: plPlayerController,
            alignment: _liveRoomController.isPortrait.value
                ? Alignment.topCenter
                : Alignment.center,
            bottomControl: BottomControl(
              controller: plPlayerController,
              liveRoomCtr: _liveRoomController,
              floating: floating,
              onRefresh: () {
                setState(() {
                  _futureBuilderFuture = _liveRoomController.queryLiveInfo();
                });
              },
            ),
            danmuWidget: PlDanmaku(
              cid: roomId,
              playerController: plPlayerController,
              type: 'live',
              createdController: (e) {
                _liveRoomController.danmakuController = e;
              },
            ),
          );
        } else {
          // 直播间信息/播放流获取失败（未开播、接口风控、网络异常等）时，
          // 原来直接返回 SizedBox() 导致整片黑屏且没有任何提示与重试入口。
          final String errMsg =
              (snapshot.data is Map && snapshot.data['msg'] != null)
                  ? snapshot.data['msg'].toString()
                  : '直播间信息获取失败';
          return Container(
            color: Colors.black,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.live_tv_rounded,
                    color: Colors.white54, size: 40),
                const SizedBox(height: 12),
                Text(
                  errMsg,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _futureBuilderFuture = _liveRoomController.queryLiveInfo();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  ),
                  child: const Text('点击重试'),
                ),
              ],
            ),
          );
        }
      },
    );

    Widget childWhenDisabled = Scaffold(
      primary: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Obx(
            () => Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _liveRoomController
                              .roomInfoH5.value.roomInfo?.appBackground !=
                          '' &&
                      _liveRoomController
                              .roomInfoH5.value.roomInfo?.appBackground !=
                          null
                  ? Opacity(
                      opacity: 0.6,
                      child: NetworkImgLayer(
                        width: Get.width,
                        height: Get.height,
                        type: 'bg',
                        src: _liveRoomController
                                .roomInfoH5.value.roomInfo?.appBackground ??
                            '',
                      ),
                    )
                  : Opacity(
                      opacity: 0.6,
                      child: Image.asset(
                        'assets/images/live/default_bg.webp',
                        fit: BoxFit.cover,
                        // width: Get.width,
                        // height: Get.height,
                      ),
                    ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(
                () => SizedBox(
                  height: MediaQuery.of(context).padding.top +
                      (_liveRoomController.isPortrait.value ||
                              MediaQuery.of(context).orientation ==
                                  Orientation.landscape
                          ? 0
                          : kToolbarHeight),
                ),
              ),
              PopScope(
                canPop: plPlayerController.isFullScreen.value != true,
                onPopInvoked: (bool didPop) {
                  if (plPlayerController.isFullScreen.value == true) {
                    plPlayerController.triggerFullScreen(status: false);
                  }
                  if (MediaQuery.of(context).orientation ==
                      Orientation.landscape) {
                    verticalScreen();
                  }
                },
                child: Obx(
                  () => Container(
                    width: Get.size.width,
                    height: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? Get.size.height
                        : !_liveRoomController.isPortrait.value
                            ? Get.size.width * 9 / 16
                            : Get.size.height -
                                MediaQuery.of(context).padding.top,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: videoPlayerPanel,
                  ),
                ),
              ),
            ],
          ),
          // 定位 快速滑动到底部
          Positioned(
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 4),
                end: const Offset(0, 0),
              ).animate(CurvedAnimation(
                parent: fabAnimationCtr,
                curve: Curves.easeInOut,
              )),
              child: ElevatedButton.icon(
                onPressed: () {
                  _scrollToBottom();
                },
                icon: const Icon(Icons.keyboard_arrow_down), // 图标
                label: const Text('新消息'), // 文字
                style: ElevatedButton.styleFrom(
                  // primary: Colors.blue, // 按钮背景颜色
                  // onPrimary: Colors.white, // 按钮文字颜色
                  padding: const EdgeInsets.fromLTRB(14, 12, 20, 12), // 按钮内边距
                ),
              ),
            ),
          ),
          // 顶栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              centerTitle: false,
              titleSpacing: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              toolbarHeight:
                  MediaQuery.of(context).orientation == Orientation.portrait
                      ? 56
                      : 0,
              title: FutureBuilder(
                future: _futureBuilder,
                builder: (context, snapshot) {
                  if (snapshot.data == null) {
                    return const SizedBox();
                  }
                  Map data = snapshot.data as Map;
                  if (data['status']) {
                    return Obx(() {
                      // H5 接口成功但 anchor_info/base_info 缺失时，
                      // 原来的 anchorInfo!.baseInfo!.face 会直接 null check 崩溃
                      final dynamic baseInfo = _liveRoomController
                          .roomInfoH5.value.anchorInfo?.baseInfo;
                      final Map? watchedShow =
                          _liveRoomController.roomInfoH5.value.watchedShow;
                      return Row(
                        children: [
                          NetworkImgLayer(
                            width: 34,
                            height: 34,
                            type: 'avatar',
                            src: baseInfo?.face,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                baseInfo?.uname ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 1),
                              if (watchedShow != null)
                                Text(
                                  watchedShow['text_large'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      );
                    });
                  } else {
                    return const SizedBox();
                  }
                },
              ),
            ),
          ),
          // 消息列表
          Obx(
            () => Positioned(
              top: MediaQuery.of(context).padding.top +
                  kToolbarHeight +
                  (_liveRoomController.isPortrait.value
                      ? Get.size.width
                      : Get.size.width * 9 / 16),
              bottom: 90 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: buildMessageListUI(
                context,
                _liveRoomController,
                _scrollController,
              ),
            ),
          ),
          // 消息输入框
          Visibility(
            visible: MediaQuery.of(context).orientation == Orientation.portrait,
            child: Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 4,
                    bottom: MediaQuery.of(context).padding.bottom + 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Obx(
                        () => IconButton(
                          style: ButtonStyle(
                            padding: MaterialStateProperty.all(EdgeInsets.zero),
                            backgroundColor: MaterialStateProperty.resolveWith(
                                (Set<MaterialState> states) {
                              return Colors.grey.withOpacity(0.1);
                            }),
                          ),
                          onPressed: () {
                            _liveRoomController.danmakuSwitch.value =
                                !_liveRoomController.danmakuSwitch.value;
                          },
                          icon: Icon(
                            _liveRoomController.danmakuSwitch.value
                                ? Icons.subtitles_outlined
                                : Icons.subtitles_off_outlined,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _liveRoomController.inputController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '发送弹幕',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: IconButton(
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                        ),
                        onPressed: () => _liveRoomController.sendMsg(),
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (Platform.isAndroid) {
      return PiPSwitcher(
        childWhenDisabled: childWhenDisabled,
        childWhenEnabled: videoPlayerPanel,
        floating: floating,
      );
    } else {
      return childWhenDisabled;
    }
  }
}

Widget buildMessageListUI(
  BuildContext context,
  LiveRoomController liveRoomController,
  ScrollController scrollController,
) {
  return Obx(
    () => MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.5),
              Colors.black,
            ],
            stops: const [0.01, 0.05, 0.2],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: GestureDetector(
          onTap: () {
            // 键盘失去焦点
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: ListView.builder(
            controller: scrollController,
            itemCount: liveRoomController.messageList.length,
            itemBuilder: (context, index) {
              final LiveMessageModel liveMsgItem =
                  liveRoomController.messageList[index];
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: liveRoomController.isPortrait.value
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                  ),
                  margin: EdgeInsets.only(
                    top: index == 0 ? 20.0 : 0.0,
                    bottom: 6.0,
                    left: 14.0,
                    right: 14.0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 3.0,
                    horizontal: 10.0,
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        TextSpan(
                          text: '${liveMsgItem.userName}: ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // 处理点击事件
                              print('Text clicked');
                            },
                        ),
                        TextSpan(
                          children: [
                            ...buildMessageTextSpan(context, liveMsgItem)
                          ],
                          // text: liveMsgItem.message,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

List<InlineSpan> buildMessageTextSpan(
  BuildContext context,
  LiveMessageModel liveMsgItem,
) {
  final List<InlineSpan> inlineSpanList = [];

  // 是否包含表情包
  if (liveMsgItem.emots == null) {
    // 没有表情包的消息
    inlineSpanList.add(
      TextSpan(text: liveMsgItem.message ?? ''),
    );
  } else {
    // 有表情包的消息 使用正则匹配 表情包用图片渲染
    final List<String> emotsKeys = liveMsgItem.emots!.keys.toList();
    final RegExp pattern = RegExp(emotsKeys.map(RegExp.escape).join('|'));

    liveMsgItem.message?.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        final emoteItem = liveMsgItem.emots![match.group(0)];
        if (emoteItem != null) {
          inlineSpanList.add(
            WidgetSpan(
              child: NetworkImgLayer(
                // 接口里 width/height 可能是 null 或字符串，直接 toDouble 会崩
                width: double.tryParse('${emoteItem['width'] ?? ''}') ?? 20,
                height: double.tryParse('${emoteItem['height'] ?? ''}') ?? 20,
                type: 'emote',
                src: emoteItem['url'] is String ? emoteItem['url'] : null,
              ),
            ),
          );
        }
        return '';
      },
      onNonMatch: (String nonMatch) {
        inlineSpanList.add(
          TextSpan(text: nonMatch),
        );
        return nonMatch;
      },
    );
  }

  return inlineSpanList;
}
