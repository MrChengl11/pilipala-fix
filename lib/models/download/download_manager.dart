// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' hide Response;
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pilipala/http/api.dart';
import 'package:pilipala/http/constants.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/http/video.dart';
// dm.pb.dart 里也有一个 Response 类，与 dio 的 Response 冲突，这里显式隐藏
import 'package:pilipala/models/danmaku/dm.pb.dart' hide Response;
import 'package:pilipala/models/download/download_task.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/models/video/play/url.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:pilipala/utils/utils.dart';

/// 离线下载管理器
///
/// 设计要点：
/// 1. 任务表放 Hive box `download`（key = cid 字符串），媒体文件放
///    `<ApplicationSupportDirectory>/offline/<cid>/`，两处互相独立：
///    删任务时可以只删记录、或连文件一起删。
/// 2. 下载器用**独立的 Dio**，不复用 `Request.dio`：后者的
///    ApiInterceptor.onError 会把任何失败弹成 SmartDialog toast，批量
///    分片下载时屏幕会被 toast 淹没。
/// 3. 每路流各自用 Range 续传：断点续传就是「先看本地文件多大，再从
///    那个偏移请求 bytes=N-」。服务端（B 站 CDN）实测返回 206。
/// 4. DASH 音视频分离：video.m4s / audio.m4s 两个文件，播放时靠
///    media_kit 的 audio-files 属性把第二条流挂上去（与线上播放一致）。
Box setting = GStrorage.setting;

class DownloadManager extends GetxController {
  DownloadManager._();

  static DownloadManager? _manager;

  static DownloadManager get instance {
    _manager ??= DownloadManager._();
    return _manager!;
  }

  /// 并发下载任务数
  static const int maxConcurrent = 2;

  /// 弹幕分段长度，与 PlDanmakuController.segmentLength 保持一致
  static const int danmakuSegmentLength = 60 * 6 * 1000;

  static const String _ua =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_3_1) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/16.4 Safari/605.1.15';

  /// 弹幕接口（seg.so）挑 UA：Safari UA 会被风控返回 {"code":-352}，
  /// 必须用桌面 Chrome UA 才拿得到 protobuf。
  static const String _danmakuUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Box<dynamic> _box = GStrorage.download;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      // CDN 会 302 到别的域名，交给 dio 自动跟随
      followRedirects: true,
    ),
  );

  /// 任务列表（按创建时间倒序），UI 直接 Obx 监听
  final RxList<DownloadTask> tasks = <DownloadTask>[].obs;

  /// 正在跑的 cid -> CancelToken
  final Map<int, CancelToken> _tokens = <int, CancelToken>{};
  final Set<int> _running = <int>{};
  final Map<int, int> _lastSaveAt = <int, int>{};

  String _rootPath = '';
  bool _inited = false;

  /// 离线文件根目录（init 之后可用）
  String get rootPath => _rootPath;

  bool get hasRunning => _running.isNotEmpty;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    final Directory support = await getApplicationSupportDirectory();
    _rootPath = support.path + '/offline';
    final Directory root = Directory(_rootPath);
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    final List<DownloadTask> loaded = <DownloadTask>[];
    for (final dynamic value in _box.values) {
      if (value is Map) {
        try {
          final DownloadTask task = DownloadTask.fromMap(value);
          // 进程被杀时残留的「下载中 / 排队中」不能沿用，否则任务永远卡住
          if (task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.waiting) {
            task.status = DownloadStatus.paused;
          }
          loaded.add(task);
        } catch (e) {
          print('DownloadManager: bad task record, skipped:  ' + e.toString());
        }
      }
    }
    loaded.sort((DownloadTask a, DownloadTask b) =>
        b.createdAt.compareTo(a.createdAt));
    tasks.assignAll(loaded);
    print('DownloadManager: loaded ' + loaded.length.toString() + ' task(s)');
  }

  // ---------------------------------------------------------------- 路径

  Future<Directory> _taskDir(int cid) async {
    final Directory root = Directory(_rootPath);
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    final Directory dir = Directory(_rootPath + '/' + cid.toString());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  String videoPathOf(int cid) => _rootPath + '/' + cid.toString() + '/video.m4s';

  String audioPathOf(int cid) => _rootPath + '/' + cid.toString() + '/audio.m4s';

  String danmakuDirOf(int cid) => _rootPath + '/' + cid.toString() + '/danmaku';

  bool hasLocalMedia(int cid) {
    if (_rootPath.isEmpty) return false;
    return File(videoPathOf(cid)).existsSync();
  }

  DownloadTask? taskOf(int cid) {
    for (final DownloadTask t in tasks) {
      if (t.cid == cid) return t;
    }
    return null;
  }

  // ---------------------------------------------------------------- 任务操作

  /// 新建任务。已存在时：已完成则直接返回 null 并提示；未完成则续传。
  Future<DownloadTask?> add({
    required int cid,
    required String bvid,
    required String title,
    String cover = '',
    int duration = 0,
    int quality = 0,
  }) async {
    await init();
    final DownloadTask? exist = taskOf(cid);
    if (exist != null) {
      if (exist.isCompleted) {
        return null;
      }
      exist.title = title.isEmpty ? exist.title : title;
      if (cover.isNotEmpty) exist.cover = cover;
      if (duration > 0) exist.duration = duration;
      if (quality > 0) exist.quality = quality;
      _save(exist);
      if (exist.status != DownloadStatus.downloading) {
        exist.status = DownloadStatus.waiting;
        _save(exist);
        _pump();
      }
      return exist;
    }
    final DownloadTask task = DownloadTask(
      cid: cid,
      bvid: bvid,
      title: title,
      cover: cover,
      duration: duration,
      quality: quality,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    tasks.insert(0, task);
    _save(task);
    _pump();
    return task;
  }

  /// 暂停（同时支持取消排队）
  void pause(int cid) {
    final DownloadTask? task = taskOf(cid);
    if (task == null) return;
    _tokens.remove(cid)?.cancel('paused');
    _running.remove(cid);
    task.status = DownloadStatus.paused;
    task.errorMsg = '';
    _save(task);
    _pump();
  }

  /// 继续
  void resume(int cid) {
    final DownloadTask? task = taskOf(cid);
    if (task == null) return;
    if (task.status == DownloadStatus.completed) return;
    task.status = DownloadStatus.waiting;
    task.errorMsg = '';
    _save(task);
    _pump();
  }

  void retry(int cid) => resume(cid);

  void pauseAll() {
    for (final DownloadTask t in tasks) {
      if (t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.waiting) {
        pause(t.cid);
      }
    }
  }

  void resumeAll() {
    for (final DownloadTask t in tasks) {
      if (t.status == DownloadStatus.paused ||
          t.status == DownloadStatus.failed) {
        resume(t.cid);
      }
    }
  }

  /// 删除任务；deleteFile 为 true 时连同离线文件一起删
  Future<void> removeTask(int cid, {bool deleteFile = true}) async {
    _tokens.remove(cid)?.cancel('removed');
    _running.remove(cid);
    tasks.removeWhere((DownloadTask t) => t.cid == cid);
    try {
      await _box.delete(cid.toString());
    } catch (e) {
      print('DownloadManager: delete record failed:  ' + e.toString());
    }
    if (deleteFile) {
      try {
        final Directory dir = Directory(_rootPath + '/' + cid.toString());
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      } catch (e) {
        print('DownloadManager: delete files failed:  ' + e.toString());
      }
    }
    _pump();
  }

  /// 记录离线播放进度
  void savePlayPosition(int cid, int position) {
    final DownloadTask? task = taskOf(cid);
    if (task == null) return;
    task.lastPosition = position;
    _save(task);
  }

  // ---------------------------------------------------------------- 落盘

  void _save(DownloadTask task) {
    try {
      _box.put(task.cid.toString(), task.toMap());
    } catch (e) {
      print('DownloadManager: save failed:  ' + e.toString());
    }
    _notify();
  }

  /// DownloadTask 是普通对象，改字段不会触发 Obx；
  /// 统一在保存时手动 refresh 任务列表，让进度条与状态文案跟着动。
  void _notify() {
    try {
      tasks.refresh();
    } catch (_) {
      // 列表尚未初始化（init 前）时忽略
    }
  }

  /// 进度回调非常密集，节流成 1 秒一次写 Hive
  void _saveThrottled(DownloadTask task) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int last = _lastSaveAt[task.cid] ?? 0;
    if (now - last < 1000) return;
    _lastSaveAt[task.cid] = now;
    _save(task);
  }

  // ---------------------------------------------------------------- 调度

  void _pump() {
    if (_running.length >= maxConcurrent) return;
    for (final DownloadTask t in tasks) {
      if (_running.length >= maxConcurrent) return;
      if (t.status == DownloadStatus.waiting && !_running.contains(t.cid)) {
        unawaited(_start(t));
      }
    }
  }

  Future<bool> _wifiAllowed() async {
    final bool onlyWifi =
        setting.get(SettingBoxKey.downloadOnlyWifi, defaultValue: false) as bool;
    if (!onlyWifi) return true;
    try {
      final List<ConnectivityResult> res =
          await Connectivity().checkConnectivity();
      return res.contains(ConnectivityResult.wifi) ||
          res.contains(ConnectivityResult.ethernet);
    } catch (e) {
      // 拿不到网络类型时不阻塞用户
      return true;
    }
  }

  Future<void> _start(DownloadTask task) async {
    if (!_running.add(task.cid)) return;
    final CancelToken token = CancelToken();
    _tokens[task.cid] = token;
    task.status = DownloadStatus.downloading;
    task.errorMsg = '';
    _save(task);

    try {
      if (!await _wifiAllowed()) {
        task.status = DownloadStatus.paused;
        task.errorMsg = '仅 Wi-Fi 下载，已暂停';
        _save(task);
        return;
      }
      await _runTask(task, token);
      task.status = DownloadStatus.completed;
      task.receivedBytes = task.totalBytes;
      task.errorMsg = '';
      _save(task);
    } on _CancelledException {
      // 用户主动暂停/删除：状态已由调用方设置，这里不再覆盖
    } catch (err) {
      if (token.isCancelled) {
        // dio 取消也会走到这里，不当作失败
        return;
      }
      task.status = DownloadStatus.failed;
      task.errorMsg = _friendlyError(err);
      _save(task);
      print('DownloadManager: task ' + task.cid.toString() + ' failed:  ' + err.toString());
    } finally {
      _tokens.remove(task.cid);
      _running.remove(task.cid);
      _lastSaveAt.remove(task.cid);
      _pump();
    }
  }

  String _friendlyError(dynamic err) {
    if (err is DioException) {
      switch (err.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return '网络超时';
        case DioExceptionType.connectionError:
          return '网络连接失败';
        case DioExceptionType.badResponse:
          return '服务器返回 ' + (err.response?.statusCode ?? 0).toString();
        default:
          return err.message ?? '下载出错';
      }
    }
    return err.toString();
  }

  Future<void> _runTask(DownloadTask task, CancelToken token) async {
    final Map res = await VideoHttp.videoUrl(
      cid: task.cid,
      bvid: task.bvid,
      qn: task.quality > 0 ? task.quality : null,
    );
    if (token.isCancelled) throw _CancelledException();
    if (res['status'] != true) {
      throw Exception('取流失败：' + (res['msg'] ?? '未知错误').toString());
    }
    final PlayUrlModel data = res['data'] as PlayUrlModel;
    final Directory dir = await _taskDir(task.cid);
    final File vFile = File(dir.path + '/video.m4s');
    final File aFile = File(dir.path + '/audio.m4s');

    int vDone = 0;
    int vTotal = 0;
    int aDone = 0;
    int aTotal = 0;

    void emit(int vd, int vt, int ad, int at) {
      vDone = vd;
      vTotal = vt;
      aDone = ad;
      aTotal = at;
      task.totalBytes = vTotal + aTotal;
      task.receivedBytes = vDone + aDone;
      _saveThrottled(task);
    }

    final List<VideoItem> videos = data.dash?.video ?? <VideoItem>[];
    final List<AudioItem> audios = data.dash?.audio ?? <AudioItem>[];

    if (videos.isNotEmpty) {
      // ---- DASH：视频流 + 音频流分别下载
      final VideoItem video = _pickVideo(videos, task.quality);
      final AudioItem? audio = _pickAudio(audios, task.audioId);
      task.quality = video.id ?? task.quality;
      task.qualityDesc = video.quality?.description ?? task.qualityDesc;
      task.codecs = video.codecs ?? task.codecs;
      if (audio != null) {
        task.audioId = audio.id ?? task.audioId;
        task.audioDesc = audio.quality ?? task.audioDesc;
      }
      _save(task);

      await _downloadToFile(
        urls: _urlCandidates(video.baseUrl, video.backupUrl),
        file: vFile,
        token: token,
        onProgress: (int received, int total) =>
            emit(received, total, aDone, aTotal),
      );
      if (token.isCancelled) throw _CancelledException();

      if (audio != null) {
        await _downloadToFile(
          urls: _urlCandidates(audio.baseUrl, audio.backupUrl),
          file: aFile,
          token: token,
          onProgress: (int received, int total) =>
              emit(vDone, vTotal, received, total),
        );
      } else if (aFile.existsSync()) {
        aFile.deleteSync();
      }
      if (token.isCancelled) throw _CancelledException();
    } else if (data.durl != null && data.durl!.isNotEmpty) {
      // ---- 兼容老的 durl（整段 mp4，无独立音轨）
      final List<String> urls = <String>[];
      for (final Durl item in data.durl!) {
        if (item.url != null && item.url!.isNotEmpty) urls.add(item.url!);
      }
      if (urls.isEmpty) {
        throw Exception('没有可用的视频地址');
      }
      if (aFile.existsSync()) aFile.deleteSync();
      await _downloadToFile(
        urls: urls,
        file: vFile,
        token: token,
        onProgress: (int received, int total) =>
            emit(received, total, 0, 0),
      );
      if (token.isCancelled) throw _CancelledException();
    } else {
      throw Exception('该视频没有可下载的流');
    }

    // 文件完整性校验：服务端给了总长就必须一样长，否则下次 Range 续传会错位
    if (vTotal > 0 && vFile.existsSync() && vFile.lengthSync() < vTotal) {
      throw Exception('视频文件不完整');
    }
    if (aTotal > 0 && aFile.existsSync() && aFile.lengthSync() < aTotal) {
      throw Exception('音频文件不完整');
    }

    // 弹幕
    final bool withDanmaku =
        setting.get(SettingBoxKey.downloadWithDanmaku, defaultValue: true) as bool;
    if (withDanmaku && task.duration > 0) {
      await _downloadDanmaku(task);
    }

    await _writeMeta(task, dir);
  }

  List<String> _urlCandidates(String? baseUrl, String? backupUrl) {
    final List<String> urls = <String>[];
    if (baseUrl != null && baseUrl.isNotEmpty) urls.add(baseUrl);
    if (backupUrl != null &&
        backupUrl.isNotEmpty &&
        backupUrl != baseUrl) {
      urls.add(backupUrl);
    }
    return urls;
  }

  /// 选一条视频流：优先贴近目标清晰度，其次优先 AVC（兼容性最好）
  VideoItem _pickVideo(List<VideoItem> videos, int quality) {
    int target = quality;
    if (target <= 0) {
      // 没有指定就取最高
      for (final VideoItem v in videos) {
        if ((v.id ?? 0) > target) target = v.id ?? 0;
      }
    }
    final List<int> ids = videos.map((VideoItem e) => e.id ?? 0).toList();
    final int closest = Utils.findClosestNumber(target, ids);
    final List<VideoItem> sameQa = videos
        .where((VideoItem e) => (e.id ?? 0) == closest)
        .toList();
    if (sameQa.isEmpty) return videos.first;
    for (final VideoItem v in sameQa) {
      final String codecs = (v.codecs ?? '').toLowerCase();
      if (codecs.startsWith('avc')) return v;
    }
    return sameQa.first;
  }

  AudioItem? _pickAudio(List<AudioItem> audios, int audioId) {
    if (audios.isEmpty) return null;
    if (audioId > 0) {
      for (final AudioItem a in audios) {
        if (a.id == audioId) return a;
      }
    }
    AudioItem? best;
    for (final AudioItem a in audios) {
      if (best == null) {
        best = a;
        continue;
      }
      if ((a.bandWidth ?? 0) > (best.bandWidth ?? 0)) best = a;
    }
    return best;
  }

  /// 带 Range 断点续传的下载
  Future<void> _downloadToFile({
    required List<String> urls,
    required File file,
    required CancelToken token,
    required void Function(int received, int total) onProgress,
  }) async {
    if (urls.isEmpty) {
      throw Exception('没有可用的下载地址');
    }
    dynamic lastError;
    for (final String url in urls) {
      try {
        await _downloadSingle(
          url: url,
          file: file,
          token: token,
          onProgress: onProgress,
        );
        return;
      } on _CancelledException {
        rethrow;
      } catch (err) {
        lastError = err;
        if (token.isCancelled) throw _CancelledException();
        print('DownloadManager: mirror failed, try next: ' + err.toString());
      }
    }
    throw lastError ?? Exception('下载失败');
  }

  Future<void> _downloadSingle({
    required String url,
    required File file,
    required CancelToken token,
    required void Function(int received, int total) onProgress,
  }) async {
    int existing = file.existsSync() ? file.lengthSync() : 0;
    final Map<String, dynamic> headers = <String, dynamic>{
      'user-agent': _ua,
      'referer': 'https://www.bilibili.com/',
      'origin': 'https://www.bilibili.com',
    };
    if (existing > 0) {
      headers['range'] = 'bytes=' + existing.toString() + '-';
    }

    final dynamic res = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        validateStatus: (int? status) =>
            status != null && status >= 200 && status < 400,
        receiveTimeout: const Duration(seconds: 30),
      ),
      cancelToken: token,
    );

    final int status = res.statusCode ?? 200;
    int total = 0;
    if (status == 206) {
      total = _totalFromContentRange(res.headers, existing);
      if (total <= 0) {
        // 服务端没给总长，只能拿现有长度兜底（进度条会显示 100%，不影响下载）
        total = existing;
      }
    } else {
      // 服务端忽略了 Range（没有续传能力）：从头覆盖写
      if (file.existsSync()) file.deleteSync();
      existing = 0;
      total = _contentLength(res.headers);
    }

    final ResponseBody? body = res.data;
    if (body == null) {
      throw Exception('响应为空');
    }

    final IOSink sink =
        file.openWrite(mode: existing > 0 && status == 206 ? FileMode.writeOnlyAppend : FileMode.write);
    int received = existing;
    onProgress(received, total);
    try {
      await for (final Uint8List chunk in body.stream) {
        if (token.isCancelled) {
          throw _CancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        if (total <= 0) total = received;
        onProgress(received, total);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (total > 0 && received < total) {
      throw Exception('连接提前结束 ' + received.toString() + '/' + total.toString());
    }
  }

  int _contentLength(Headers headers) {
    final String? raw = headers.value('content-length');
    if (raw == null) return 0;
    return int.tryParse(raw) ?? 0;
  }

  int _totalFromContentRange(Headers headers, int fallback) {
    final String? raw = headers.value('content-range');
    if (raw == null) return fallback;
    final int slash = raw.lastIndexOf('/');
    if (slash < 0) return fallback;
    final String tail = raw.substring(slash + 1).trim();
    return int.tryParse(tail) ?? fallback;
  }

  /// 下载弹幕：按 6 分钟一段请求 Protobuf 并原样存盘
  Future<void> _downloadDanmaku(DownloadTask task) async {
    try {
      final Directory dir = await _taskDir(task.cid);
      final Directory dmDir = Directory(dir.path + '/danmaku');
      if (!dmDir.existsSync()) dmDir.createSync(recursive: true);
      // duration 约定毫秒；历史任务里若被存成秒（< 60 秒的值不可能是一条
      // 正常视频的毫秒时长），按秒兜底换算，避免算出几千个不存在的分段。
      int totalMs = task.duration;
      if (totalMs > 0 && totalMs < 60 * 1000) {
        totalMs = totalMs * 1000;
      }
      int segCount = (totalMs / danmakuSegmentLength).ceil();
      if (segCount <= 0) segCount = 1;
      // 上限保护：B 站单片最长也就十几个小时，超过 200 段必然是脏数据
      if (segCount > 200) segCount = 200;
      for (int i = 0; i < segCount; i++) {
        final File f = File(dmDir.path + '/' + (i + 1).toString() + '.pb');
        if (f.existsSync() && f.lengthSync() > 2) continue;
        try {
          final DmSegMobileReply? reply = await _fetchDanmaku(task.cid, i + 1);
          if (reply == null || reply.elems.isEmpty) {
            print('DownloadManager: danmaku seg ' +
                (i + 1).toString() +
                ' empty (risk-control or no danmaku)');
            continue;
          }
          await f.writeAsBytes(reply.writeToBuffer(), flush: true);
        } catch (err) {
          print('DownloadManager: danmaku seg ' +
              (i + 1).toString() +
              ' failed:  ' +
              err.toString());
        }
      }
    } catch (e) {
      // 弹幕失败不影响视频缓存
      print('DownloadManager: danmaku failed:  ' + e.toString());
    }
  }

  /// 主动拉取一段弹幕。
  ///
  /// 不复用 DanmakaHttp + Request.dio：那条链路的默认 UA 在部分视频上会被
  /// 风控（返回 {"code":-352} 的 JSON 而不是 protobuf），且失败会弹全局 toast。
  /// 这里用浏览器 UA + 当前 Cookie 直连，失败只安静地记一行日志。
  Future<DmSegMobileReply?> _fetchDanmaku(int cid, int segmentIndex) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final dynamic cookie = Request.dio.options.headers['cookie'];
        final Map<String, dynamic> headers = <String, dynamic>{
          'user-agent': _danmakuUa,
          'referer': 'https://www.bilibili.com/',
          'origin': 'https://www.bilibili.com',
        };
        if (cookie != null && cookie.toString().isNotEmpty) {
          headers['cookie'] = cookie.toString();
        }
        final dynamic res = await _dio.get<List<int>>(
          HttpString.apiBaseUrl + Api.webDanmaku,
          queryParameters: <String, dynamic>{
            'type': 1,
            'oid': cid,
            'segment_index': segmentIndex,
          },
          options: Options(
            responseType: ResponseType.bytes,
            headers: headers,
            validateStatus: (int? status) =>
                status != null && status >= 200 && status < 300,
          ),
        );
        final List<int>? bytes = res.data as List<int>?;
        if (bytes == null || bytes.isEmpty) return null;
        return DmSegMobileReply.fromBuffer(Uint8List.fromList(bytes));
      } catch (e) {
        print('DownloadManager: danmaku fetch failed:  ' + e.toString());
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      }
    }
    return null;
  }

  /// 读取已缓存的弹幕（按段索引）
  Map<int, List<DanmakuElem>> loadDanmaku(int cid) {
    final Map<int, List<DanmakuElem>> map = <int, List<DanmakuElem>>{};
    if (_rootPath.isEmpty) return map;
    final Directory dmDir = Directory(danmakuDirOf(cid));
    if (!dmDir.existsSync()) return map;
    for (final FileSystemEntity entity in dmDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.pb')) continue;
      final String name = entity.uri.pathSegments.last.replaceAll('.pb', '');
      final int? index = int.tryParse(name);
      if (index == null) continue;
      try {
        final DmSegMobileReply reply =
            DmSegMobileReply.fromBuffer(entity.readAsBytesSync());
        if (reply.elems.isNotEmpty) {
          map[index] = reply.elems.toList();
        }
      } catch (e) {
        print('DownloadManager: read danmaku failed:  ' + e.toString());
      }
    }
    return map;
  }

  /// 展平所有弹幕（离线播放时一次性喂给弹幕引擎）
  List<DanmakuElem> loadDanmakuElems(int cid) {
    final Map<int, List<DanmakuElem>> segMap = loadDanmaku(cid);
    final List<int> keys = segMap.keys.toList()..sort();
    final List<DanmakuElem> all = <DanmakuElem>[];
    for (final int key in keys) {
      all.addAll(segMap[key]!);
    }
    return all;
  }

  Future<void> _writeMeta(DownloadTask task, Directory dir) async {
    try {
      final Map<String, dynamic> meta = <String, dynamic>{
        'cid': task.cid,
        'bvid': task.bvid,
        'title': task.title,
        'cover': task.cover,
        'quality': task.quality,
        'qualityDesc': task.qualityDesc,
        'audioId': task.audioId,
        'audioDesc': task.audioDesc,
        'codecs': task.codecs,
        'duration': task.duration,
        'createdAt': task.createdAt,
        'videoBytes':
            File(dir.path + '/video.m4s').existsSync() ? File(dir.path + '/video.m4s').lengthSync() : 0,
        'audioBytes':
            File(dir.path + '/audio.m4s').existsSync() ? File(dir.path + '/audio.m4s').lengthSync() : 0,
      };
      await File(dir.path + '/meta.json')
          .writeAsString(jsonEncode(meta), flush: true);
    } catch (e) {
      print('DownloadManager: write meta failed:  ' + e.toString());
    }
  }

  @override
  void onClose() {
    for (final CancelToken token in _tokens.values) {
      token.cancel('closing');
    }
    _tokens.clear();
    super.onClose();
  }
}

/// 内部用于区分「用户主动取消」和「真的失败」
class _CancelledException implements Exception {}
