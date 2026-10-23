import 'package:flutter/material.dart';

class StyleString {
  static const double cardSpace = 8;
  static const double safeSpace = 12;
  static BorderRadius mdRadius = BorderRadius.circular(10);
  static const Radius imgRadius = Radius.circular(10);
  static const double aspectRatio = 16 / 10;

  /// 横向视频卡片（VideoCardH，排行榜/搜索结果等）右侧文字区的最小高度。
  ///
  /// 卡片结构见 lib/common/widgets/video_card_h.dart 的 VideoContent：
  /// Column[ 标题(maxLines:2), Spacer, [发布日期], [作者], 统计行 ]
  /// 原实现把整张卡片高度固定成封面高度，小屏 360dp 下文字区需要 ~95dp
  /// 而封面只有 ~90dp，导致 8~10px 的 RenderFlex overflow。
  ///
  /// [textScaler] 当前 TextScaler。
  /// [showPubdate] 是否显示发布日期行。
  /// [showOwner] 是否显示作者行。
  static double horizontalContentExtent(
    TextScaler textScaler, {
    bool showPubdate = false,
    bool showOwner = true,
  }) {
    // VideoContent 内部已统一用 height: 1.2 收紧行高（见 video_card_h.dart）。
    const double lineFactor = 1.2;
    // 标题：fontWeight.w500，默认字号 14，最多 2 行
    final double titleHeight = textScaler.scale(14) * lineFactor * 2;
    // 发布日期：fontSize 11
    final double pubdateHeight =
        showPubdate ? textScaler.scale(11) * lineFactor : 0;
    // 作者名：labelMedium (~12)
    final double ownerHeight =
        showOwner ? textScaler.scale(12) * lineFactor : 0;
    // 统计行：右侧「更多」IconButton 已从 24 收到 20
    const double statHeight = 20;
    // 标题与元信息之间的固定间隙 SizedBox(height: 2)
    const double gap = 2;
    return titleHeight + pubdateHeight + ownerHeight + statHeight + gap;
  }

  /// 视频/直播卡片中「图片下方文字区域」的估算高度。
  ///
  /// 历史实现里各页面各自写死 68 / 86 / 42 / 66 / 48 等魔法数字，
  /// 与实际内容（标题两行 + 统计行 + 作者行 + 更多按钮 24px）不一致，
  /// 导致 RenderFlex overflow（BOTTOM OVERFLOWED BY 8~10 PIXELS）。
  /// 这里按卡片结构逐项累加，并对标题/统计/作者行应用 textScaler。
  ///
  /// [crossAxisCount] 网格列数，1 为单列大卡。
  /// [textScaler] 当前 TextScaler，用于字体缩放时的高度校正。
  /// [hasStatLine] 是否为多列（多列卡片显示统计行，单列不显示）。
  static double videoContentExtent(
    int crossAxisCount,
    TextScaler textScaler, {
    bool hasStatLine = true,
  }) {
    // 文字行高系数：Flutter 默认 TextStyle height 约 1.2~1.43，取 1.4 保守估算。
    const double lineFactor = 1.4;
    // 标题字号（与 ThemeData 默认 titleSmall/bodyMedium 接近）
    final double titleFontSize = textScaler.scale(14);
    final double titleHeight = titleFontSize * lineFactor * 2; // maxLines: 2
    // 统计行 / 作者行字号
    final double metaFontSize = textScaler.scale(12);
    final double metaHeight = metaFontSize * lineFactor;
    // 作者行右侧「更多」IconButton 固定 24px，撑高整行
    const double moreBtnSize = 24;
    final double authorLineHeight =
        metaHeight > moreBtnSize ? metaHeight : moreBtnSize;

    // 内边距：多列 fromLTRB(5,8,5,4) / 单列 fromLTRB(9,9,9,4)
    const double padV = 12;
    // 标题与作者行之间的间隙：多列 SizedBox(2)，单列 SizedBox(4)
    final double gap = crossAxisCount == 1 ? 4 : 2;

    double total = padV + titleHeight + gap + authorLineHeight;
    if (crossAxisCount > 1 && hasStatLine) {
      total += metaHeight + 2; // SizedBox(height: 2) + 统计行
    }
    // 额外 2px 余量，避免亚像素取整再次溢出
    return total + 2;
  }
}

class Constants {
  // 27eb53fc9058f8c3  移动端 Android
  // 4409e2ce8ffd12b8  TV端
  static const String appKey = '4409e2ce8ffd12b8';
  // 59b43e04ad6965f34319062b478f83dd TV端
  static const String appSec = '59b43e04ad6965f34319062b478f83dd';
  static const String thirdSign = '04224646d1fea004e79606d3b038c84a';
  static const String thirdApi =
      'https://www.mcbbs.net/template/mcbbs/image/special_photo_bg.png';
}
