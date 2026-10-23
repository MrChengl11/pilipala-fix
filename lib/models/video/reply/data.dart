import 'package:pilipala/models/video/reply/item.dart';

import 'config.dart';
import 'page.dart';
import 'upper.dart';

class ReplyData {
  ReplyData({
    this.page,
    this.config,
    this.replies,
    this.topReplies,
    this.upper,
  });

  ReplyPage? page;
  ReplyConfig? config;
  late List<ReplyItemModel>? replies;
  late List<ReplyItemModel>? topReplies;
  ReplyUpper? upper;

  ReplyData.fromJson(Map<String, dynamic> json) {
    // 接口异常（如视频被删/被限制）时 page/config/upper 可能缺失，逐项判空，
    // 否则 ReplyPage.fromJson(null) 会直接抛 TypeError 导致评论区白屏。
    final dynamic upperJson = json['upper'];
    final dynamic upperMid = upperJson is Map ? upperJson['mid'] : null;
    page = json['page'] != null ? ReplyPage.fromJson(json['page']) : null;
    config =
        json['config'] != null ? ReplyConfig.fromJson(json['config']) : null;
    replies = json['replies'] != null
        ? json['replies']
            .map<ReplyItemModel>(
                (item) => ReplyItemModel.fromJson(item, upperMid))
            .toList()
        : [];
    topReplies = json['top_replies'] != null
        ? json['top_replies']
            .map<ReplyItemModel>((item) => ReplyItemModel.fromJson(
                item, upperMid,
                isTopStatus: true))
            .toList()
        : [];
    upper = upperJson != null ? ReplyUpper.fromJson(upperJson) : null;
  }
}
