import 'dart:async';
import 'dart:io';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/http/video.dart';
import 'package:pilipala/models/common/reply_type.dart';
import 'package:pilipala/models/common/search_type.dart';
import 'package:pilipala/models/video/later.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/models/video/reply/item.dart';
import 'package:pilipala/pages/video/detail/reply_reply/index.dart';
import 'package:pilipala/plugin/pl_player/index.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:pilipala/utils/utils.dart';
import 'package:pilipala/utils/video_utils.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../models/video/subTitile/content.dart';
import '../../../http/danmaku.dart';
import '../../../plugin/pl_player/models/bottom_control_type.dart';
import '../../../utils/id_utils.dart';
import 'introduction/controller.dart';
import 'reply/controller.dart';
import 'widgets/header_control.dart';
import 'widgets/watch_later_list.dart';

class VideoDetailController extends GetxController
    with GetSingleTickerProviderStateMixin {
  /// 路由传参
  String bvid = Get.parameters['bvid']!;
  RxInt cid = int.parse(Get.parameters['cid']!).obs;
  RxInt danmakuCid = 0.obs;
  String heroTag = Get.arguments['heroTag'];
  // 视频详情
  Map videoItem = {};
  // 视频类型 默认投稿视频
  SearchType videoType = Get.arguments['videoType'] ?? SearchType.video;
  // 页面来源 稍后再看 收藏夹
  RxString sourceType = 'normal'.obs;

  /// tabs相关配置
  late TabController tabCtr;
  RxList<String> tabs = <String>['简介', '评论'].obs;

  // 请求返回的视频信息
  late PlayUrlModel data;
  // 请求状态
  RxBool isLoading = false.obs;

  /// 播放器配置 画质 音质 解码格式
  late VideoQuality currentVideoQa;
  AudioQuality? currentAudioQa;
  VideoDecodeFormats? currentDecodeFormats;
  // 是否开始自动播放 存在多p的情况下，第二p需要为true
  RxBool autoPlay = true.obs;
  // 视频资源是否有效
  RxBool isEffective = true.obs;
  // 封面图的展示
  RxBool isShowCover = true.obs;
  // 硬解
  RxBool enableHA = false.obs;

  /// 本地存储
  Box userInfoCache = GStrorage.userInfo;
  Box localCache = GStrorage.localCache;
  Box setting = GStrorage.setting;

  RxInt oid = 0.obs;
  // 评论id 请求楼中楼评论使用
  int fRpid = 0;

  ReplyItemModel? firstFloor;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  RxString bgCover = ''.obs;
  RxString cover = ''.obs;
  PlPlayerController plPlayerController = PlPlayerController();
  // 本页是否已释放播放器。view.dispose 与 GetX 路由 onClose 都会在退出页面时执行，
  // 两处统一走 releasePlayer()，保证一个页面只把全局播放器计数减一次（否则 A→B→返回A 时
  // 计数会被多减，共享播放器被提前销毁，返回 A 后 setDataSource 永远 loading）。
  bool _playerReleased = false;

  /// 释放播放器（幂等），view.dispose 与 onClose 都调用这里
  void releasePlayer() {
    if (_playerReleased) return;
    _playerReleased = true;
    plPlayerController.dispose();
  }

  late VideoItem firstVideo;
  late AudioItem firstAudio;
  late String videoUrl;
  late String audioUrl;
  late Duration defaultST;
  // 亮度
  double? brightness;
  // 默认记录历史记录
  bool enableHeart = true;
  var userInfo;
  late bool isFirstTime = true;
  Floating? floating;
  late PreferredSizeWidget headerControl;

  late bool enableCDN;
  late int? cacheVideoQa;
  late String cacheDecode;
  late int defaultAudioQa;

  PersistentBottomSheetController? replyReplyBottomSheetCtr;
  RxList<SubTitileContentModel> subtitleContents =
      <SubTitileContentModel>[].obs;
  late bool enableRelatedVideo;
  List subtitles = [];
  RxList<BottomControlType> bottomList = [
    BottomControlType.playOrPause,
    BottomControlType.time,
    BottomControlType.space,
    BottomControlType.fit,
    BottomControlType.fullscreen,
  ].obs;
  RxDouble sheetHeight = 0.0.obs;
  RxString archiveSourceType = 'dash'.obs;
  ScrollController? replyScrollController;
  List<MediaVideoItemModel> mediaList = <MediaVideoItemModel>[];
  RxBool isWatchLaterVisible = false.obs;
  RxString watchLaterTitle = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final Map argMap = Get.arguments;
    userInfo = userInfoCache.get('userInfoCache');
    if (argMap.containsKey('videoItem')) {
      var args = argMap['videoItem'];
      updateCover(args.pic);
    } else if (argMap.containsKey('pic')) {
      updateCover(argMap['pic']);
    }

    tabCtr = TabController(length: 2, vsync: this);
    autoPlay.value =
        setting.get(SettingBoxKey.autoPlayEnable, defaultValue: true);
    enableHA.value = setting.get(SettingBoxKey.enableHA, defaultValue: false);
    enableRelatedVideo =
        setting.get(SettingBoxKey.enableRelatedVideo, defaultValue: true);
    if (userInfo == null ||
        localCache.get(LocalCacheKey.historyPause) == true) {
      enableHeart = false;
    }
    danmakuCid.value = cid.value;

    ///
    if (Platform.isAndroid) {
      floating = Floating();
    }

    // CDN优化
    enableCDN = setting.get(SettingBoxKey.enableCDN, defaultValue: true);
    // 预设的画质
    cacheVideoQa = setting.get(SettingBoxKey.defaultVideoQa);
    // 预设的解码格式
    cacheDecode = setting.get(SettingBoxKey.defaultDecode,
        defaultValue: VideoDecodeFormats.values.last.code);
    defaultAudioQa = setting.get(SettingBoxKey.defaultAudioQa,
        defaultValue: AudioQuality.hiRes.code);
    oid.value = IdUtils.bv2av(Get.parameters['bvid']!);
    getSubtitle();
    headerControl = HeaderControl(
      controller: plPlayerController,
      videoDetailCtr: this,
      floating: floating,
      bvid: bvid,
      videoType: videoType,
    );

    sourceType.value = argMap['sourceType'] ?? 'normal';
    isWatchLaterVisible.value =
        sourceType.value == 'watchLater' || sourceType.value == 'fav';
    if (sourceType.value == 'watchLater') {
      watchLaterTitle.value = '稍后再看';
      fetchMediaList();
    }
    if (sourceType.value == 'fav') {
      watchLaterTitle.value = argMap['favTitle'];
      queryFavVideoList();
    }
    tabCtr.addListener(onTabChanged);
  }

  showReplyReplyPanel(oid, fRpid, firstFloor, currentReply, loadMore) {
    replyReplyBottomSheetCtr =
        scaffoldKey.currentState?.showBottomSheet((BuildContext context) {
      return VideoReplyReplyPanel(
        oid: oid,
        rpid: fRpid,
        closePanel: () => {
          fRpid = 0,
        },
        firstFloor: firstFloor,
        replyType: ReplyType.video,
        source: 'videoDetail',
        sheetHeight: sheetHeight.value,
        currentReply: currentReply,
        loadMore: loadMore,
      );
    });
    replyReplyBottomSheetCtr?.closed.then((value) {
      fRpid = 0;
    });
  }

  /// 更新画质、音质
  /// TODO 继续进度播放
  /// [fromDecodeSwitch] 为 true 表示这次重建是「用户切换解码格式」触发的：
  /// 只有这种场景才允许为了让所选编码有片源而切换画质（例如 DVH1 只存在于
  /// qn=126）。切换画质/音质时不带这个参数，否则用户会永远被锁在 126 画质上。
  Future updatePlayer({bool fromDecodeSwitch = false}) async {
    defaultST = plPlayerController.position.value;
    plPlayerController.removeListeners();
    plPlayerController.isBuffering.value = false;
    plPlayerController.buffered.value = Duration.zero;

    if (archiveSourceType.value == 'dash') {
      /// 根据currentVideoQa和currentDecodeFormats 重新设置videoUrl
      final List<VideoItem> allVideos = data.dash?.video ?? const <VideoItem>[];
      List<VideoItem> videoList =
          allVideos.where((i) => i.id == currentVideoQa.code).toList();
      if (videoList.isEmpty) {
        // 当前清晰度不在本次返回的 dash 列表中（会员/接口未返回该清晰度）：
        // 恢复监听后提示并返回，避免下方 firstWhere 抛 StateError 让播放器卡在旧状态
        plPlayerController.startListeners();
        SmartDialog.showToast('该清晰度暂不可用，请选择其他清晰度');
        return;
      }
      // currentDecodeFormats/codecs 都可能为 null（会员画质、部分接口不返回编码格式），
      // 直接 ?.code 传给 startsWith 会在裸类型下抛 TypeError
      final String decodeCode = currentDecodeFormats?.code ?? '';

      /// 找出所选解码格式对应的视频流
      VideoItem? selected;
      for (final VideoItem item in videoList) {
        if (currentDecodeFormats != null &&
            VideoDecodeFormatsCode.matches(
                item.codecs, currentDecodeFormats!)) {
          selected = item;
          break;
        }
      }
      // 当前画质下没有该编码：杜比视界（dvh1）只存在于 qn=126 的流里，
      // 所以到完整 dash 列表里再找一次。找到就连同杜比音轨一起切过去，
      // 并明确 toast 告知画质变了 —— 旧代码这里会抛 StateError 然后把
      // currentDecodeFormats 静默改回设置里的默认 AVC，用户看到的就是
      // 「选了 DVH1 直接被打回 AVC」（Bug 2）。
      if (selected == null && fromDecodeSwitch && decodeCode.isNotEmpty) {
        for (final VideoItem item in allVideos) {
          if (VideoDecodeFormatsCode.matches(
              item.codecs, currentDecodeFormats!)) {
            selected = item;
            break;
          }
        }
        if (selected != null) {
          final VideoQuality? targetQa =
              VideoQualityCode.fromCode(selected.id ?? -1);
          if (targetQa != null && targetQa != currentVideoQa) {
            currentVideoQa = targetQa;
            cacheVideoQa = VideoQualityCode.toCode(targetQa);
            videoList =
                allVideos.where((i) => i.id == targetQa.code).toList();
            SmartDialog.showToast(
                '已切换到${targetQa.description}画质以启用${currentDecodeFormats!.description}解码');
          }
        }
      }
      final String unsupported =
          currentDecodeFormats?.description ?? decodeCode;
      if (selected == null && fromDecodeSwitch) {
        // 用户主动选了某个编码，但片源里确实没有（片源没有 / 账号无权限）：
        // 明确 toast 告知，并把面板上的解码格式同步成「实际正在播的编码」，
        // 避免出现「面板显示 DVH1、实际在播 AVC」这种不自洽的状态，
        // 也不像旧代码那样静默把用户的选择改回默认 AVC。
        String playingCodecs = '';
        try {
          // firstVideo 就是「当前正在播的那条流」，此刻仍是上一次的旧值
          playingCodecs = firstVideo.codecs ?? '';
        } catch (_) {
          // firstVideo 还没初始化过（极端情况）：退化为当前画质的首条流
        }
        currentDecodeFormats =
            VideoDecodeFormatsCode.fromString(playingCodecs) ??
                VideoDecodeFormatsCode.fromString(
                    videoList.first.codecs ?? '') ??
                currentDecodeFormats;
        plPlayerController.startListeners();
        SmartDialog.showToast(
            '当前视频没有 $unsupported 编码的片源，保持${currentDecodeFormats?.description ?? ''}解码');
        return;
      }
      if (selected == null) {
        // 切画质/音质时走到这里：目标画质下没有当前解码格式的流。
        // 此时用户的主要意图是「换画质」，编码应该让位 —— 取该画质下的首条流，
        // 并把解码格式同步成它。否则（例如选了 DVH1 之后）再切画质会被直接拒绝，
        // 看起来就是「画质问不动」。
        selected = videoList.first;
        currentDecodeFormats =
            VideoDecodeFormatsCode.fromString(selected.codecs ?? '') ??
                currentDecodeFormats;
        SmartDialog.showToast(
            '该画质没有 $unsupported 编码的片源，已切换为${currentDecodeFormats?.description ?? ''}解码');
      }
      firstVideo = selected;
      videoUrl = enableCDN
          ? VideoUtils.getCdnUrl(firstVideo)
          : (firstVideo.backupUrl ?? firstVideo.baseUrl ?? '');

      /// 根据currentAudioQa 重新设置audioUrl
      final List<AudioItem> audioList = data.dash?.audio ?? const <AudioItem>[];
      if (audioList.isNotEmpty) {
        AudioItem? selectedAudio;
        // 杜比视界一般配套杜比全景声音轨，优先选它
        if (currentDecodeFormats == VideoDecodeFormats.DVH1) {
          for (final AudioItem item in audioList) {
            if (item.id == AudioQuality.dolby.code) {
              selectedAudio = item;
              break;
            }
          }
        }
        selectedAudio ??= currentAudioQa != null
            ? audioList.firstWhere(
                (AudioItem i) => i.id == currentAudioQa!.code,
                orElse: () => audioList.first,
              )
            : audioList.first;
        audioUrl = enableCDN
            ? VideoUtils.getCdnUrl(selectedAudio)
            : (selectedAudio.backupUrl ?? selectedAudio.baseUrl ?? '');
        if (selectedAudio.id != null) {
          currentAudioQa = AudioQualityCode.fromCode(selectedAudio.id!);
        }
      }
    }

    if (archiveSourceType.value == 'durl') {
      cacheVideoQa = VideoQualityCode.toCode(currentVideoQa);
      // queryVideoUrl 在自动播放时内部会自行初始化播放器，必须 await 它，
      // 否则紧接着的 playerInit 会二次 setDataSource，互相打断（进度重置/封面闪烁）
      await queryVideoUrl();
      if (!autoPlay.value) {
        playerInit();
      }
      return;
    }
    playerInit();
  }

  Future playerInit({
    video,
    audio,
    seekToTime,
    duration,
    bool? autoplay,
  }) async {
    /// 设置/恢复 屏幕亮度
    if (brightness != null) {
      ScreenBrightness().setScreenBrightness(brightness!);
    } else {
      ScreenBrightness().resetScreenBrightness();
    }
    await plPlayerController.setDataSource(
      DataSource(
        videoSource: video ?? videoUrl,
        audioSource: audio ?? audioUrl,
        type: DataSourceType.network,
        httpHeaders: {
          'user-agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15',
          'referer': HttpString.baseUrl
        },
      ),
      // 硬解
      enableHA: enableHA.value,
      seekTo: seekToTime ?? defaultST,
      duration: duration ?? Duration(milliseconds: data.timeLength ?? 0),
      // 宽>高 水平 否则 垂直
      direction: firstVideo.width != null && firstVideo.height != null
          ? ((firstVideo.width! - firstVideo.height!) > 0
              ? 'horizontal'
              : 'vertical')
          : null,
      bvid: bvid,
      cid: cid.value,
      enableHeart: enableHeart,
      isFirstTime: isFirstTime,
      autoplay: autoplay ?? autoPlay.value,
    );

    /// 开启自动全屏时，在player初始化完成后立即传入headerControl
    plPlayerController.headerControl = headerControl;

    plPlayerController.subtitles.value = subtitles;
  }

  // 视频链接
  Future queryVideoUrl() async {
    var result =
        await VideoHttp.videoUrl(cid: cid.value, bvid: bvid, qn: cacheVideoQa);
    if (result['status']) {
      data = result['data'];
      if (data.acceptDesc!.isNotEmpty && data.acceptDesc!.contains('试看')) {
        SmartDialog.showToast(
          '该视频为专属视频，仅提供试看',
          displayTime: const Duration(seconds: 3),
        );
        videoUrl = data.durl!.first.url!;
        audioUrl = '';
        defaultST = Duration.zero;
        firstVideo = VideoItem();
        if (autoPlay.value) {
          await playerInit();
          isShowCover.value = false;
        }
        return result;
      }
      if (data.durl != null) {
        archiveSourceType.value = 'durl';
        videoUrl = data.durl!.first.url!;
        audioUrl = '';
        defaultST = Duration.zero;
        firstVideo = VideoItem();
        currentVideoQa = VideoQualityCode.fromCode(data.quality!)!;
        if (autoPlay.value) {
          await playerInit();
          isShowCover.value = false;
        }
        return result;
      }
      final List<VideoItem> allVideosList = data.dash!.video!;
      try {
        archiveSourceType.value = 'dash';
        // 当前可播放的最高质量视频
        int currentHighVideoQa = allVideosList.first.quality!.code;
        // 预设的画质为null，则当前可用的最高质量
        cacheVideoQa ??= currentHighVideoQa;
        int resVideoQa = currentHighVideoQa;
        if (cacheVideoQa! <= currentHighVideoQa) {
          // 如果预设的画质低于当前最高
          final List<int> numbers = data.acceptQuality!
              .where((e) => e <= currentHighVideoQa)
              .toList();
          resVideoQa = Utils.findClosestNumber(cacheVideoQa!, numbers);
        }
        currentVideoQa = VideoQualityCode.fromCode(resVideoQa)!;

        /// 取出符合当前画质的videoList
        final List<VideoItem> videosList =
            allVideosList.where((e) => e.quality!.code == resVideoQa).toList();

        /// 优先顺序 设置中指定解码格式 -> 当前可选的首个解码格式
        final List<FormatItem> supportFormats = data.supportFormats ?? <FormatItem>[];
        // 根据画质选编码格式。接口偶尔不会返回所选画质的 supportFormats 条目，
        // 原来裸 firstWhere 会抛 StateError，被外层 catch 吞掉后视频直接不加载，
        // 这里退化为首个可用格式，保证还能播。
        final FormatItem matchedFormat = supportFormats.firstWhere(
          (e) => e.quality == resVideoQa,
          orElse: () =>
              supportFormats.isNotEmpty ? supportFormats.first : FormatItem(),
        );
        final List supportDecodeFormats = matchedFormat.codecs ?? <dynamic>[];
        // 默认从设置中取解码格式（fromString 现在解析不出来会返回 null，
        // 需要显式兜底，不能再依赖它「默认 DVH1」）
        currentDecodeFormats = VideoDecodeFormatsCode.fromString(cacheDecode) ??
            VideoDecodeFormatsCode.fromCode(
                VideoDecodeFormats.values.last.code);
        // 当前视频没有对应格式就退化为接口返回的第一个可用格式
        final bool decodeSupported = supportDecodeFormats.any((i) =>
            VideoDecodeFormatsCode.matches(i.toString(), currentDecodeFormats!));
        if (!decodeSupported) {
          for (final dynamic i in supportDecodeFormats) {
            final VideoDecodeFormats? matched =
                VideoDecodeFormatsCode.fromString(i.toString());
            if (matched != null) {
              currentDecodeFormats = matched;
              break;
            }
          }
        }

        /// 取出符合当前解码格式的videoItem
        firstVideo = videosList.firstWhere(
          (e) => VideoDecodeFormatsCode.matches(
              e.codecs, currentDecodeFormats!),
          orElse: () => videosList.first,
        );
        // 走到 orElse 说明该画质没有所选编码：把 UI 上的解码格式同步成真实
        // 在播的流，避免面板显示 AVC 而实际是 HEVC（或反过来）
        if (!VideoDecodeFormatsCode.matches(
            firstVideo.codecs, currentDecodeFormats!)) {
          currentDecodeFormats = VideoDecodeFormatsCode.fromString(
                  firstVideo.codecs ?? '') ??
              currentDecodeFormats;
        }
        videoUrl = enableCDN
            ? VideoUtils.getCdnUrl(firstVideo)
            : (firstVideo.backupUrl ?? firstVideo.baseUrl!);
      } catch (err) {
        SmartDialog.showToast('firstVideo error: $err');
      }

      /// 优先顺序 设置中指定质量 -> 当前可选的最高质量
      late AudioItem? firstAudio;
      // 复制一份再合并杜比/无损音轨：直接 insert 到 data.dash.audio 会让该列表
      // 每次 playerInit 都重复累积，音质面板出现重复项
      final List<AudioItem> audiosList =
          List<AudioItem>.of(data.dash!.audio ?? const <AudioItem>[]);

      try {
        void addAudioIfAbsent(AudioItem? item) {
          if (item == null) return;
          if (audiosList.any((e) => e.id == item.id)) return;
          audiosList.insert(0, item);
        }

        if (data.dash!.dolby?.audio?.isNotEmpty == true) {
          // 杜比
          addAudioIfAbsent(data.dash!.dolby!.audio!.first);
        }

        if (data.dash!.flac?.audio != null) {
          // 无损
          addAudioIfAbsent(data.dash!.flac!.audio);
        }

        // 音质选择面板读取的是 dash.audio，这里同步一次去重后的列表
        data.dash!.audio = audiosList;

        if (audiosList.isNotEmpty) {
          final List<int> numbers = audiosList.map((map) => map.id!).toList();
          int closestNumber = Utils.findClosestNumber(defaultAudioQa, numbers);
          if (!numbers.contains(defaultAudioQa) &&
              numbers.any((e) => e > defaultAudioQa)) {
            closestNumber = 30280;
          }
          firstAudio = audiosList.firstWhere((e) => e.id == closestNumber);
        } else {
          firstAudio = AudioItem();
        }
      } catch (err) {
        firstAudio = audiosList.isNotEmpty ? audiosList.first : AudioItem();
        SmartDialog.showToast('firstAudio error: $err');
      }

      audioUrl = enableCDN
          ? VideoUtils.getCdnUrl(firstAudio)
          : (firstAudio.backupUrl ?? firstAudio.baseUrl!);
      //
      if (firstAudio.id != null) {
        currentAudioQa = AudioQualityCode.fromCode(firstAudio.id!)!;
      }
      defaultST = Duration(milliseconds: data.lastPlayTime!);
      if (autoPlay.value) {
        await playerInit();
        isShowCover.value = false;
      }
    } else {
      if (result['code'] == -404) {
        isShowCover.value = false;
      }
      SmartDialog.showToast(result['msg'].toString());
    }
    return result;
  }

  // mob端全屏状态关闭二级回复
  hiddenReplyReplyPanel() {
    replyReplyBottomSheetCtr != null
        ? replyReplyBottomSheetCtr!.close()
        : print('replyReplyBottomSheetCtr is null');
  }

  // 获取字幕配置
  Future getSubtitle() async {
    var result = await VideoHttp.getSubtitle(bvid: bvid, cid: cid.value);
    if (result['status']) {
      if (result['data'].subtitles.isNotEmpty) {
        subtitles = result['data'].subtitles;
        getDanmaku(subtitles);
      }
    }
  }

  // 获取弹幕
  Future getDanmaku(List subtitles) async {
    if (subtitles.isNotEmpty) {
      for (var i in subtitles) {
        final Map<String, dynamic> res = await VideoHttp.getSubtitleContent(
          i.subtitleUrl,
        );
        i.content = res['content'];
        i.body = res['body'];
      }
    }
  }

  setSubtitleContent() {
    plPlayerController.subtitleContent.value = '';
    plPlayerController.subtitles.value = subtitles;
  }

  clearSubtitleContent() {
    plPlayerController.subtitleContent.value = '';
    plPlayerController.subtitles.value = [];
  }

  /// 发送弹幕
  void showShootDanmakuSheet() {
    final TextEditingController textController = TextEditingController();
    bool isSending = false; // 追踪是否正在发送
    BuildContext? dialogContext; // 弹窗内层 context，用于判断弹窗是否已被用户关闭
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        dialogContext = context;
        // TODO: 支持更多类型和颜色的弹幕
        return AlertDialog(
          title: const Text('发送弹幕'),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return TextField(
              controller: textController,
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return TextButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final String msg = textController.text;
                        if (msg.isEmpty) {
                          SmartDialog.showToast('弹幕内容不能为空');
                          return;
                        } else if (msg.length > 100) {
                          SmartDialog.showToast('弹幕内容不能超过100个字符');
                          return;
                        }
                        if (dialogContext?.mounted ?? false) {
                          setState(() {
                            isSending = true; // 开始发送，更新状态
                          });
                        }
                        //修改按钮文字
                        // SmartDialog.showToast('弹幕发送中,\n$msg');
                        final dynamic res = await DanmakaHttp.shootDanmaku(
                          oid: cid.value,
                          msg: textController.text,
                          bvid: bvid,
                          progress:
                              plPlayerController.position.value.inMilliseconds,
                          type: 1,
                        );
                        // 弹窗已被用户关闭（点空白/取消）：不再 setState，也不再继续提示或关闭页面，
                        // 否则会抛 setState() after dispose()，且 Get.back() 会把视频详情页一起 pop 掉
                        if (!(dialogContext?.mounted ?? false)) {
                          return;
                        }
                        setState(() {
                          isSending = false; // 发送结束，更新状态
                        });
                        if (res['status']) {
                          SmartDialog.showToast('发送成功');
                          // 发送成功，自动预览该弹幕，避免重新请求
                          // TODO: 暂停状态下预览弹幕仍会移动与计时，可考虑添加到dmSegList或其他方式实现
                          plPlayerController.danmakuController?.addItems([
                            DanmakuItem(
                              msg,
                              color: Colors.white,
                              time: plPlayerController
                                  .position.value.inMilliseconds,
                              type: DanmakuItemType.scroll,
                              isSend: true,
                            )
                          ]);
                          Get.back();
                        } else {
                          SmartDialog.showToast('发送失败，错误信息为${res['msg']}');
                        }
                      },
                child: Text(isSending ? '发送中...' : '发送'),
              );
            })
          ],
        );
      },
    ).then((_) {
      // 弹窗关闭后释放输入框控制器
      textController.dispose();
    });
  }

  void updateCover(String? pic) {
    if (pic != null) {
      cover.value = videoItem['pic'] = pic;
    }
  }

  void onControllerCreated(ScrollController controller) {
    replyScrollController = controller;
  }

  void onTapTabbar(int index) {
    if (tabCtr.animation!.isCompleted && index == 1 && tabCtr.index == 1) {
      replyScrollController?.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  void toggeleWatchLaterVisible(bool val) {
    if (sourceType.value == 'watchLater' || sourceType.value == 'fav') {
      isWatchLaterVisible.value = !isWatchLaterVisible.value;
    }
  }

  // 获取稍后再看列表
  Future fetchMediaList() async {
    final Map argMap = Get.arguments;
    var count = argMap['count'];
    var res = await UserHttp.getMediaList(
      type: 2,
      bizId: userInfo.mid,
      ps: count,
    );
    if (res['status']) {
      mediaList = res['data'].reversed.toList();
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  // 稍后再看面板展开
  showMediaListPanel() {
    replyReplyBottomSheetCtr =
        scaffoldKey.currentState?.showBottomSheet((BuildContext context) {
      return MediaListPanel(
        sheetHeight: sheetHeight.value,
        mediaList: mediaList,
        changeMediaList: changeMediaList,
        panelTitle: watchLaterTitle.value,
        bvid: bvid,
        mediaId: Get.arguments['mediaId'],
        hasMore: mediaList.length != Get.arguments['count'],
      );
    });
    replyReplyBottomSheetCtr?.closed.then((value) {
      isWatchLaterVisible.value = true;
    });
  }

  // 切换稍后再看
  Future changeMediaList(bvidVal, cidVal, aidVal, coverVal) async {
    final VideoIntroController videoIntroCtr =
        Get.find<VideoIntroController>(tag: heroTag);
    bvid = bvidVal;
    oid.value = aidVal ?? IdUtils.bv2av(bvid);
    cid.value = cidVal;
    danmakuCid.value = cidVal;
    cover.value = coverVal;
    queryVideoUrl();
    clearSubtitleContent();
    await getSubtitle();
    setSubtitleContent();
    // 重新请求评论
    try {
      /// 未渲染回复组件时可能异常
      final VideoReplyController videoReplyCtr =
          Get.find<VideoReplyController>(tag: heroTag);
      videoReplyCtr.aid = aidVal;
      videoReplyCtr.queryReplyList(type: 'init');
    } catch (_) {}
    videoIntroCtr.lastPlayCid.value = cidVal;
    videoIntroCtr.bvid = bvidVal;
    replyReplyBottomSheetCtr!.close();
    await videoIntroCtr.queryVideoIntro();
  }

  // 获取收藏夹视频列表
  Future queryFavVideoList() async {
    final Map argMap = Get.arguments;
    var mediaId = argMap['mediaId'];
    var oid = argMap['oid'];
    var res = await UserHttp.parseFavVideo(
      mediaId: mediaId,
      oid: oid,
      bvid: bvid,
    );
    if (res['status']) {
      mediaList = res['data'];
    }
  }

  // 监听tabBarView切换
  void onTabChanged() {
    isWatchLaterVisible.value = tabCtr.index == 0;
  }

  @override
  void onClose() {
    super.onClose();
    releasePlayer();
    tabCtr.removeListener(onTabChanged);
    tabCtr.dispose();
  }
}
