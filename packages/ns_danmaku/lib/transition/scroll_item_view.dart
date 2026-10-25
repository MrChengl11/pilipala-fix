import 'package:flutter/material.dart';
import 'package:ns_danmaku/danmaku_border_text.dart';

import '../utils/border_color.dart';

class ScrollItemView extends StatefulWidget {
  /// 弹幕唯一ID（由 DanmakuView 单调递增分配，保证唯一）
  final String id;
  final String text;
  final Color color;
  final double fontSize;
  final double duration;
  final double y;
  final double begin;
  final double end;
  final bool border;
  final Size size;
  final double strokeWidth;
  final Function(String)? onComplete;
  final Function(AnimationController)? onCreated;
  final bool isSend;
  const ScrollItemView({
    required this.id,
    required this.text,
    this.fontSize = 16,
    this.duration = 10,
    this.color = Colors.white,
    this.y = 0,
    this.begin = 0,
    this.end = -1,
    this.size = Size.zero,
    this.border = true,
    this.strokeWidth = 2.0,
    this.onComplete,
    this.onCreated,
    this.isSend = false,
    required UniqueKey key,
  }) : super(key: key);

  @override
  State<ScrollItemView> createState() => _ScrollItemViewState();
}

class _ScrollItemViewState extends State<ScrollItemView>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  bool get isComplete => controller.isCompleted;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    // 修复：原实现为 Duration(seconds: widget.duration.floor())
    //  1) .floor() 把小数时长截断（如 6.67s -> 6s），弹幕速度与实际时长不符；
    //  2) 当 duration < 1.0 时 Duration.zero 会让 controller.forward() 立即完成，
    //     触发 onComplete 把弹幕从列表中移除 —— 表现为弹幕刚出现/滑到一半就消失。
    controller = AnimationController(
      duration: _computeDuration(widget.duration),
      vsync: this,
    );

    controller.addStatusListener(statusUpdate);

    _animation = Tween(
            begin: Offset(widget.begin, widget.y),
            end: Offset(widget.end, widget.y))
        .animate(controller);

    widget.onCreated?.call(controller);
    controller.forward();
  }

  /// 把秒数换算成精确的动画时长。
  ///
  /// 原实现是 Duration(seconds: widget.duration.floor())，有两个缺陷：
  /// 1) .floor() 截断小数（6.67s -> 6s），高倍速下弹幕明显变快；
  /// 2) duration < 1.0 时会得到 Duration.zero，controller.forward() 立即完成并
  ///    回调 onComplete 把弹幕移除 —— 弹幕刚出现就"消失"，即本 bug 的直接原因。
  Duration _computeDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) {
      return const Duration(milliseconds: 200);
    }
    var us = (seconds * Duration.microsecondsPerSecond).round();
    if (us < 200000) {
      us = 200000; // 最少 200ms，避免零时长动画瞬间完成
    } else if (us > 600 * Duration.microsecondsPerSecond) {
      us = 600 * Duration.microsecondsPerSecond;
    }
    return Duration(microseconds: us);
  }

  void statusUpdate(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete?.call(widget.id);
    }
  }

  @override
  void dispose() {
    controller.removeStatusListener(statusUpdate);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: SizedBox(
        height: widget.size.height,
        width: widget.size.width,
        child: widget.border
            ? DanmakuBorderText(
                widget.text,
                color: widget.color,
                fontSize: widget.fontSize,
                strokeWidth: widget.strokeWidth,
                isSend: widget.isSend,
              )
            : Text(
                widget.text,
                style: TextStyle(
                  color: widget.color,
                  fontSize: widget.fontSize,
                  letterSpacing: 2,
                  overflow: TextOverflow.visible,
                  backgroundColor: widget.isSend ? getBorderColor(widget.color) : null
                ),
              ),
      ),
    );
  }
}
