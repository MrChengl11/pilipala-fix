import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/user/sub_folder.dart';
import 'package:pilipala/pages/subscription/widgets/item.dart';

/// 「我的订阅」列表项。
///
/// 历史 bug：视频区组件 SubItem 把文字区包在
/// Row > Expanded > ConstrainedBox 里，而文字区 VideoContent 自己又
/// return Expanded(...)。ParentDataWidget 隔着 ConstrainedBox 找不到
/// 父级 Flex，release 包里抛 ParentData/FlexParentData 类型错误，
/// 整块文字区被替换成浅灰 ErrorWidget（约束高 100000），整页变成
/// 半屏灰块且无法滚动。这组用例保证不会再退化成那样。

SubFolderItemData _item() => SubFolderItemData(
      id: 100,
      title: '这是一个用来验证订阅卡片布局的长标题，可能会占两行',
      cover: '',
      mediaCount: 12,
      type: 11,
      upper: Upper(mid: 1, name: '测试UP主', face: ''),
    );

Future<void> _pump(WidgetTester tester, {double textScale = 1.0}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: ListView(
            children: [
              SubItem(
                subFolderItem: _item(),
                isOwner: true,
                cancelSub: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('360dp 窄屏：文字区正常渲染，不被 ErrorWidget 撑成整屏灰块', (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    // 卡片高度应该由内容决定（封面 90dp / 文字 ~95dp），
    // 出现 100000 高的 ErrorWidget 时会直接爆到几百上千。
    expect(tester.getSize(find.byType(SubItem)).height, lessThan(200));
    expect(find.textContaining('合集 UP主'), findsOneWidget);
    expect(find.text('12个视频'), findsOneWidget);
    expect(find.byIcon(Icons.clear_outlined), findsOneWidget);
  });

  testWidgets('字体放大 1.3 倍：内容自然撑高、不溢出', (tester) async {
    await _pump(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SubItem)).height, lessThan(240));
  });
}
