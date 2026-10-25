import 'package:flutter/material.dart';

enum DanmakuItemType {
  scroll,
  top,
  bottom,
}

class DanmakuItem {
  final String text;
  final Color color;
  final int time;
  final DanmakuItemType type;
  final bool isSend;
  DanmakuItem(
    this.text, {
    this.color = Colors.white,
    this.time = 0,
    this.type = DanmakuItemType.scroll,
    this.isSend = false
  });
}
