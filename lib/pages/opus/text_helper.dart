import 'package:flutter/material.dart';
import 'package:pilipala/models/read/opus.dart';

class TextHelper {
  static Alignment getAlignment(int? align) {
    switch (align) {
      case 1:
        return Alignment.center;
      case 0:
        return Alignment.centerLeft;
      case 2:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  /// 解析接口的 #RRGGBB / #RGB / #AARRGGBB / 无 # 前缀 颜色字符串。
  ///
  /// 原实现直接 `color.substring(1, 7)`：遇到 3 位色值（#fff）或长度不足的
  /// 字符串会抛 RangeError (start) "Only valid value is 0: 1"，整个图文页
  /// 直接红屏。这里改成按长度分支并 tryParse。
  static Color? parseHexColor(String? raw) {
    if (raw == null) return null;
    String hex = raw.trim();
    if (hex.isEmpty) return null;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substring(2);
    if (hex.length == 3) {
      // #RGB → #RRGGBB
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final int? value = int.tryParse(hex, radix: 16);
      return value != null ? Color(value) : null;
    }
    final int? value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  static TextStyle _textStyle(
      ModuleParagraphTextNode node, int? align, BuildContext context) {
    final ModuleParagraphTextNodeWord? word = node.word;
    final Color? color = parseHexColor(word?.color);
    return TextStyle(
      fontSize: word?.fontSize != null ? word!.fontSize! * 0.95 : 14,
      // 原来只判 bold != null，bold=false 时也会加粗
      fontWeight: word?.style?.bold == true
          ? FontWeight.bold
          : FontWeight.normal,
      height: align == 1 ? 2 : 1.5,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }

  static TextSpan buildTextSpan(
      ModuleParagraphTextNode node, int? align, BuildContext context) {
    if (node.nodeType != null) {
      return TextSpan(
        text: node.word?.words ?? '',
        style: _textStyle(node, align, context),
      );
    } else {
      switch (node.type) {
        case 'TEXT_NODE_TYPE_WORD':
          return TextSpan(
            text: node.word?.words ?? '',
            style: _textStyle(node, align, context),
          );
        default:
          return const TextSpan(text: '');
      }
    }
  }
}
