import 'package:hive/hive.dart';
import 'package:pilipala/models/user/info.dart';
import 'package:pilipala/plugin/pl_player/models/play_repeat.dart';
import 'package:pilipala/plugin/pl_player/models/play_speed.dart';
import 'package:pilipala/utils/storage.dart';
import '../models/common/index.dart';

Box setting = GStrorage.setting;
Box localCache = GStrorage.localCache;
Box videoStorage = GStrorage.video;
Box userInfoCache = GStrorage.userInfo;

// 全部字段都带默认值：initialize() 是异步的，而首帧 Widget 可能先于它完成
// （例如 NetworkImgLayer 读 imgQuality），此前会抛 LateInitializationError。
class GlobalDataCache {
  int imgQuality = 10;
  FullScreenGestureMode fullScreenGestureMode = FullScreenGestureMode.values.last;
  bool enablePlayerControlAnimation = true;
  List<String> actionTypeSort = <String>[
    'like',
    'coin',
    'collect',
    'watchLater',
    'share'
  ];

  /// 播放器相关
  // 弹幕开关
  bool isOpenDanmu = false;
  // 弹幕屏蔽类型
  List<dynamic> blockTypes = <dynamic>[];
  // 弹幕展示区域
  double showArea = 0.5;
  // 弹幕透明度
  double opacityVal = 1.0;
  // 弹幕字体大小
  double fontSizeVal = 1.0;
  // 弹幕显示时间
  double danmakuDurationVal = 4.0;
  // 弹幕描边宽度
  double strokeWidth = 1.5;
  // 播放器循环模式
  PlayRepeat playRepeat = PlayRepeat.pause;
  // 播放器默认播放速度
  double playbackSpeed = 1.0;
  // 播放器自动长按速度
  bool enableAutoLongPressSpeed = false;
  // 播放器长按速度
  double longPressSpeed = 2.0;
  // 播放器速度列表
  List<double> speedsList = <double>[];
  // 用户信息
  UserInfoData? userInfo;

  // 私有构造函数
  GlobalDataCache._();

  // 单例实例
  static final GlobalDataCache _instance = GlobalDataCache._();

  // 获取全局实例
  factory GlobalDataCache() => _instance;

  // 异步初始化方法
  Future<void> initialize() async {
    imgQuality = await setting.get(SettingBoxKey.defaultPicQa,
        defaultValue: 10); // 设置全局变量
    final int gestureIndex = setting.get(SettingBoxKey.fullScreenGestureMode,
        defaultValue: FullScreenGestureMode.values.last.index) as int;
    fullScreenGestureMode =
        (gestureIndex >= 0 && gestureIndex < FullScreenGestureMode.values.length)
            ? FullScreenGestureMode.values[gestureIndex]
            : FullScreenGestureMode.values.last;
    enablePlayerControlAnimation = setting
        .get(SettingBoxKey.enablePlayerControlAnimation, defaultValue: true);
    // Hive 反序列化出的 List 元素是 dynamic，直接赋给 List<String> 会 CastError
    actionTypeSort = List<String>.from(await setting.get(
        SettingBoxKey.actionTypeSort,
        defaultValue: ['like', 'coin', 'collect', 'watchLater', 'share']));

    isOpenDanmu =
        await setting.get(SettingBoxKey.enableShowDanmaku, defaultValue: false);
    blockTypes =
        await localCache.get(LocalCacheKey.danmakuBlockType, defaultValue: []);
    showArea =
        await localCache.get(LocalCacheKey.danmakuShowArea, defaultValue: 0.5);
    opacityVal =
        await localCache.get(LocalCacheKey.danmakuOpacity, defaultValue: 1.0);
    fontSizeVal =
        await localCache.get(LocalCacheKey.danmakuFontScale, defaultValue: 1.0);
    danmakuDurationVal =
        await localCache.get(LocalCacheKey.danmakuDuration, defaultValue: 4.0);
    strokeWidth =
        await localCache.get(LocalCacheKey.strokeWidth, defaultValue: 1.5);

    var defaultPlayRepeat = await videoStorage.get(VideoBoxKey.playRepeat,
        defaultValue: PlayRepeat.pause.value);
    playRepeat = PlayRepeat.values.toList().firstWhere(
        (e) => e.value == defaultPlayRepeat,
        orElse: () => PlayRepeat.pause);
    playbackSpeed =
        await videoStorage.get(VideoBoxKey.playSpeedDefault, defaultValue: 1.0);
    enableAutoLongPressSpeed = await setting
        .get(SettingBoxKey.enableAutoLongPressSpeed, defaultValue: false);
    if (!enableAutoLongPressSpeed) {
      longPressSpeed = await videoStorage.get(VideoBoxKey.longPressSpeedDefault,
          defaultValue: 2.0);
    } else {
      longPressSpeed = 2.0;
    }
    speedsList = List<double>.from(await videoStorage
        .get(VideoBoxKey.customSpeedsList, defaultValue: <double>[]));
    final List<double> playSpeedSystem = await videoStorage
        .get(VideoBoxKey.playSpeedSystem, defaultValue: playSpeed);
    speedsList.addAll(playSpeedSystem);

    userInfo = userInfoCache.get('userInfoCache');
  }
}
