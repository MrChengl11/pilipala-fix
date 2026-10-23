import 'dart:convert';
import 'dart:io';
import 'package:pilipala/models/dynamics/result.dart';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : r'D:/tmp/dyn.json';
  final map = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final dataMap = map['data'] as Map<String, dynamic>;
  final items = dataMap['items'] as List;
  int shown = 0;
  final seen = <String>{};
  int ok = 0;
  for (int i = 0; i < items.length; i++) {
    try {
      DynamicItemModel.fromJson(items[i] as Map<String, dynamic>);
      ok++;
    } catch (e, st) {
      final lines = st.toString().split('\n');
      final key = e.toString() + '|' + (lines.isNotEmpty ? lines[0] : '');
      if (!seen.contains(key) && shown < 8) {
        seen.add(key);
        shown++;
        print('--- item ' + i.toString() + '  ' + e.toString());
        for (final l in lines.take(4)) { print(l); }
      }
    }
  }
  print('ok=' + ok.toString() + '/' + items.length.toString());
}
