import 'package:flutter/material.dart';
import 'package:pilipala/utils/utils.dart';

class StatView extends StatelessWidget {
  final String? theme;
  final dynamic view;
  final String? size;

  /// 为 true 时内部 Text 允许省略号收缩（窄卡片如 3 列以上使用）
  final bool overflow;

  const StatView({
    Key? key,
    this.theme = 'gray',
    this.view,
    this.size,
    this.overflow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Map<String, Color> colorObject = {
      'white': Colors.white,
      'gray': Theme.of(context).colorScheme.outline,
      'black': Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
    };
    Color color = colorObject[theme]!;
    return StatIconText(
      icon: Icons.play_circle_outlined,
      text: Utils.numFormat(view ?? 0),
      color: color,
      size: size,
      overflow: overflow,
    );
  }
}

class StatIconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final String? size;

  /// 为 true 时文本可被压缩并显示省略号
  final bool overflow;

  const StatIconText({
    Key? key,
    required this.icon,
    required this.text,
    required this.color,
    this.size,
    this.overflow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget textWidget = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: overflow ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontSize: size == 'medium' ? 12 : 11,
        color: color,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 2),
        overflow ? Flexible(child: textWidget) : textWidget,
      ],
    );
  }
}
