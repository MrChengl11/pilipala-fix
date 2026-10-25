// ignore_for_file: constant_identifier_names

enum VideoQuality {
  speed240,
  flunt360,
  clear480,
  high720,
  high72060,
  high1080,
  high1080plus,
  high108060,
  super4K,
  hdr,
  dolbyVision,
  super8k
}

extension VideoQualityCode on VideoQuality {
  static final List<int> _codeList = [
    6,
    16,
    32,
    64,
    74,
    80,
    112,
    116,
    120,
    125,
    126,
    127,
  ];
  int get code => _codeList[index];

  static VideoQuality? fromCode(int code) {
    final index = _codeList.indexOf(code);
    if (index != -1) {
      return VideoQuality.values[index];
    }
    return null;
  }

  static int? toCode(VideoQuality quality) {
    final index = VideoQuality.values.indexOf(quality);
    if (index != -1 && index < _codeList.length) {
      return _codeList[index];
    }
    return null;
  }
}

extension VideoQualityDesc on VideoQuality {
  static final List<String> _descList = [
    '240P 极速',
    '360P 流畅',
    '480P 清晰',
    '720P 高清',
    '720P60 高帧率',
    '1080P 高清',
    '1080P+ 高码率',
    '1080P60 高帧率',
    '4K 超清',
    'HDR 真彩色',
    '杜比视界',
    '8K 超高清'
  ];
  get description => _descList[index];
}

///
enum AudioQuality { k64, k132, k192, dolby, hiRes }

extension AudioQualityCode on AudioQuality {
  static final List<int> _codeList = [
    30216,
    30232,
    30280,
    30250,
    30251,
  ];
  int get code => _codeList[index];

  static AudioQuality? fromCode(int code) {
    final index = _codeList.indexOf(code);
    if (index != -1) {
      return AudioQuality.values[index];
    }
    return null;
  }
}

extension AudioQualityDesc on AudioQuality {
  static final List<String> _descList = [
    '64K',
    '132K',
    '192K',
    '杜比全景声',
    'Hi-Res无损',
  ];
  get description => _descList[index];
}

enum VideoDecodeFormats {
  DVH1,
  AV1,
  HEVC,
  AVC,
}

extension VideoDecodeFormatsDesc on VideoDecodeFormats {
  static final List<String> _descList = ['DVH1', 'AV1', 'HEVC', 'AVC'];
  get description => _descList[index];
}

extension VideoDecodeFormatsCode on VideoDecodeFormats {
  static final List<String> _codeList = ['dvh1', 'av01', 'hev1', 'avc1'];
  get code => _codeList[index];

  /// codecs 串前缀 -> 解码格式。bilibili 同一编码有多种写法：
  /// hvc1/hev1 都是 HEVC，dvhe/dvh1/dovi 都是杜比视界，avc3 也是 AVC。
  static final Map<String, VideoDecodeFormats> _prefixMap = {
    'dvh1': VideoDecodeFormats.DVH1,
    'dvhe': VideoDecodeFormats.DVH1,
    'dovi': VideoDecodeFormats.DVH1,
    'av01': VideoDecodeFormats.AV1,
    'hev1': VideoDecodeFormats.HEVC,
    'hvc1': VideoDecodeFormats.HEVC,
    'avc1': VideoDecodeFormats.AVC,
    'avc3': VideoDecodeFormats.AVC,
  };

  static VideoDecodeFormats? fromCode(String code) {
    final index = _codeList.indexOf(code);
    if (index != -1) {
      return VideoDecodeFormats.values[index];
    }
    return null;
  }

  /// 解析 codecs 串（如 'avc1.640032'、'hvc1.1.6.L120.90'）。
  ///
  /// 解析不出来时返回 null。原实现解析失败时默认返回 values.first(DVH1)，
  /// 于是接口里任何不认识的 codecs（典型是 HEVC 的 hvc1.xxx）都会被显示成
  /// 「DVH1」，用户一选就必然失败并被打回 AVC —— 这就是 Bug 2 的根因。
  static VideoDecodeFormats? fromString(String val) {
    final String lower = val.toLowerCase();
    for (final entry in _prefixMap.entries) {
      if (lower.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// 面板展示用名称：解析不出来时直接显示原始 codecs 串，不再伪装成 DVH1
  static String descFromString(String val) =>
      fromString(val)?.description ?? val;

  /// 判断某条流的 codecs 串是否属于指定解码格式。
  /// 统一走 [_prefixMap] 归一化，避免 supportFormats 写的是 hvc1.* 而 dash 里
  /// 写的是 hev1.*（或 avc3/avc1）时对不上，导致明明有流却判定为不支持。
  static bool matches(String? codecs, VideoDecodeFormats format) {
    if (codecs == null || codecs.isEmpty) return false;
    final VideoDecodeFormats? parsed = fromString(codecs);
    if (parsed != null) return parsed == format;
    return codecs.toLowerCase().startsWith(format.code);
  }
}
