import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/common/widgets/custom_toast.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/models/common/color_type.dart';
import 'package:pilipala/models/common/theme_type.dart';
import 'package:pilipala/pages/search/index.dart';
import 'package:pilipala/pages/video/detail/index.dart';
import 'package:pilipala/router/app_pages.dart';
import 'package:pilipala/pages/main/view.dart';
import 'package:pilipala/services/service_locator.dart';
import 'package:pilipala/utils/app_scheme.dart';
import 'package:pilipala/utils/data.dart';
import 'package:pilipala/utils/global_data_cache.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pilipala/utils/recommend_filter.dart';
import 'package:catcher_2/catcher_2.dart';
import './services/loggeer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await GStrorage.init();
  clearLogs();
  Request();
  await Request.setCookie();

  // 全局缓存必须在 runApp 之前完成初始化：
  // 首帧就会构造 NetworkImgLayer，它读取 GlobalDataCache().imgQuality，
  // 若此时还没初始化会抛 LateInitializationError（首页各图片位报错）。
  await GlobalDataCache().initialize();

  // 异常捕获 logo记录
  final Catcher2Options releaseConfig = Catcher2Options(
    SilentReportMode(),
    [FileHandler(await getLogsPath())],
  );

  Catcher2(
    releaseConfig: releaseConfig,
    runAppFunction: () {
      runApp(const MyApp());
    },
  );

  // 小白条、导航栏沉浸
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 29) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ));
  }

  PiliSchame.init();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Box setting = GStrorage.setting;
    // 主题色（历史值/版本升级可能越界，越界时回退到第一个主题，避免启动白屏）
    final dynamic storedColor =
        setting.get(SettingBoxKey.customColor, defaultValue: 0);
    final int colorIndex =
        storedColor is int && storedColor >= 0 && storedColor < colorThemeTypes.length
            ? storedColor
            : 0;
    Color defaultColor = colorThemeTypes[colorIndex]['color'] as Color;
    Color brandColor = defaultColor;
    // 主题模式（同样防止越界）
    final dynamic storedTheme =
        setting.get(SettingBoxKey.themeMode, defaultValue: ThemeType.system.code);
    ThemeType currentThemeValue =
        storedTheme is int && storedTheme >= 0 && storedTheme < ThemeType.values.length
            ? ThemeType.values[storedTheme]
            : ThemeType.system;
    // 是否动态取色
    bool isDynamicColor =
        setting.get(SettingBoxKey.dynamicColor, defaultValue: true);
    // 字体缩放大小
    double textScale =
        setting.get(SettingBoxKey.defaultTextScale, defaultValue: 1.0);

    // 强制设置高帧率
    if (Platform.isAndroid) {
      FlutterDisplayMode.supported.then((value) {
        // 异步回调里的异常不会被外层 try 捕获，必须在此处兜住
        try {
          final List modes = value;
          var storageDisplay = setting.get(SettingBoxKey.displayMode);
          DisplayMode f = DisplayMode.auto;
          if (storageDisplay != null) {
            final Iterable matched =
                modes.where((e) => e.toString() == storageDisplay);
            if (matched.isNotEmpty) {
              f = matched.first;
            }
          }
          final Iterable prefer = modes.where((el) => el == f);
          if (prefer.isNotEmpty) {
            FlutterDisplayMode.setPreferredMode(prefer.first);
          }
        } catch (err) {
          print('set display mode error: $err');
        }
      });
    }

    if (Platform.isAndroid) {
      return AndroidApp(
        brandColor: brandColor,
        isDynamicColor: isDynamicColor,
        currentThemeValue: currentThemeValue,
        textScale: textScale,
      );
    } else {
      return OtherApp(
        brandColor: brandColor,
        currentThemeValue: currentThemeValue,
        textScale: textScale,
      );
    }
  }
}

class AndroidApp extends StatelessWidget {
  const AndroidApp({
    super.key,
    required this.brandColor,
    required this.isDynamicColor,
    required this.currentThemeValue,
    required this.textScale,
  });

  final Color brandColor;
  final bool isDynamicColor;
  final ThemeType currentThemeValue;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: ((ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme? lightColorScheme;
        ColorScheme? darkColorScheme;
        if (lightDynamic != null && darkDynamic != null && isDynamicColor) {
          // dynamic取色成功
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // dynamic取色失败，采用品牌色
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: brandColor,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: brandColor,
            brightness: Brightness.dark,
          );
        }
        return BuildMainApp(
          lightColorScheme: lightColorScheme,
          darkColorScheme: darkColorScheme,
          currentThemeValue: currentThemeValue,
          textScale: textScale,
        );
      }),
    );
  }
}

class OtherApp extends StatelessWidget {
  const OtherApp({
    super.key,
    required this.brandColor,
    required this.currentThemeValue,
    required this.textScale,
  });

  final Color brandColor;
  final ThemeType currentThemeValue;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return BuildMainApp(
      lightColorScheme: ColorScheme.fromSeed(
        seedColor: brandColor,
        brightness: Brightness.light,
      ),
      darkColorScheme: ColorScheme.fromSeed(
        seedColor: brandColor,
        brightness: Brightness.dark,
      ),
      currentThemeValue: currentThemeValue,
      textScale: textScale,
    );
  }
}

class BuildMainApp extends StatelessWidget {
  const BuildMainApp({
    super.key,
    required this.lightColorScheme,
    required this.darkColorScheme,
    required this.currentThemeValue,
    required this.textScale,
  });

  final ColorScheme lightColorScheme;
  final ColorScheme darkColorScheme;
  final ThemeType currentThemeValue;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final SnackBarThemeData snackBarTheme = SnackBarThemeData(
      actionTextColor: lightColorScheme.primary,
      backgroundColor: lightColorScheme.secondaryContainer,
      closeIconColor: lightColorScheme.secondary,
      contentTextStyle: TextStyle(color: lightColorScheme.secondary),
      elevation: 20,
    );

    return GetMaterialApp(
      title: 'PiliPala',
      theme: ThemeData(
        colorScheme: currentThemeValue == ThemeType.dark
            ? darkColorScheme
            : lightColorScheme,
        snackBarTheme: snackBarTheme,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: ZoomPageTransitionsBuilder(
              allowEnterRouteSnapshotting: false,
            ),
          },
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: currentThemeValue == ThemeType.light
            ? lightColorScheme
            : darkColorScheme,
        snackBarTheme: snackBarTheme,
      ),
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      locale: const Locale("zh", "CN"),
      supportedLocales: const [Locale("zh", "CN"), Locale("en", "US")],
      fallbackLocale: const Locale("zh", "CN"),
      getPages: Routes.getPages,
      home: const MainApp(),
      builder: (BuildContext context, Widget? child) {
        return FlutterSmartDialog(
          toastBuilder: (String msg) => CustomToast(msg: msg),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        );
      },
      navigatorObservers: [
        VideoDetailPage.routeObserver,
        SearchPage.routeObserver,
      ],
      onReady: () async {
        RecommendFilter();
        Data.init();
        setupServiceLocator();
      },
    );
  }
}
