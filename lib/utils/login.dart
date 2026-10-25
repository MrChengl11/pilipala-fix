import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/http/user.dart';
import 'package:pilipala/pages/dynamics/index.dart';
import 'package:pilipala/pages/home/index.dart';
import 'package:pilipala/pages/media/index.dart';
import 'package:pilipala/pages/mine/index.dart';
import 'package:pilipala/utils/cookie.dart';
import 'package:pilipala/utils/global_data_cache.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:uuid/uuid.dart';

class LoginUtils {
  /// 安全获取已注册的控制器。
  ///
  /// 部分控制器只有在对应底部导航项开启 / 页面被构建时才会被 Get.put：
  /// MediaController（媒体库）、DynamicsController（动态）、MineController（我的）。
  /// 登录、退出时的状态同步不能因为它们不存在而抛
  /// `"MediaController" not found. You need to call "Get.put(MediaController())"`，
  /// 否则登录成功也会弹出「登录遇到问题」。
  static T? _tryFind<T extends GetxController>() {
    try {
      if (!Get.isRegistered<T>()) {
        return null;
      }
      return Get.find<T>();
    } catch (err) {
      debugPrint('LoginUtils: Get.find<$T>() failed: $err');
      return null;
    }
  }

  static Future refreshLoginStatus(bool status) async {
    try {
      final MineController? mineCtr = _tryFind<MineController>();

      // 更改我的页面登录状态
      if (mineCtr != null) {
        await mineCtr.resetUserInfo();
      }

      // 更改主页登录状态
      final HomeController? homeCtr = _tryFind<HomeController>();
      if (homeCtr != null) {
        homeCtr.updateLoginStatus(status);
      }

      if (mineCtr != null) {
        mineCtr.userLogin.value = status;
      }

      final DynamicsController? dynamicsCtr = _tryFind<DynamicsController>();
      if (dynamicsCtr != null) {
        dynamicsCtr.userLogin.value = status;
      }

      final MediaController? mediaCtr = _tryFind<MediaController>();
      if (mediaCtr != null) {
        mediaCtr.userLogin.value = status;
      }
    } catch (err) {
      // 状态同步失败不影响登录/退出结果，只记录日志，不打扰用户
      debugPrint('LoginUtils.refreshLoginStatus error: $err');
    }
  }

  static String buvid() {
    var mac = <String>[];
    var random = Random();

    for (var i = 0; i < 6; i++) {
      var min = 0;
      var max = 0xff;
      var num = (random.nextInt(max - min + 1) + min).toRadixString(16);
      mac.add(num);
    }

    var md5Str = md5.convert(utf8.encode(mac.join(':'))).toString();
    var md5Arr = md5Str.split('');
    return 'XY${md5Arr[2]}${md5Arr[12]}${md5Arr[22]}$md5Str';
  }

  static String getUUID() {
    return const Uuid().v4().replaceAll('-', '');
  }

  static String generateBuvid() {
    String uuid = getUUID() + getUUID();
    return 'XY${uuid.substring(0, 35).toUpperCase()}';
  }

  static confirmLogin(url, controller) async {
    var content = '';
    if (url != null) {
      content = '${content + url}; \n';
    }
    try {
      await SetCookie.onSet();
      final result = await UserHttp.userInfo();
      if (result['status'] && result['data'].isLogin) {
        SmartDialog.showToast('登录成功');
        // 注意：走到这里登录已经成功。
        // 之后的缓存/请求头/控制器状态同步属于「尽力而为」的后置刷新，
        // 任何失败（例如媒体库 tab 未开启时 MediaController 未注册）都不能
        // 再弹「登录遇到问题」弹窗，否则用户会看到登录失败但实际已登录。
        try {
          Box userInfoCache = GStrorage.userInfo;
          if (!userInfoCache.isOpen) {
            userInfoCache = await Hive.openBox('userInfo');
          }
          await userInfoCache.put('userInfoCache', result['data']);
          // 登录后立刻同步缓存与请求头，否则不重启应用时：
          // GlobalDataCache().userInfo 仍是 null（自己的评论没有删除入口），
          // x-bili-mid 仍缺失（推荐/风控按未登录处理）。
          GlobalDataCache().refreshUserInfo();
          Request.setOptionsHeaders(result['data'], true);
        } catch (err) {
          debugPrint('LoginUtils.confirmLogin: cache/header sync failed: $err');
        }

        // 控制器状态同步：各自独立，某个控制器未注册不影响其它控制器
        try {
          final HomeController? homeCtr = _tryFind<HomeController>();
          if (homeCtr != null) {
            homeCtr.updateLoginStatus(true);
            homeCtr.userFace.value = result['data'].face;
          }
          final MediaController? mediaCtr = _tryFind<MediaController>();
          if (mediaCtr != null) {
            mediaCtr.mid = result['data'].mid;
          }
        } catch (err) {
          debugPrint('LoginUtils.confirmLogin: controller sync failed: $err');
        }

        try {
          await LoginUtils.refreshLoginStatus(true);
        } catch (err) {
          debugPrint('LoginUtils.confirmLogin: refreshLoginStatus failed: $err');
        }
        Get.back();
      } else {
        // 获取用户信息失败
        SmartDialog.showToast(result['msg']);
        Clipboard.setData(ClipboardData(text: result['msg']));
      }
    } catch (e) {
      SmartDialog.showNotify(msg: e.toString(), notifyType: NotifyType.warning);
      content = content + e.toString();
      Clipboard.setData(ClipboardData(text: content));
    }
  }
}
