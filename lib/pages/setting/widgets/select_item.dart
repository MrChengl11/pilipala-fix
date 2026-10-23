import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/models/video/play/quality.dart';
import 'package:pilipala/utils/storage.dart';

class SetSelectItem extends StatefulWidget {
  final String? title;
  final String? subTitle;
  final String? setKey;
  const SetSelectItem({
    this.title,
    this.subTitle,
    this.setKey,
    Key? key,
  }) : super(key: key);

  @override
  State<SetSelectItem> createState() => _SetSelectItemState();
}

class _SetSelectItemState extends State<SetSelectItem> {
  Box setting = GStrorage.setting;

  /// 取枚举项的展示文案，供 onSelected 回填 currentVal。
  String _descriptionOf(dynamic item) {
    if (item is VideoQuality) return item.description;
    if (item is AudioQuality) return item.description;
    if (item is VideoDecodeFormats) return item.description;
    return item?.toString() ?? '';
  }

  late dynamic currentVal;
  late int currentIndex;
  late List menus;
  late List<PopupMenuEntry> popMenuItems;

  @override
  void initState() {
    super.initState();
    late String defaultVal;
    switch (widget.setKey) {
      case SettingBoxKey.defaultVideoQa:
        defaultVal = VideoQuality.values.last.description;
        List<VideoQuality> list = menus = VideoQuality.values.reversed.toList();
        currentVal = setting.get(widget.setKey, defaultValue: defaultVal);
        // 老版本存下来的描述可能在枚举里已不存在，缺少 orElse 会抛
        // StateError: No element，导致整个设置页 initState 崩溃。
        currentIndex = list
            .firstWhere(
              (i) => i.description == currentVal,
              orElse: () => VideoQuality.values.last,
            )
            .index;

        popMenuItems = [
          for (var i in list) ...[
            PopupMenuItem(
              value: i.index,
              child: Text(i.description),
            )
          ]
        ];

        break;
      case SettingBoxKey.defaultAudioQa:
        defaultVal = AudioQuality.values.last.description;
        List<AudioQuality> list = menus = AudioQuality.values.reversed.toList();
        currentVal = setting.get(widget.setKey, defaultValue: defaultVal);
        currentIndex = list
            .firstWhere(
              (i) => i.description == currentVal,
              orElse: () => AudioQuality.values.last,
            )
            .index;

        popMenuItems = [
          for (var i in list) ...[
            PopupMenuItem(
              value: i.index,
              child: Text(i.description),
            ),
          ]
        ];
        break;
      case SettingBoxKey.defaultDecode:
        defaultVal = VideoDecodeFormats.values[0].description;
        currentVal = setting.get(widget.setKey, defaultValue: defaultVal);
        List<VideoDecodeFormats> list = menus = VideoDecodeFormats.values;

        currentIndex = list
            .firstWhere(
              (i) => i.description == currentVal,
              orElse: () => VideoDecodeFormats.values[0],
            )
            .index;

        popMenuItems = [
          for (var i in list) ...[
            PopupMenuItem(
              value: i.index,
              child: Text(i.description),
            ),
          ]
        ];
        break;
      case 'defaultVideoSpeed':
        defaultVal = '1.0';
        currentVal = setting.get(widget.setKey, defaultValue: defaultVal);

        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    TextStyle subTitleStyle = Theme.of(context)
        .textTheme
        .labelMedium!
        .copyWith(color: Theme.of(context).colorScheme.outline);
    return ListTile(
      onTap: () {},
      dense: false,
      title: Text(widget.title!),
      subtitle: Text(
        '当前${widget.title!} $currentVal',
        style: subTitleStyle,
      ),
      trailing: PopupMenuButton(
        initialValue: currentIndex,
        icon: const Icon(
          Icons.arrow_forward_rounded,
          size: 22,
        ),
        onSelected: (item) {
          // 原实现 menus.firstWhere((e) => e.code == item).first 有三个问题：
          // 1) VideoQuality/AudioQuality/VideoDecodeFormats 都没有 code 字段
          // 2) firstWhere 无 orElse，找不到就抛 StateError
          // 3) 取的是枚举的 .first（该枚举的首个常量），而不是选中的那一项
          // 这里按 PopupMenuItem 的 value（即 index）回查实际选中的项。
          final selected = menus.firstWhere(
            (e) =>
                (e is VideoQuality
                    ? e.index
                    : e is AudioQuality
                        ? e.index
                        : e is VideoDecodeFormats
                            ? e.index
                            : e) ==
                item,
            orElse: () => menus[0],
          );
          currentVal = _descriptionOf(selected);
          setState(() {});
        },
        itemBuilder: (BuildContext context) =>
            <PopupMenuEntry>[...popMenuItems],
      ),
    );
  }
}
