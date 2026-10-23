import 'package:hive/hive.dart';
import 'package:pilipala/http/user.dart';

import 'storage.dart';

class Data {
  static Future init() async {
    await historyStatus();
  }

  static Future historyStatus() async {
    Box localCache = GStrorage.localCache;
    Box userInfoCache = GStrorage.userInfo;
    if (userInfoCache.get('userInfoCache') == null) {
      return;
    }
    try {
      var res = await UserHttp.historyStatus();
      // 接口失败时 data 为 null，直接写入会把「暂停记录历史」开关覆盖成 null
      if (res.data['code'] == 0 && res.data['data'] != null) {
        localCache.put(LocalCacheKey.historyPause, res.data['data']);
      }
    } catch (err) {
      print('historyStatus error: $err');
    }
  }
}
