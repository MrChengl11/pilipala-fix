class RoomInfoModel {
  RoomInfoModel({
    this.roomId,
    this.isPortrait,
    this.liveStatus,
    this.liveTime,
    this.playurlInfo,
  });
  int? roomId;
  bool? isPortrait;
  int? liveStatus;
  int? liveTime;
  PlayurlInfo? playurlInfo;

  RoomInfoModel.fromJson(Map<String, dynamic> json) {
    roomId = json['room_id'];
    liveStatus = json['live_status'];
    isPortrait = json['is_portrait'];
    liveTime = json['live_time'];
    // 未开播/无播放地址的直播间 playurl_info 为 null，直接 fromJson 会
    // NoSuchMethodError: The method '[]' was called on null，导致整页黑屏
    final dynamic _playurlInfo = json['playurl_info'];
    playurlInfo = _playurlInfo is Map
        ? PlayurlInfo.fromJson(Map<String, dynamic>.from(_playurlInfo))
        : null;
  }
}

class PlayurlInfo {
  PlayurlInfo({
    this.playurl,
  });

  Playurl? playurl;

  PlayurlInfo.fromJson(Map<String, dynamic> json) {
    final dynamic _playurl = json['playurl'];
    playurl = _playurl is Map
        ? Playurl.fromJson(Map<String, dynamic>.from(_playurl))
        : null;
  }
}

class Playurl {
  Playurl({
    this.cid,
    this.gQnDesc,
    this.stream,
  });

  int? cid;
  List<GQnDesc>? gQnDesc;
  List<Streams>? stream;

  Playurl.fromJson(Map<String, dynamic> json) {
    cid = json['cid'];
    final dynamic _gQnDesc = json['g_qn_desc'];
    gQnDesc = _gQnDesc is List
        ? _gQnDesc
            .whereType<Map>()
            .map<GQnDesc>((e) => GQnDesc.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <GQnDesc>[];
    final dynamic _stream = json['stream'];
    stream = _stream is List
        ? _stream
            .whereType<Map>()
            .map<Streams>((e) => Streams.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Streams>[];
  }
}

class GQnDesc {
  GQnDesc({
    this.qn,
    this.desc,
    this.hdrDesc,
    this.attrDesc,
  });

  int? qn;
  String? desc;
  String? hdrDesc;
  String? attrDesc;

  GQnDesc.fromJson(Map<String, dynamic> json) {
    qn = json['qn'];
    desc = json['desc'];
    hdrDesc = json['hedr_desc'];
    attrDesc = json['attr_desc'];
  }
}

class Streams {
  Streams({
    this.protocolName,
    this.format,
  });

  String? protocolName;
  List<FormatItem>? format;

  Streams.fromJson(Map<String, dynamic> json) {
    protocolName = json['protocol_name'];
    final dynamic _format = json['format'];
    format = _format is List
        ? _format
            .whereType<Map>()
            .map<FormatItem>(
                (e) => FormatItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <FormatItem>[];
  }
}

class FormatItem {
  FormatItem({
    this.formatName,
    this.codec,
  });

  String? formatName;
  List<CodecItem>? codec;

  FormatItem.fromJson(Map<String, dynamic> json) {
    formatName = json['format_name'];
    final dynamic _codec = json['codec'];
    codec = _codec is List
        ? _codec
            .whereType<Map>()
            .map<CodecItem>((e) => CodecItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <CodecItem>[];
  }
}

class CodecItem {
  CodecItem({
    this.codecName,
    this.currentQn,
    this.acceptQn,
    this.baseUrl,
    this.urlInfo,
    this.hdrQn,
    this.dolbyType,
    this.attrName,
  });

  String? codecName;
  int? currentQn;
  List? acceptQn;
  String? baseUrl;
  List<UrlInfoItem>? urlInfo;
  String? hdrQn;
  int? dolbyType;
  String? attrName;

  CodecItem.fromJson(Map<String, dynamic> json) {
    codecName = json['codec_name'];
    currentQn = json['current_qn'];
    acceptQn = json['accept_qn'];
    baseUrl = json['base_url'];
    final dynamic _urlInfo = json['url_info'];
    urlInfo = _urlInfo is List
        ? _urlInfo
            .whereType<Map>()
            .map<UrlInfoItem>(
                (e) => UrlInfoItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <UrlInfoItem>[];
    hdrQn = json['hdr_n'];
    dolbyType = json['dolby_type'];
    attrName = json['attr_name'];
  }
}

class UrlInfoItem {
  UrlInfoItem({
    this.host,
    this.extra,
    this.streamTtl,
  });

  String? host;
  String? extra;
  int? streamTtl;

  UrlInfoItem.fromJson(Map<String, dynamic> json) {
    host = json['host'];
    extra = json['extra'];
    streamTtl = json['stream_ttl'];
  }
}
