/// 离线下载任务模型
///
/// 该对象只保存「状态」与「元信息」，实际媒体文件落在
/// `<ApplicationSupportDirectory>/offline/<cid>/` 下（video.m4s / audio.m4s / danmaku/*.pb）。
/// 持久化走 Hive box `download`，key 为 cid 字符串，value 为本对象的 toMap()。
enum DownloadStatus {
  waiting, // 排队中
  downloading, // 下载中
  paused, // 已暂停
  completed, // 已完成
  failed, // 失败
}

class DownloadTask {
  DownloadTask({
    required this.cid,
    required this.bvid,
    required this.title,
    this.cover = '',
    this.quality = 0,
    this.qualityDesc = '',
    this.audioId = 0,
    this.audioDesc = '',
    this.codecs = '',
    this.duration = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.waiting,
    this.errorMsg = '',
    this.createdAt = 0,
    this.lastPosition = 0,
  });

  /// 分P 的 cid，同时作为存储目录名与 Hive key
  final int cid;
  final String bvid;
  String title;
  String cover;

  /// 实际下载到的清晰度 id（qn）与描述
  int quality;
  String qualityDesc;

  /// 音频流 id（30216/30232/30280…），恢复下载时按它重挑音轨
  int audioId;
  String audioDesc;
  String codecs;

  /// 视频时长（毫秒），用于弹幕分段与进度条
  int duration;

  int receivedBytes;
  int totalBytes;
  DownloadStatus status;
  String errorMsg;
  int createdAt;

  /// 离线播放进度（毫秒），退出播放页时写入
  int lastPosition;

  double get progress {
    if (totalBytes <= 0) return 0;
    final double p = receivedBytes / totalBytes;
    return p.clamp(0.0, 1.0);
  }

  bool get isCompleted => status == DownloadStatus.completed;

  /// 排队中或下载中（都算「活跃」，占着队列）
  bool get isActive =>
      status == DownloadStatus.downloading || status == DownloadStatus.waiting;

  String get statusText {
    switch (status) {
      case DownloadStatus.waiting:
        return '排队中';
      case DownloadStatus.downloading:
        return '下载中 ${(progress * 100).toStringAsFixed(0)}%';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return errorMsg.isEmpty ? '下载失败' : '失败：$errorMsg';
    }
  }

  static String sizeText(int bytes) {
    if (bytes <= 0) return '0B';
    const List<String> units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index++;
    }
    return '${size.toStringAsFixed(index == 0 ? 0 : 1)}${units[index]}';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cid': cid,
      'bvid': bvid,
      'title': title,
      'cover': cover,
      'quality': quality,
      'qualityDesc': qualityDesc,
      'audioId': audioId,
      'audioDesc': audioDesc,
      'codecs': codecs,
      'duration': duration,
      'receivedBytes': receivedBytes,
      'totalBytes': totalBytes,
      'status': status.index,
      'errorMsg': errorMsg,
      'createdAt': createdAt,
      'lastPosition': lastPosition,
    };
  }

  factory DownloadTask.fromMap(Map data) {
    final int rawStatus = data['status'] is int ? data['status'] as int : 0;
    return DownloadTask(
      cid: data['cid'] is int ? data['cid'] as int : int.tryParse('${data['cid']}') ?? 0,
      bvid: data['bvid'] ?? '',
      title: data['title'] ?? '',
      cover: data['cover'] ?? '',
      quality: data['quality'] is int ? data['quality'] as int : 0,
      qualityDesc: data['qualityDesc'] ?? '',
      audioId: data['audioId'] is int ? data['audioId'] as int : 0,
      audioDesc: data['audioDesc'] ?? '',
      codecs: data['codecs'] ?? '',
      duration: data['duration'] is int ? data['duration'] as int : 0,
      receivedBytes: data['receivedBytes'] is int ? data['receivedBytes'] as int : 0,
      totalBytes: data['totalBytes'] is int ? data['totalBytes'] as int : 0,
      status: rawStatus >= 0 && rawStatus < DownloadStatus.values.length
          ? DownloadStatus.values[rawStatus]
          : DownloadStatus.paused,
      errorMsg: data['errorMsg'] ?? '',
      createdAt: data['createdAt'] is int ? data['createdAt'] as int : 0,
      lastPosition: data['lastPosition'] is int ? data['lastPosition'] as int : 0,
    );
  }
}
