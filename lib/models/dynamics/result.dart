import 'dart:convert';
// ---------------------------------------------------------------------------
// 反序列化容错工具
// 同一个字段在不同端/版本上可能返回 int / String / double / bool（例如
// module_author.pub_ts、live_play_info.live_id、stat.danmaku 等），直接赋值给
// 严格类型字段会抛 "type 'String' is not a subtype of type 'int?'"，并让整页
// 动态解析失败（动态 tab 整页报错）。统一从这里做类型归一。
// ---------------------------------------------------------------------------
int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString().trim());
}

/// 时间戳专用：0 与无法解析的值都当作「无」，避免显示 1970 年
int? asTs(dynamic v) {
  final int? i = asInt(v);
  return (i == null || i == 0) ? null : i;
}

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
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

class DynamicsDataModel {
  DynamicsDataModel({
    this.hasMore,
    this.items,
    this.offset,
  });
  bool? hasMore;
  List<DynamicItemModel>? items;
  String? offset;

  DynamicsDataModel.fromJson(Map<String, dynamic> json) {
    hasMore = asBool(json['has_more']);
    items = json['items'] is List
        ? (json['items'] as List)
            .map<DynamicItemModel>((e) => DynamicItemModel.fromJson(e))
            .toList()
        : <DynamicItemModel>[];
    offset = asStr(json['offset']);
  }
}

// 单个动态
class DynamicItemModel {
  DynamicItemModel({
    this.basic,
    this.idStr,
    this.modules,
    this.orig,
    this.type,
    this.visible,
  });

  Map? basic;
  String? idStr;
  ItemModulesModel? modules;
  ItemOrigModel? orig;
  String? type;
  bool? visible;

  DynamicItemModel.fromJson(Map<String, dynamic> json) {
    basic = json['basic'] is Map ? json['basic'] : null;
    idStr = asStr(json['id_str']);
    modules = json['modules'] == null
        ? null
        : ItemModulesModel.fromJson(json['modules']);
    orig = json['orig'] != null ? ItemOrigModel.fromJson(json['orig']) : null;
    type = asStr(json['type']);
    visible = asBool(json['visible']);
  }
}

class ItemOrigModel {
  ItemOrigModel({
    this.basic,
    this.isStr,
    this.modules,
    this.type,
    this.visible,
  });

  Map? basic;
  String? isStr;
  ItemModulesModel? modules;
  String? type;
  bool? visible;

  ItemOrigModel.fromJson(Map<String, dynamic> json) {
    basic = json['basic'] is Map ? json['basic'] : null;
    isStr = asStr(json['is_str']);
    modules = json['modules'] == null
        ? null
        : ItemModulesModel.fromJson(json['modules']);
    type = asStr(json['type']);
    visible = asBool(json['visible']);
  }
}

// 单个动态详情
class ItemModulesModel {
  ItemModulesModel({
    this.moduleAuthor,
    this.moduleDynamic,
    // this.moduleInter,
    this.moduleStat,
    this.moduleTag,
  });

  ModuleAuthorModel? moduleAuthor;
  ModuleDynamicModel? moduleDynamic;
  // ModuleInterModel? moduleInter;
  ModuleStatModel? moduleStat;
  Map? moduleTag;

  ItemModulesModel.fromJson(Map<String, dynamic> json) {
    moduleAuthor = json['module_author'] != null
        ? ModuleAuthorModel.fromJson(json['module_author'])
        : null;
    moduleDynamic = json['module_dynamic'] != null
        ? ModuleDynamicModel.fromJson(json['module_dynamic'])
        : null;
    // moduleInter = ModuleInterModel.fromJson(json['module_interaction']);
    moduleStat = json['module_stat'] != null
        ? ModuleStatModel.fromJson(json['module_stat'])
        : null;
    moduleTag = json['module_tag'] is Map ? json['module_tag'] : null;
  }
}

// 单个动态详情 - 作者信息
class ModuleAuthorModel {
  ModuleAuthorModel({
    // this.avatar,
    // this.decorate,
    this.face,
    this.following,
    this.jumpUrl,
    this.label,
    this.mid,
    this.name,
    // this.officialVerify,
    // this.pandant,
    this.pubAction,
    // this.pubLocationText,
    this.pubTime,
    this.pubTs,
    this.type,
    this.vip,
  });

  String? face;
  bool? following;
  String? jumpUrl;
  String? label;
  int? mid;
  String? name;
  String? pubAction;
  String? pubTime;
  int? pubTs;
  String? type;
  Map? vip;

  ModuleAuthorModel.fromJson(Map<String, dynamic> json) {
    face = asStr(json['face']);
    following = asBool(json['following']);
    jumpUrl = asStr(json['jump_url']);
    label = asStr(json['label']);
    mid = asInt(json['mid']);
    name = asStr(json['name']);
    pubAction = asStr(json['pub_action']);
    pubTime = asStr(json['pub_time']);
    // 接口有时把时间戳返回成 String，统一走容错解析
    pubTs = asTs(json['pub_ts']);
    type = asStr(json['type']);
    vip = json['vip'] is Map ? json['vip'] : null;
  }
}

// 单个动态详情 - 动态信息
class ModuleDynamicModel {
  ModuleDynamicModel({
    this.additional,
    this.desc,
    this.major,
    this.topic,
  });

  DynamicAddModel? additional;
  DynamicDescModel? desc;
  DynamicMajorModel? major;
  DynamicTopicModel? topic;

  ModuleDynamicModel.fromJson(Map<String, dynamic> json) {
    additional = json['additional'] != null
        ? DynamicAddModel.fromJson(json['additional'])
        : null;
    desc =
        json['desc'] != null ? DynamicDescModel.fromJson(json['desc']) : null;
    if (json['major'] != null) {
      major = DynamicMajorModel.fromJson(json['major']);
    }
    topic = json['topic'] != null
        ? DynamicTopicModel.fromJson(json['topic'])
        : null;
  }
}

// 单个动态详情 - 评论？信息
// class ModuleInterModel {
//   ModuleInterModel({

//   });

//   ModuleInterModel.fromJson(Map<String, dynamic> json) {

//   }
// }
class DynamicAddModel {
  DynamicAddModel({
    this.type,
    this.vote,
    this.ugc,
    this.reserve,
    this.goods,
  });

  String? type;
  Vote? vote;
  Ugc? ugc;
  Reserve? reserve;
  Good? goods;

  /// TODO 比赛vs
  String? match;

  /// TODO 游戏信息
  String? common;

  DynamicAddModel.fromJson(Map<String, dynamic> json) {
    type = asStr(json['type']);
    vote = json['vote'] != null ? Vote.fromJson(json['vote']) : null;
    ugc = json['ugc'] != null ? Ugc.fromJson(json['ugc']) : null;
    reserve =
        json['reserve'] != null ? Reserve.fromJson(json['reserve']) : null;
    goods = json['goods'] != null ? Good.fromJson(json['goods']) : null;
  }
}

class Vote {
  Vote({
    this.choiceCnt,
    this.defaultShare,
    this.share,
    this.endTime,
    this.joinNum,
    this.status,
    this.type,
    this.uid,
    this.voteId,
  });

  int? choiceCnt;
  String? share;
  int? defaultShare;
  int? endTime;
  int? joinNum;
  int? status;
  int? type;
  int? uid;
  int? voteId;

  Vote.fromJson(Map<String, dynamic> json) {
    choiceCnt = asInt(json['choice_cnt']);
    share = asStr(json['share']);
    defaultShare = asInt(json['default_share']);
    endTime = asTs(json['end_time']);
    joinNum = asInt(json['join_num']);
    status = asInt(json['status']);
    type = asInt(json['type']);
    uid = asInt(json['uid']);
    voteId = asInt(json['vote_id']);
  }
}

class Ugc {
  Ugc({
    this.cover,
    this.descSecond,
    this.duration,
    this.headText,
    this.idStr,
    this.jumpUrl,
    this.multiLine,
    this.title,
  });

  String? cover;
  String? descSecond;
  String? duration;
  String? headText;
  String? idStr;
  String? jumpUrl;
  bool? multiLine;
  String? title;

  Ugc.fromJson(Map<String, dynamic> json) {
    cover = asStr(json['cover']);
    descSecond = asStr(json['desc_second']);
    duration = asStr(json['duration']);
    headText = asStr(json['head_text']);
    idStr = asStr(json['id_str']);
    jumpUrl = asStr(json['jump_url']);
    multiLine = asBool(json['multi_line']);
    title = asStr(json['title']);
  }
}

class Reserve {
  Reserve({
    this.button,
    this.desc1,
    this.desc2,
    this.jumpUrl,
    this.reserveTotal,
    this.rid,
    this.state,
    this.stype,
    this.title,
    this.upMid,
  });

  Map? button;
  Map? desc1;
  Map? desc2;
  String? jumpUrl;
  int? reserveTotal;
  int? rid;
  int? state;
  int? stype;
  String? title;
  int? upMid;

  Reserve.fromJson(Map<String, dynamic> json) {
    button = json['button'] is Map ? json['button'] : null;
    desc1 = json['desc1'] is Map ? json['desc1'] : null;
    desc2 = json['desc2'] is Map ? json['desc2'] : null;
    jumpUrl = asStr(json['jump_url']);
    reserveTotal = asInt(json['reserve_total']);
    rid = asInt(json['rid']);
    state = asInt(json['state']);
    stype = asInt(json['stype']);
    title = asStr(json['title']);
    upMid = asInt(json['up_mid']);
  }
}

class Good {
  Good({
    this.headIcon,
    this.headText,
    this.items,
    this.jumpUrl,
  });

  String? headIcon;
  String? headText;
  List<GoodItem>? items;
  String? jumpUrl;

  Good.fromJson(Map<String, dynamic> json) {
    headIcon = asStr(json['head_icon']);
    headText = asStr(json['head_text']);
    items = json['items'] is List
        ? (json['items'] as List)
            .map<GoodItem>((e) => GoodItem.fromJson(e))
            .toList()
        : <GoodItem>[];
    jumpUrl = asStr(json['jump_url']);
  }
}

class GoodItem {
  GoodItem({
    this.brief,
    this.cover,
    this.id,
    this.jumpDesc,
    this.jumpUrl,
    this.name,
    this.price,
  });

  String? brief;
  String? cover;
  dynamic id;
  String? jumpDesc;
  String? jumpUrl;
  String? name;
  String? price;

  GoodItem.fromJson(Map<String, dynamic> json) {
    brief = asStr(json['brief']);
    cover = asStr(json['cover']);
    id = json['id'];
    jumpDesc = asStr(json['jump_desc']);
    jumpUrl = asStr(json['jump_url']);
    name = asStr(json['name']);
    price = asStr(json['price']);
  }
}

class DynamicDescModel {
  DynamicDescModel({
    this.richTextNodes,
    this.text,
  });

  List<RichTextNodeItem>? richTextNodes;
  String? text;

  DynamicDescModel.fromJson(Map<String, dynamic> json) {
    richTextNodes = json['rich_text_nodes'] != null
        ? json['rich_text_nodes']
            .map<RichTextNodeItem>((e) => RichTextNodeItem.fromJson(e))
            .toList()
        : [];
    text = asStr(json['text']);
  }
}

//
class DynamicMajorModel {
  DynamicMajorModel({
    this.archive,
    this.draw,
    this.ugcSeason,
    this.opus,
    this.pgc,
    this.liveRcmd,
    this.live,
    this.none,
    this.type,
    this.courses,
    this.common,
    this.music,
  });

  DynamicArchiveModel? archive;
  DynamicDrawModel? draw;
  DynamicArchiveModel? ugcSeason;
  DynamicOpusModel? opus;
  DynamicArchiveModel? pgc;
  DynamicLiveModel? liveRcmd;
  DynamicLive2Model? live;
  DynamicNoneModel? none;
  // MAJOR_TYPE_DRAW 图片
  // MAJOR_TYPE_ARCHIVE 视频
  // MAJOR_TYPE_OPUS 图文/文章
  String? type;
  Map? courses;
  Map? common;
  Map? music;

  DynamicMajorModel.fromJson(Map<String, dynamic> json) {
    archive = json['archive'] != null
        ? DynamicArchiveModel.fromJson(json['archive'])
        : null;
    draw =
        json['draw'] != null ? DynamicDrawModel.fromJson(json['draw']) : null;
    ugcSeason = json['ugc_season'] != null
        ? DynamicArchiveModel.fromJson(json['ugc_season'])
        : null;
    opus =
        json['opus'] != null ? DynamicOpusModel.fromJson(json['opus']) : null;
    pgc =
        json['pgc'] != null ? DynamicArchiveModel.fromJson(json['pgc']) : null;
    liveRcmd = json['live_rcmd'] != null
        ? DynamicLiveModel.fromJson(json['live_rcmd'])
        : null;
    live =
        json['live'] != null ? DynamicLive2Model.fromJson(json['live']) : null;
    none =
        json['none'] != null ? DynamicNoneModel.fromJson(json['none']) : null;
    type = asStr(json['type']);
    courses = json['courses'] ?? {};
    common = json['common'] ?? {};
    music = json['music'] ?? {};
  }
}

class DynamicTopicModel {
  DynamicTopicModel({
    this.id,
    this.jumpUrl,
    this.name,
  });

  int? id;
  String? jumpUrl;
  String? name;

  DynamicTopicModel.fromJson(Map<String, dynamic> json) {
    id = asInt(json['id']);
    jumpUrl = asStr(json['jump_url']);
    name = asStr(json['name']);
  }
}

class DynamicArchiveModel {
  DynamicArchiveModel({
    this.aid,
    this.badge,
    this.bvid,
    this.cover,
    this.desc,
    this.disablePreview,
    this.durationText,
    this.jumpUrl,
    this.stat,
    this.title,
    this.type,
    this.epid,
    this.seasonId,
  });

  int? aid;
  Map? badge;
  String? bvid;
  String? cover;
  String? desc;
  int? disablePreview;
  String? durationText;
  String? jumpUrl;
  Stat? stat;
  String? title;
  int? type;
  int? epid;
  int? seasonId;

  DynamicArchiveModel.fromJson(Map<String, dynamic> json) {
    aid = asInt(json['aid']);
    badge = json['badge'] is Map ? json['badge'] : null;
    // 旧实现 json['epid'].toString() 在 epid 为空时会把 bvid 写成字符串 "null"
    bvid = asStr(json['bvid']) ?? asStr(json['epid']) ?? '';
    cover = asStr(json['cover']);
    disablePreview = asInt(json['disable_preview']);
    durationText = asStr(json['duration_text']);
    jumpUrl = asStr(json['jump_url']);
    stat = json['stat'] is Map ? Stat.fromJson(json['stat']) : null;
    title = asStr(json['title']);
    type = asInt(json['type']);
    epid = asInt(json['epid']);
    seasonId = asInt(json['season_id']);
  }
}

class DynamicDrawModel {
  DynamicDrawModel({
    this.id,
    this.items,
  });

  int? id;
  List<DynamicDrawItemModel>? items;

  DynamicDrawModel.fromJson(Map<String, dynamic> json) {
    id = asInt(json['id']);
    // ignore: prefer_null_aware_operators
    items = json['items'] != null
        ? json['items']
            .map<DynamicDrawItemModel>((e) => DynamicDrawItemModel.fromJson(e))
            .toList()
        : null;
  }
}

class DynamicOpusModel {
  DynamicOpusModel({
    this.jumpUrl,
    this.pics,
    this.summary,
    this.title,
  });

  String? jumpUrl;
  List<OpusPicsModel>? pics;
  SummaryModel? summary;
  String? title;
  DynamicOpusModel.fromJson(Map<String, dynamic> json) {
    jumpUrl = asStr(json['jump_url']);
    pics = json['pics'] is List
        ? (json['pics'] as List)
            .map<OpusPicsModel>((e) => OpusPicsModel.fromJson(e))
            .toList()
        : <OpusPicsModel>[];
    summary =
        json['summary'] != null ? SummaryModel.fromJson(json['summary']) : null;
    title = asStr(json['title']);
  }
}

class SummaryModel {
  SummaryModel({
    this.richTextNodes,
    this.text,
  });

  List<RichTextNodeItem>? richTextNodes;
  String? text;

  SummaryModel.fromJson(Map<String, dynamic> json) {
    richTextNodes = json['rich_text_nodes'] is List
        ? (json['rich_text_nodes'] as List)
            .map<RichTextNodeItem>((e) => RichTextNodeItem.fromJson(e))
            .toList()
        : <RichTextNodeItem>[];
    text = asStr(json['text']);
  }
}

class RichTextNodeItem {
  RichTextNodeItem({
    this.emoji,
    this.origText,
    this.text,
    this.type,
    this.rid,
  });
  Emoji? emoji;
  String? origText;
  String? text;
  String? type;
  String? rid;

  RichTextNodeItem.fromJson(Map<String, dynamic> json) {
    emoji = json['emoji'] != null ? Emoji.fromJson(json['emoji']) : null;
    origText = asStr(json['orig_text']);
    text = asStr(json['text']);
    type = asStr(json['type']);
    rid = asStr(json['rid']);
  }
}

class Emoji {
  Emoji({
    this.iconUrl,
    this.size,
    this.text,
    this.type,
  });

  String? iconUrl;
  double? size;
  String? text;
  int? type;
  Emoji.fromJson(Map<String, dynamic> json) {
    iconUrl = asStr(json['icon_url']);
    size = asDouble(json['size']);
    text = asStr(json['text']);
    type = asInt(json['type']);
  }
}

class DynamicNoneModel {
  DynamicNoneModel({
    this.tips,
  });
  String? tips;
  DynamicNoneModel.fromJson(Map<String, dynamic> json) {
    tips = asStr(json['tips']);
  }
}

class OpusPicsModel {
  OpusPicsModel({
    this.width,
    this.height,
    this.size,
    this.src,
    this.url,
  });

  int? width;
  int? height;
  int? size;
  String? src;
  String? url;

  OpusPicsModel.fromJson(Map<String, dynamic> json) {
    width = asInt(json['width']);
    height = asInt(json['height']);
    size = asInt(json['size']) ?? 0;
    src = asStr(json['src']);
    url = asStr(json['url']);
  }
}

class DynamicDrawItemModel {
  DynamicDrawItemModel({
    this.height,
    this.size,
    this.src,
    this.tags,
    this.width,
  });
  int? height;
  int? size;
  String? src;
  List? tags;
  int? width;
  DynamicDrawItemModel.fromJson(Map<String, dynamic> json) {
    height = asInt(json['height']);
    size = asInt(json['size']) ?? 0;
    src = asStr(json['src']);
    tags = json['tags'] is List ? json['tags'] : null;
    width = asInt(json['width']);
  }
}

class DynamicLiveModel {
  DynamicLiveModel({
    this.content,
  });

  String? content;
  int? type;
  Map? livePlayInfo;
  int? uid;
  String? parentAreaName;
  int? roomId;
  String? liveId;
  int? liveStatus;
  String? cover;
  int? online;
  String? areaName;
  String? title;
  int? liveStartTime;
  Map? watchedShow;

  DynamicLiveModel.fromJson(Map<String, dynamic> json) {
    content = asStr(json['content']);
    final dynamic rawContent = json['content'];
    if (rawContent is String) {
      try {
        final dynamic decoded = jsonDecode(rawContent);
        if (decoded is Map) {
          type = asInt(decoded['type']);
          final dynamic rawPlayInfo = decoded['live_play_info'];
          if (rawPlayInfo is Map) {
            final Map livePlayInfo = rawPlayInfo;
            uid = asInt(livePlayInfo['uid']);
            parentAreaName = asStr(livePlayInfo['parent_area_name']);
            roomId = asInt(livePlayInfo['room_id']);
            liveId = asStr(livePlayInfo['live_id']);
            liveStatus = asInt(livePlayInfo['live_status']);
            cover = asStr(livePlayInfo['cover']);
            online = asInt(livePlayInfo['online']);
            areaName = asStr(livePlayInfo['area_name']);
            title = asStr(livePlayInfo['title']);
            liveStartTime = asInt(livePlayInfo['live_start_time']);
            watchedShow = livePlayInfo['watched_show'] is Map
                ? livePlayInfo['watched_show']
                : null;
          }
        }
      } catch (err) {
        // content 不是合法 JSON 时只丢直播信息，不能让整页动态解析失败
        print('DynamicLiveModel.fromJson decode content failed: $err');
      }
    }
  }
}

class DynamicLive2Model {
  DynamicLive2Model({
    this.badge,
    this.cover,
    this.descFirst,
    this.descSecond,
    this.id,
    this.jumpUrl,
    this.liveState,
    this.reserveType,
    this.title,
  });

  Map? badge;
  String? cover;
  String? descFirst;
  String? descSecond;
  int? id;
  String? jumpUrl;
  int? liveState;
  int? reserveType;
  String? title;

  DynamicLive2Model.fromJson(Map<String, dynamic> json) {
    badge = json['badge'] is Map ? json['badge'] : null;
    cover = asStr(json['cover']);
    descFirst = asStr(json['desc_first']);
    descSecond = asStr(json['desc_second']);
    id = asInt(json['id']);
    jumpUrl = asStr(json['jump_url']);
    liveState = asInt(json['live_state']);
    reserveType = asInt(json['reserve_type']);
    title = asStr(json['title']);
  }
}

// 动态状态 转发、评论、点赞
class ModuleStatModel {
  ModuleStatModel({
    this.comment,
    this.forward,
    this.like,
  });

  Comment? comment;
  ForWard? forward;
  Like? like;

  ModuleStatModel.fromJson(Map<String, dynamic> json) {
    comment = json['comment'] == null
        ? null
        : Comment.fromJson(json['comment']);
    forward = json['forward'] == null
        ? null
        : ForWard.fromJson(json['forward']);
    like = json['like'] == null ? null : Like.fromJson(json['like']);
  }
}

// 动态状态 评论
class Comment {
  Comment({
    this.count,
    this.forbidden,
  });

  String? count;
  bool? forbidden;

  Comment.fromJson(Map<String, dynamic> json) {
    // 旧实现 count 为 null 时会得到字符串 "null"
    final int? c = asInt(json['count']);
    count = (c == null || c == 0) ? null : c.toString();
    forbidden = asBool(json['forbidden']);
  }
}

class ForWard {
  ForWard({this.count, this.forbidden});
  String? count;
  bool? forbidden;

  ForWard.fromJson(Map<String, dynamic> json) {
    final int? c = asInt(json['count']);
    count = (c == null || c == 0) ? null : c.toString();
    forbidden = asBool(json['forbidden']);
  }
}

// 动态状态 点赞
class Like {
  Like({
    this.count,
    this.forbidden,
    this.status,
  });

  String? count;
  bool? forbidden;
  bool? status;

  Like.fromJson(Map<String, dynamic> json) {
    final int? c = asInt(json['count']);
    count = (c == null || c == 0) ? null : c.toString();
    forbidden = asBool(json['forbidden']);
    status = asBool(json['status']);
  }
}

class Stat {
  Stat({
    this.danmaku,
    this.play,
  });

  String? danmaku;
  String? play;

  Stat.fromJson(Map<String, dynamic> json) {
    danmaku = asStr(json['danmaku']);
    play = asStr(json['play']);
  }
}
