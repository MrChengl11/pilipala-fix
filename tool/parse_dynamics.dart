import 'dart:convert';
import 'dart:io';
import 'package:pilipala/models/dynamics/result.dart';

void main() {
  final raw = File(r'D:/tmp/dyn.json').readAsStringSync();
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final dataMap = map['data'] as Map<String, dynamic>;
  final items = (dataMap['items'] as List);
  print('items=' + items.length.toString());
  int ok = 0, bad = 0;
  for (int i = 0; i < items.length; i++) {
    try {
      final m = DynamicItemModel.fromJson(items[i] as Map<String, dynamic>);
      ok++;
      print('  [$i] OK type=' + (m.type ?? '?') + ' modules=' + (m.type ?? ''));
    } catch (e, st) {
      bad++;
      print('  [$i] FAIL: ' + e.toString());
      print('      ' + st.toString().split('\n').take(6).join('\n      '));
    }
  }
  print('ok=' + ok.toString() + ' bad=' + bad.toString());
  try {
    final d = DynamicsDataModel.fromJson(dataMap);
    print('whole OK items=' + (d.items?.length.toString() ?? 'null'));
  } catch (e, st) {
    print('whole FAIL: ' + e.toString());
    print(st.toString().split('\n').take(8).join('\n'));
  }
}
