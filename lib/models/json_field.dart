import 'dart:convert';

// ---------------------------------------------------------------------------
// JSON 字段类型归一工具（通用版）
//
// B 站各接口对同一字段的类型并不稳定：同一个 mid / uid / count 在不同端、不同
// 版本上可能是 int、String（"130061363"）、double 甚至 bool。模型里把字段声
// 明成 int? 却直接 `json['uid']` 赋值，运行时会抛
//   type 'String' is not a subtype of type 'int?'
// 这类异常被 http 层 catch 后表现为「解析失败」，用户看到的是整页报错甚至红屏。
//
// 所有模型反序列化都应经这里取值。
// ---------------------------------------------------------------------------
int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString().trim());
}

/// 时间戳专用：0 与无法解析的值都当作「无」，避免显示 1970 年。
int? asTs(dynamic v) {
  final int? i = asInt(v);
  return (i == null || i == 0) ? null : i;
}

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1.0 : 0.0;
  return double.tryParse(v.toString().trim());
}

String? asStr(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is Map || v is Iterable) return jsonEncode(v);
  return v.toString();
}

bool? asBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final String s = v.toString().trim().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0' || s.isEmpty) return false;
  return null;
}

/// 取 Map 字段：不是 Map 时返回 null，避免 `json['x']['y']` 抛 NoSuchMethodError。
Map<String, dynamic>? asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    try {
      return Map<String, dynamic>.from(v);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// 取 List<Map> 字段：过滤掉非 Map 元素。
List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  for (final dynamic item in v) {
    final Map<String, dynamic>? m = asMap(item);
    if (m != null) out.add(m);
  }
  return out;
}
