import 'package:flutter/foundation.dart';
import 'package:pilipala/http/danmaku.dart';
import 'package:pilipala/models/danmaku/dm.pb.dart';

class PlDanmakuController {
  PlDanmakuController(this.cid, this.type, {this.offlineSegMap});
  final int cid;
  final String type;

  /// 离线下载好的弹幕（key 为段号，从 1 开始），命中后不再联网请求
  final Map<int, List<DanmakuElem>>? offlineSegMap;

  bool get isOffline => offlineSegMap != null && offlineSegMap!.isNotEmpty;
  Map<int, List<DanmakuElem>> dmSegMap = {};
  // 已请求的段落标记
  List<bool> requestedSeg = [];

  bool get initiated => requestedSeg.isNotEmpty;

  static int segmentLength = 60 * 6 * 1000;

  void initiate(int videoDuration, int progress) {
    if (requestedSeg.isEmpty) {
      int segCount = (videoDuration / segmentLength).ceil();
      requestedSeg = List<bool>.generate(segCount, (index) => false);
    }
    try {
      queryDanmaku(calcSegment(progress));
    } catch (e) {
      print(e);
    }
  }

  void dispose() {
    dmSegMap.clear();
    requestedSeg.clear();
  }

  int calcSegment(int progress) {
    return progress ~/ segmentLength;
  }

  void queryDanmaku(int segmentIndex) async {
    // 视频时长未知（duration 为 0）或进度超出已知段落数时，
    // requestedSeg 为空/越界，直接下标访问会 RangeError。
    if (segmentIndex < 0 || segmentIndex >= requestedSeg.length) {
      return;
    }
    if (requestedSeg[segmentIndex]) {
      return;
    }
    requestedSeg[segmentIndex] = true;

    // 离线缓存优先：直接使用本地已下载的弹幕，不发起网络请求
    final List<DanmakuElem>? offline = offlineSegMap?[segmentIndex + 1];
    if (offline != null) {
      for (final DanmakuElem element in offline) {
        final int pos = element.progress ~/ 100;
        dmSegMap[pos] ??= <DanmakuElem>[];
        dmSegMap[pos]!.add(element);
      }
      return;
    }

    try {
      final DmSegMobileReply result = await DanmakaHttp.queryDanmaku(
          cid: cid, segmentIndex: segmentIndex + 1);
      if (result.elems.isNotEmpty) {
        for (var element in result.elems) {
          int pos = element.progress ~/ 100; //每0.1秒存储一次
          if (dmSegMap[pos] == null) {
            dmSegMap[pos] = [];
          }
          dmSegMap[pos]!.add(element);
        }
      }
    } catch (e) {
      // 网络异常时避免未捕获的异步异常，允许下次进入该段时重试
      requestedSeg[segmentIndex] = false;
      debugPrint('$e');
    }
  }

  List<DanmakuElem>? getCurrentDanmaku(int progress) {
    if (requestedSeg.isEmpty) {
      return null;
    }
    int segmentIndex = calcSegment(progress);
    if (segmentIndex < 0 || segmentIndex >= requestedSeg.length) {
      return null;
    }
    if (!requestedSeg[segmentIndex]) {
      queryDanmaku(segmentIndex);
    }
    return dmSegMap[progress ~/ 100];
  }
}
