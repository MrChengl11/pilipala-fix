import 'package:flutter/material.dart';

import 'utils/border_color.dart';

class DanmakuBorderText extends StatelessWidget {
  final String text;
  final TextAlign textAlign;
  final Color color;
  final double fontSize;
  final double strokeWidth;
  final bool isSend;
  const DanmakuBorderText(
    this.text, {
    this.textAlign = TextAlign.left,
    this.color = Colors.white,
    this.fontSize = 16,
    this.strokeWidth = 2.0,
    this.isSend = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 显式重置继承来的 DefaultTextStyle，让实际绘制使用的字体度量与
    // DanmakuView.calculateTextSize() 的 TextPainter 测量完全一致。
    //
    // 修复：MaterialApp 里的 Material 会把 DefaultTextStyle 设为
    // textTheme.bodyMedium（M3 默认带 letterSpacing 0.25、height 1.43 等）。
    // Text 会把它 merge 进自己的 style，于是实际绘制宽度比测量宽度多出
    // letterSpacing × 字符数：长弹幕能多出半个汉字宽，短弹幕多出几像素。
    // 而滚动弹幕的 SlideTransition 结束位移恰好是 -1 倍「测量宽度」——
    // 多出来的那截字形就留在视频左边缘，直到下一条弹幕触发重建才消失。
    return DefaultTextStyle(
      style: const TextStyle(),
      softWrap: false,
      overflow: TextOverflow.visible,
      child: Stack(
        children: <Widget>[
          Text(
            text,
            softWrap: false,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: fontSize,
              overflow: TextOverflow.visible,
              backgroundColor: isSend ? getBorderColor(color) : null,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round
                ..color = getBorderColor(color),
            ),
          ),
          Text(
            text,
            softWrap: false,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  //double get strokeWidth => (fontSize / 20).ceil() * 2;
}
