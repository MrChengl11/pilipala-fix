import 'package:pilipala/models/json_field.dart';

// ---------------------------------------------------------------------------
// 图文（opus）模型。
//
// 接口字段类型不稳定：basic.uid 实际返回 **字符串**（"130061363"），而模型声明
// 是 int? → 直接赋值抛 "type 'String' is not a subtype of type 'int?'"，被
// http 层 catch 后整篇图文变成「专栏内容解析失败」，这是 /opus 打不开的直接原因。
// 这里统一用 json_field.dart 的 asInt/asDouble/asStr/asBool/asMap 做归一。
// 同时补齐各层判空：module/paragraph/pic 缺字段都不应该让整篇图文解析失败。
// ---------------------------------------------------------------------------
class OpusDataModel {
  OpusDataModel({
    this.id,
    this.detail,
    this.type,
    this.theme,
    this.themeMode,
  });

  String? id;
  OpusDetailDataModel? detail;
  int? type;
  String? theme;
  String? themeMode;

  OpusDataModel.fromJson(Map<String, dynamic> json) {
    id = asStr(json['id']);
    final Map<String, dynamic>? detailJson = asMap(json['detail']);
    detail =
        detailJson != null ? OpusDetailDataModel.fromJson(detailJson) : null;
    type = asInt(json['type']);
    theme = asStr(json['theme']);
    themeMode = asStr(json['themeMode']);
  }
}

class OpusDetailDataModel {
  OpusDetailDataModel({
    this.basic,
    this.idStr,
    this.modules,
    this.type,
  });

  Basic? basic;
  String? idStr;
  List<OpusModuleDataModel>? modules;
  int? type;

  OpusDetailDataModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? basicJson = asMap(json['basic']);
    basic = basicJson != null ? Basic.fromJson(basicJson) : null;
    idStr = asStr(json['id_str']);
    modules = <OpusModuleDataModel>[];
    for (final Map<String, dynamic> item in asMapList(json['modules'])) {
      try {
        modules!.add(OpusModuleDataModel.fromJson(item));
      } catch (_) {
        // 单个 module 结构异常时丢掉它，不牵连整篇图文
      }
    }
    type = asInt(json['type']);
  }
}

class Basic {
  Basic({
    this.commentIdStr,
    this.commentType,
    this.ridStr,
    this.title,
    this.uid,
  });

  String? commentIdStr;
  int? commentType;
  String? ridStr;
  String? title;
  int? uid;

  Basic.fromJson(Map<String, dynamic> json) {
    commentIdStr = asStr(json['comment_id_str']);
    commentType = asInt(json['comment_type']);
    ridStr = asStr(json['rid_str']);
    title = asStr(json['title']);
    uid = asInt(json['uid']);
  }
}

class OpusModuleDataModel {
  OpusModuleDataModel({
    this.moduleTitle,
    this.moduleAuthor,
    this.moduleContent,
    this.moduleExtend,
    this.moduleBottom,
    this.moduleStat,
  });

  ModuleTop? moduleTop;
  ModuleTitle? moduleTitle;
  ModuleAuthor? moduleAuthor;
  ModuleContent? moduleContent;
  ModuleExtend? moduleExtend;
  ModuleBottom? moduleBottom;
  ModuleStat? moduleStat;

  OpusModuleDataModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? topJson = asMap(json['module_top']);
    moduleTop = topJson != null ? ModuleTop.fromJson(topJson) : null;
    final Map<String, dynamic>? titleJson = asMap(json['module_title']);
    moduleTitle = titleJson != null ? ModuleTitle.fromJson(titleJson) : null;
    final Map<String, dynamic>? authorJson = asMap(json['module_author']);
    moduleAuthor = authorJson != null ? ModuleAuthor.fromJson(authorJson) : null;
    final Map<String, dynamic>? contentJson = asMap(json['module_content']);
    moduleContent =
        contentJson != null ? ModuleContent.fromJson(contentJson) : null;
    final Map<String, dynamic>? extendJson = asMap(json['module_extend']);
    moduleExtend = extendJson != null ? ModuleExtend.fromJson(extendJson) : null;
    final Map<String, dynamic>? bottomJson = asMap(json['module_bottom']);
    moduleBottom = bottomJson != null ? ModuleBottom.fromJson(bottomJson) : null;
    final Map<String, dynamic>? statJson = asMap(json['module_stat']);
    moduleStat = statJson != null ? ModuleStat.fromJson(statJson) : null;
  }
}

class ModuleTop {
  ModuleTop({
    this.type,
    this.video,
  });

  int? type;
  Map? video;

  ModuleTop.fromJson(Map<String, dynamic> json) {
    type = asInt(json['type']);
    video = asMap(json['video']);
  }
}

class ModuleTitle {
  ModuleTitle({
    this.text,
  });

  String? text;

  ModuleTitle.fromJson(Map<String, dynamic> json) {
    text = asStr(json['text']);
  }
}

class ModuleAuthor {
  ModuleAuthor({
    this.face,
    this.mid,
    this.name,
    this.pubTime,
  });

  String? face;
  int? mid;
  String? name;
  String? pubTime;

  ModuleAuthor.fromJson(Map<String, dynamic> json) {
    face = asStr(json['face']);
    mid = asInt(json['mid']);
    name = asStr(json['name']);
    pubTime = asStr(json['pub_time']);
  }
}

class ModuleContent {
  ModuleContent({
    this.paragraphs,
    this.moduleType,
  });

  List<ModuleParagraph>? paragraphs;
  String? moduleType;

  ModuleContent.fromJson(Map<String, dynamic> json) {
    paragraphs = <ModuleParagraph>[];
    for (final Map<String, dynamic> item in asMapList(json['paragraphs'])) {
      try {
        paragraphs!.add(ModuleParagraph.fromJson(item));
      } catch (_) {
        // 单个段落异常时跳过，正文其余部分照常显示
      }
    }
    moduleType = asStr(json['module_type']);
  }
}

class ModuleParagraph {
  ModuleParagraph({
    this.align,
    this.paraType,
    this.pic,
    this.text,
  });

  // 0 左对齐  1 居中  2 右对齐
  int? align;
  int? paraType;
  Pics? pic;
  ModuleParagraphText? text;
  LinkCard? linkCard;

  ModuleParagraph.fromJson(Map<String, dynamic> json) {
    align = asInt(json['align']);
    final Map<String, dynamic>? linkCardJson = asMap(json['link_card']);
    paraType = json['para_type'] == null && linkCardJson != null
        ? 3
        : asInt(json['para_type']);
    final Map<String, dynamic>? picJson = asMap(json['pic']);
    pic = picJson != null ? Pics.fromJson(picJson) : null;
    final Map<String, dynamic>? textJson = asMap(json['text']);
    text = textJson != null ? ModuleParagraphText.fromJson(textJson) : null;
    linkCard = linkCardJson != null ? LinkCard.fromJson(linkCardJson) : null;
  }
}

class Pics {
  Pics({
    this.pics,
    this.style,
  });

  List<Pic>? pics;
  int? style;

  Pics.fromJson(Map<String, dynamic> json) {
    pics = <Pic>[];
    for (final Map<String, dynamic> item in asMapList(json['pics'])) {
      try {
        pics!.add(Pic.fromJson(item));
      } catch (_) {
        // 单张图片字段异常（缺 url/宽高）时跳过
      }
    }
    style = asInt(json['style']);
  }
}

class Pic {
  Pic({
    this.height,
    this.size,
    this.url,
    this.width,
    this.aspectRatio,
    this.scale,
  });

  int? height;
  double? size;
  String? url;
  int? width;
  double? aspectRatio;
  double? scale;

  Pic.fromJson(Map<String, dynamic> json) {
    height = asInt(json['height']);
    size = asDouble(json['size']);
    url = asStr(json['url']);
    width = asInt(json['width']);
    // 原来直接 json['width'] / json['height']：字段缺失时抛 NoSuchMethodError，
    // height 为 0 时抛 Infinity/NaN，交给 Image 渲染会崩。
    final int w = width ?? 0;
    final int h = height ?? 0;
    aspectRatio = (w > 0 && h > 0) ? w / h : null;
    scale = w > 0 ? customDivision(w, 600) : null;
  }
}

class LinkCard {
  LinkCard({
    this.cover,
    this.descSecond,
    this.duration,
    this.jumpUrl,
    this.title,
  });

  String? cover;
  String? descSecond;
  String? duration;
  String? jumpUrl;
  String? title;

  LinkCard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? card = asMap(json['card']);
    if (card == null) return;
    cover = asStr(card['cover']);
    descSecond = asStr(card['desc_second']);
    duration = asStr(card['duration']);
    jumpUrl = asStr(card['jump_url']);
    title = asStr(card['title']);
  }
}

class ModuleParagraphText {
  ModuleParagraphText({
    this.nodes,
  });

  List<ModuleParagraphTextNode>? nodes;

  ModuleParagraphText.fromJson(Map<String, dynamic> json) {
    nodes = <ModuleParagraphTextNode>[];
    for (final Map<String, dynamic> item in asMapList(json['nodes'])) {
      try {
        nodes!.add(ModuleParagraphTextNode.fromJson(item));
      } catch (_) {}
    }
  }
}

class ModuleParagraphTextNode {
  ModuleParagraphTextNode({
    this.type,
    this.nodeType,
    this.word,
  });

  String? type;
  int? nodeType;
  ModuleParagraphTextNodeWord? word;

  ModuleParagraphTextNode.fromJson(Map<String, dynamic> json) {
    type = asStr(json['type']);
    nodeType = asInt(json['node_type']);
    final Map<String, dynamic>? wordJson = asMap(json['word']);
    word = wordJson != null ? ModuleParagraphTextNodeWord.fromJson(wordJson) : null;
  }
}

class ModuleParagraphTextNodeWord {
  ModuleParagraphTextNodeWord({
    this.color,
    this.fontSize,
    this.style,
    this.words,
  });

  String? color;
  int? fontSize;
  ModuleParagraphTextNodeWordStyle? style;
  String? words;

  ModuleParagraphTextNodeWord.fromJson(Map<String, dynamic> json) {
    color = asStr(json['color']);
    fontSize = asInt(json['font_size']);
    final Map<String, dynamic>? styleJson = asMap(json['style']);
    style = styleJson != null
        ? ModuleParagraphTextNodeWordStyle.fromJson(styleJson)
        : null;
    words = asStr(json['words']);
  }
}

class ModuleParagraphTextNodeWordStyle {
  ModuleParagraphTextNodeWordStyle({
    this.bold,
  });

  bool? bold;

  ModuleParagraphTextNodeWordStyle.fromJson(Map<String, dynamic> json) {
    bold = asBool(json['bold']);
  }
}

class ModuleExtend {
  ModuleExtend({
    this.items,
  });

  List<ModuleExtendItem>? items;

  ModuleExtend.fromJson(Map<String, dynamic> json) {
    items = <ModuleExtendItem>[];
    for (final Map<String, dynamic> item in asMapList(json['items'])) {
      try {
        items!.add(ModuleExtendItem.fromJson(item));
      } catch (_) {}
    }
  }
}

class ModuleExtendItem {
  ModuleExtendItem({
    this.bizId,
    this.bizType,
    this.icon,
    this.jumpUrl,
    this.text,
  });

  dynamic bizId;
  int? bizType;
  dynamic icon;
  String? jumpUrl;
  String? text;

  ModuleExtendItem.fromJson(Map<String, dynamic> json) {
    bizId = json['biz_id'];
    bizType = asInt(json['biz_type']);
    icon = json['icon'];
    jumpUrl = asStr(json['jump_url']);
    text = asStr(json['text']);
  }
}

class ModuleBottom {
  ModuleBottom({
    this.shareInfo,
  });

  ShareInfo? shareInfo;

  ModuleBottom.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? shareJson = asMap(json['share_info']);
    shareInfo = shareJson != null ? ShareInfo.fromJson(shareJson) : null;
  }
}

class ShareInfo {
  ShareInfo({
    this.pic,
    this.summary,
    this.title,
  });

  String? pic;
  String? summary;
  String? title;

  ShareInfo.fromJson(Map<String, dynamic> json) {
    pic = asStr(json['pic']);
    summary = asStr(json['summary']);
    title = asStr(json['title']);
  }
}

class ModuleStat {
  ModuleStat({
    this.coin,
    this.comment,
    this.favorite,
    this.forward,
    this.like,
  });

  StatItem? coin;
  StatItem? comment;
  StatItem? favorite;
  StatItem? forward;
  StatItem? like;

  StatItem? _statItem(dynamic v) {
    final Map<String, dynamic>? m = asMap(v);
    return m != null ? StatItem.fromJson(m) : null;
  }

  ModuleStat.fromJson(Map<String, dynamic> json) {
    coin = _statItem(json['coin']);
    comment = _statItem(json['comment']);
    favorite = _statItem(json['favorite']);
    forward = _statItem(json['forward']);
    like = _statItem(json['like']);
  }
}

class StatItem {
  StatItem({
    this.count,
    this.forbidden,
    this.status,
  });

  int? count;
  bool? forbidden;
  bool? status;

  StatItem.fromJson(Map<String, dynamic> json) {
    count = asInt(json['count']);
    forbidden = asBool(json['forbidden']);
    status = asBool(json['status']);
  }
}

double customDivision(int a, int b) {
  if (b == 0) return 1.0;
  double result = a / b;
  if (result < 1) {
    return result;
  } else {
    return 1.0;
  }
}
