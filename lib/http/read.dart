import 'dart:convert';
import 'package:html/parser.dart';
import 'package:pilipala/models/read/opus.dart';
import 'package:pilipala/models/read/read.dart';
import 'package:pilipala/utils/wbi_sign.dart';
import 'index.dart';

class ReadHttp {
  static List<String> extractScriptContents(String htmlContent) {
    RegExp scriptRegExp = RegExp(r'<script>([\s\S]*?)<\/script>');
    Iterable<Match> matches = scriptRegExp.allMatches(htmlContent);
    List<String> scriptContents = [];
    for (Match match in matches) {
      String scriptContent = match.group(1)!;
      scriptContents.add(scriptContent);
    }
    return scriptContents;
  }

  /// 从页面里抽出下一个 script 标签的 JSON 内容并解析。
  ///
  /// 原实现直接用 extractScriptContents(...)[0] + substring + json.decode，
  /// 页面结构变化/接口风控返回错误页时必然抛 RangeError/FormatException，
  /// 而调用方没有 try/catch，用户只能看到空白页且没有失败提示。
  static Map<String, dynamic>? _extractJson(String html) {
    try {
      final String? bodyHtml = parse(html).body?.outerHtml;
      if (bodyHtml == null) return null;
      final List<String> scripts = extractScriptContents(bodyHtml);
      for (final String script in scripts) {
        final int startIndex = script.indexOf('{');
        final int endIndex = script.lastIndexOf('};');
        if (startIndex < 0 || endIndex <= startIndex) continue;
        try {
          final dynamic decoded =
              json.decode(script.substring(startIndex, endIndex + 1));
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {
          continue;
        }
      }
    } catch (_) {}
    return null;
  }

  // 解析专栏 opus格式
  static Future parseArticleOpus({required String id}) async {
    var res = await Request().get('https://www.bilibili.com/opus/$id', extra: {
      'ua': 'pc',
    });
    final String html = res.data?.toString() ?? '';
    if (html.isEmpty) return {'status': false, 'msg': '专栏内容获取失败'};
    final Map<String, dynamic>? jsonData = _extractJson(html);
    if (jsonData == null) return {'status': false, 'msg': '专栏内容解析失败'};
    String? headContent = parse(html).head?.outerHtml;
    var document = parse(headContent);
    var linkTags = document.getElementsByTagName('link');
    bool isCv = false;
    String cvId = '';
    for (var linkTag in linkTags) {
      var attributes = linkTag.attributes;
      if (attributes.containsKey('rel') &&
          attributes['rel'] == 'canonical' &&
          attributes.containsKey('data-vue-meta') &&
          attributes['data-vue-meta'] == 'true') {
        final String cvHref = linkTag.attributes['href']!;
        RegExp regex = RegExp(r'cv(\d+)');
        RegExpMatch? match = regex.firstMatch(cvHref);
        if (match != null) {
          cvId = match.group(1)!;
        } else {
          print('No match found.');
        }
        isCv = true;
        break;
      }
    }
    try {
      return {
        'status': true,
        'data': OpusDataModel.fromJson(jsonData),
        'isCv': isCv,
        'cvId': cvId,
      };
    } catch (e) {
      return {'status': false, 'msg': '专栏内容解析失败'};
    }
  }

  // 解析专栏 cv格式
  static Future parseArticleCv({required String id}) async {
    var res = await Request().get(
      'https://www.bilibili.com/read/cv$id',
      extra: {'ua': 'pc'},
    );
    final String html = res.data?.toString() ?? '';
    if (html.isEmpty) return {'status': false, 'msg': '专栏内容获取失败'};
    final Map<String, dynamic>? jsonData = _extractJson(html);
    if (jsonData == null) return {'status': false, 'msg': '专栏内容解析失败'};
    try {
      return {
        'status': true,
        'data': ReadDataModel.fromJson(jsonData),
      };
    } catch (e) {
      return {'status': false, 'msg': '专栏内容解析失败'};
    }
  }

  //
  static Future getViewInfo({required String id}) async {
    Map params = await WbiSign().makSign({
      'id': id,
      'mobi_app': 'pc',
      'from': 'web',
      'gaia_source': 'main_web',
      'web_location': 333.976,
    });
    var res = await Request().get(
      Api.getViewInfo,
      data: {
        'id': id,
        'mobi_app': 'pc',
        'from': 'web',
        'gaia_source': 'main_web',
        'web_location': 333.976,
        'w_rid': params['w_rid'],
        'wts': params['wts'],
      },
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': res.data['data'],
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }
}
