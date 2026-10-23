import 'package:pilipala/models/json_field.dart';
import 'package:pilipala/models/member/info.dart';

import 'opus.dart';

class ReadDataModel {
  ReadDataModel({
    this.cvid,
    this.readInfo,
    this.readViewInfo,
    this.upInfo,
    this.catalogList,
    this.recommendInfoList,
    this.hiddenInteraction,
    this.isModern,
  });

  int? cvid;
  ReadInfo? readInfo;
  Map? readViewInfo;
  Map? upInfo;
  List<dynamic>? catalogList;
  List<dynamic>? recommendInfoList;
  bool? hiddenInteraction;
  bool? isModern;

  ReadDataModel.fromJson(Map<String, dynamic> json) {
    cvid = asInt(json['cvid']);
    final Map<String, dynamic>? readInfoJson = asMap(json['readInfo']);
    readInfo = readInfoJson != null ? ReadInfo.fromJson(readInfoJson) : null;
    readViewInfo = asMap(json['readViewInfo']);
    upInfo = asMap(json['upInfo']);
    catalogList = json['catalogList'] is List ? json['catalogList'] : <dynamic>[];
    recommendInfoList =
        json['recommendInfoList'] is List ? json['recommendInfoList'] : <dynamic>[];
    hiddenInteraction = asBool(json['hiddenInteraction']);
    isModern = asBool(json['isModern']);
  }
}

class ReadInfo {
  ReadInfo({
    this.id,
    this.category,
    this.title,
    this.summary,
    this.bannerUrl,
    this.author,
    this.publishTime,
    this.ctime,
    this.mtime,
    this.stats,
    this.attributes,
    this.words,
    this.originImageUrls,
    this.content,
    this.opus,
    this.dynIdStr,
    this.totalArtNum,
  });

  int? id;
  Map? category;
  String? title;
  String? summary;
  String? bannerUrl;
  Author? author;
  int? publishTime;
  int? ctime;
  int? mtime;
  Map? stats;
  int? attributes;
  int? words;
  List<String>? originImageUrls;
  String? content;
  Opus? opus;
  String? dynIdStr;
  int? totalArtNum;

  ReadInfo.fromJson(Map<String, dynamic> json) {
    id = asInt(json['id']);
    category = asMap(json['category']);
    title = asStr(json['title']);
    summary = asStr(json['summary']);
    bannerUrl = asStr(json['banner_url']);
    // author 在部分老文章里缺失，原实现无条件 Author.fromJson(null) 会直接抛
    final Map<String, dynamic>? authorJson = asMap(json['author']);
    author = authorJson != null ? Author.fromJson(authorJson) : null;
    publishTime = asInt(json['publish_time']);
    ctime = asInt(json['ctime']);
    mtime = asInt(json['mtime']);
    stats = asMap(json['stats']);
    attributes = asInt(json['attributes']);
    words = asInt(json['words']);
    final dynamic originImages = json['origin_image_urls'];
    originImageUrls = originImages is List
        ? originImages.map((e) => asStr(e) ?? '').toList()
        : <String>[];
    content = asStr(json['content']);
    final Map<String, dynamic>? opusJson = asMap(json['opus']);
    opus = opusJson != null ? Opus.fromJson(opusJson) : null;
    dynIdStr = asStr(json['dyn_id_str']);
    totalArtNum = asInt(json['total_art_num']);
  }
}

class Author {
  Author({
    this.mid,
    this.name,
    this.face,
    this.vip,
    this.fans,
    this.level,
  });

  int? mid;
  String? name;
  String? face;
  Vip? vip;
  int? fans;
  int? level;

  Author.fromJson(Map<String, dynamic> json) {
    mid = asInt(json['mid']);
    name = asStr(json['name']);
    face = asStr(json['face']);
    final Map<String, dynamic>? vipJson = asMap(json['vip']);
    vip = vipJson != null ? Vip.fromJson(vipJson) : null;
    fans = asInt(json['fans']);
    level = asInt(json['level']);
  }
}

class Opus {
  // "opus_id": 976625853207150600,
  // "opus_source": 2,
  // "title": "真的很想骂人 但又没什么好骂的",
  // "content": {
  //     "paragraphs": [{
  //         "para_type": 1,
  //         "text": {
  //             "nodes": [{
  //                 "node_type": 1,
  //                 "word": {
  //                     "words": "21年玩到今年4月的号没了  ow1的时候45的号 玩了三年  后面第9赛季一个英杰5的号（虽然是偷的 但我任何违规行为都没有还是给我封了）  最近玩的号叫velleity  只和队友打天梯以及训练赛 又没了 连带着我一个一把没玩过只玩过一场训练赛的小号也没了  实在是无话可说了...",
  //                     "font_size": 17,
  //                     "style": {},
  //                     "font_level": "regular"
  //                 }
  //             }]
  //         }
  //     }, {
  //         "para_type": 2,
  //         "pic": {
  //             "pics": [{
  //                 "url": "https:\u002F\u002Fi0.hdslb.com\u002Fbfs\u002Fnew_dyn\u002Fba4e57459451fe74dcb70fd20bde9823316082117.jpg",
  //                 "width": 1600,
  //                 "height": 1000,
  //                 "size": 588.482421875
  //             }],
  //             "style": 1
  //         }
  //     }, {
  //         "para_type": 1,
  //         "text": {
  //             "nodes": [{
  //                 "node_type": 1,
  //                 "word": {
  //                     "words": "\n",
  //                     "font_size": 17,
  //                     "style": {},
  //                     "font_level": "regular"
  //                 }
  //             }]
  //         }
  //     }, {
  //         "para_type": 2,
  //         "pic": {
  //             "pics": [{
  //                 "url": "https:\u002F\u002Fi0.hdslb.com\u002Fbfs\u002Fnew_dyn\u002F0945be6b621091ddb8189482a87a36fb316082117.jpg",
  //                 "width": 1600,
  //                 "height": 1002,
  //                 "size": 665.7861328125
  //             }],
  //             "style": 1
  //         }
  //     }, {
  //         "para_type": 1,
  //         "text": {
  //             "nodes": [{
  //                 "node_type": 1,
  //                 "word": {
  //                     "words": "\n",
  //                     "font_size": 17,
  //                     "style": {},
  //                     "font_level": "regular"
  //                 }
  //             }]
  //         }
  //     }, {
  //         "para_type": 2,
  //         "pic": {
  //             "pics": [{
  //                 "url": "https:\u002F\u002Fi0.hdslb.com\u002Fbfs\u002Fnew_dyn\u002Ffa60649f8786578a764a1e68a2c5d23f316082117.jpg",
  //                 "width": 1600,
  //                 "height": 999,
  //                 "size": 332.970703125
  //             }],
  //             "style": 1
  //         }
  //     }, {
  //         "para_type": 1,
  //         "text": {
  //             "nodes": [{
  //                 "node_type": 1,
  //                 "word": {
  //                     "words": "\n",
  //                     "font_size": 17,
  //                     "style": {},
  //                     "font_level": "regular"
  //                 }
  //             }]
  //         }
  //     }]
  // },
  // "pub_info": {
  //     "uid": 316082117,
  //     "pub_time": 1726226826
  // },
  // "article": {
  //     "category_id": 15,
  //     "cover": [{
  //         "url": "https:\u002F\u002Fi0.hdslb.com\u002Fbfs\u002Fnew_dyn\u002Fbanner\u002Feb10074186a62f98c18e1b5b9deb38be316082117.png",
  //         "width": 1071,
  //         "height": 315,
  //         "size": 225.625
  //     }]
  // },
  // "version": {
  //     "cvid": 38660379,
  //     "version_id": 101683514411343360
  // }
  Opus({
    this.opusId,
    this.opusSource,
    this.title,
    this.content,
  });

  int? opusId;
  int? opusSource;
  String? title;
  Content? content;

  Opus.fromJson(Map<String, dynamic> json) {
    opusId = asInt(json['opus_id']);
    opusSource = asInt(json['opus_source']);
    title = asStr(json['title']);
    final Map<String, dynamic>? contentJson = asMap(json['content']);
    content = contentJson != null ? Content.fromJson(contentJson) : null;
  }
}

class Content {
  Content({
    this.paragraphs,
  });

  List<ModuleParagraph>? paragraphs;

  Content.fromJson(Map<String, dynamic> json) {
    paragraphs = <ModuleParagraph>[];
    for (final Map<String, dynamic> item in asMapList(json['paragraphs'])) {
      try {
        paragraphs!.add(ModuleParagraph.fromJson(item));
      } catch (_) {
        // 单个段落结构异常时跳过，正文其余部分照常显示
      }
    }
  }
}
