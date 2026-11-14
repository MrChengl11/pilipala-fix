import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:ns_danmaku/transition/scroll_item_view.dart';

/// 滚动弹幕「左边缘残片」回归测试。
///
/// 现象：弹幕滚到最左侧后，会在视频左边缘残留半个字符 / 几像素宽的字，
/// 过几秒才消失。
///
/// 根因（两个叠加）：
/// 1) DanmakuView.calculateTextSize() 用一个独立的 TextPainter 测宽，而
///    ScrollItemView 里真正绘制的 Text 会继承外层 Material 设置的
///    DefaultTextStyle（Material 3 的 bodyMedium，letterSpacing 0.25 等），
///    实际绘制宽度 > 测量宽度。SlideTransition 的结束位移 = -1（正好按
///    子控件宽度平移），于是最后一截字形留在裁剪区内。
/// 2) 动画结束后 onItemComplete 只从 Map 里删 id，没有触发重建，
///    已完成的 ScrollItemView 仍挂在 element 树上继续绘制，直到下一条
///    弹幕触发重建 —— 这就是「过几秒才消失」。
///
/// 修复后应满足：
/// - 绘制宽度与测量宽度一致（DanmakuBorderText 内部重置 DefaultTextStyle）；
/// - 滚动盒宽度额外预留 strokeWidth + 2px，终点时文本完全离开裁剪区；
/// - 动画完成后条目立即从 widget 树上移除。
void main() {
  const text = '弹幕测试内容很长很长很长abcde';
  const fontSize = 15.0;
  const strokeWidth = 2.0;
  const itemPadding = strokeWidth + 2.0;

  TextStyle measuredStyle() => TextStyle(
        fontSize: fontSize,
        overflow: TextOverflow.visible,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black,
      );

  double measure(String value, TextStyle style,
      {TextScaler textScaler = TextScaler.noScaling, Locale? locale}) {
    final painter = TextPainter(
      locale: locale,
      maxLines: 1,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      text: TextSpan(text: value, style: style),
    )..layout();
    return painter.width;
  }

  Future<DanmakuController> pumpDanmaku(
    WidgetTester tester, {
    double duration = 2,
  }) async {
    DanmakuController? controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 200,
              child: DanmakuView(
                createdController: (c) => controller = c,
                option: DanmakuOption(
                  fontSize: fontSize,
                  strokeWidth: strokeWidth,
                  duration: duration,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller, isNotNull);
    return controller!;
  }

  testWidgets('绘制宽度不得超过滚动盒宽度，且盒子为描边预留空间', (tester) async {
    final controller = await pumpDanmaku(tester);

    controller.addItems([DanmakuItem(text, color: Colors.white)]);
    await tester.pump();

    final itemFinder = find.byType(ScrollItemView);
    expect(itemFinder, findsOneWidget);
    final item = tester.widget<ScrollItemView>(itemFinder);

    final textContext = tester.element(
      find.descendant(of: itemFinder, matching: find.byType(Text)).first,
    );
    final ambient = DefaultTextStyle.of(textContext).style;
    final renderedStyle = ambient.merge(measuredStyle());
    final textScaler = MediaQuery.textScalerOf(textContext);
    final locale = Localizations.maybeLocaleOf(textContext);

    final measuredWidth = measure(text, measuredStyle(),
        textScaler: textScaler, locale: locale);
    final renderedWidth =
        measure(text, renderedStyle, textScaler: textScaler, locale: locale);

    // 滚动盒宽度 = 测量宽度 + 描边安全边距。
    expect(
      item.size.width,
      closeTo(measuredWidth + itemPadding, 0.51),
      reason: '滚动盒宽度应为测量宽度 + ${itemPadding}px 安全边距',
    );

    // 关键回归点：实际绘制的字形必须能装进滚动盒。
    // 修复前 ambient 会带 letterSpacing 0.25，长文本绘制宽度多出
    // 0.25×字符数（这里 17 字符 = 4.25px），终点就会留下残片。
    expect(
      renderedWidth,
      lessThanOrEqualTo(item.size.width - strokeWidth + 0.5),
      reason: '渲染宽度($renderedWidth) 超出滚动盒可用宽度'
          '(${item.size.width - strokeWidth})；'
          'ambient.letterSpacing=${ambient.letterSpacing}, '
          'ambient.fontFamily=${ambient.fontFamily}',
    );
  });

  testWidgets('滚动终点完全移出裁剪区', (tester) async {
    final controller = await pumpDanmaku(tester);

    controller.addItems([DanmakuItem(text, color: Colors.white)]);
    await tester.pump();

    final item = tester.widget<ScrollItemView>(find.byType(ScrollItemView));
    final boxWidth = item.size.width;

    // begin/end 是「子控件宽度」的倍数：起点整数倍平移后应贴在视图右侧，
    // 终点平移量必须覆盖整个滚动盒（-1 倍宽度 = 右缘恰好到视图左边界）。
    expect(item.begin * boxWidth, greaterThanOrEqualTo(360.0 - 0.01),
        reason: '弹幕应从视图右边界之外开始');
    expect(item.end * boxWidth, lessThanOrEqualTo(-boxWidth + 0.01),
        reason: '动画终点必须让整个滚动盒移出裁剪区');
  });

  testWidgets('动画结束后条目立即从 widget 树移除', (tester) async {
    final controller = await pumpDanmaku(tester, duration: 2);

    controller.addItems([DanmakuItem(text, color: Colors.white)]);
    await tester.pump();
    expect(find.byType(ScrollItemView), findsOneWidget);

    // duration = 2s，3s 后动画必然已完成。
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.byType(ScrollItemView), findsNothing,
        reason: '已完成的滚动弹幕仍挂在 widget 树上，会持续绘制残留像素');
  });
}
