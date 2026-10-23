import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/read/opus.dart';
import 'package:pilipala/pages/opus/text_helper.dart';

/// 图文 / 专栏内容区共用渲染器。
///
/// 背景：B 站已把 /read/cvXXX 页面也切换成 detail.modules 结构，
/// 老的 readInfo 字段在新页面里完全不存在，导致所有 cv 专栏页
/// 都显示「专栏内容缺失」。这里把 opus 页的内容渲染抽出来复用。
class OpusModuleView extends StatelessWidget {
  const OpusModuleView({
    super.key,
    required this.opusData,
    required this.onPreviewImg,
  });

  final OpusDataModel opusData;

  /// 点击图片预览：参数是全部图片 + 当前下标
  final void Function(List<String> pics, int index) onPreviewImg;

  @override
  Widget build(BuildContext context) {
    final List<OpusModuleDataModel> modules =
        opusData.detail?.modules ?? <OpusModuleDataModel>[];

    ModuleContent? moduleContent;
    final int contentIndex =
        modules.indexWhere((module) => module.moduleContent != null);
    if (contentIndex != -1) {
      moduleContent = modules[contentIndex].moduleContent;
    }
    if (moduleContent == null) return const SizedBox.shrink();

    final List<String> picList = <String>[];
    for (final ModuleParagraph paragraph
        in moduleContent.paragraphs ?? <ModuleParagraph>[]) {
      if (paragraph.paraType == 2) {
        for (final Pic pic in paragraph.pic?.pics ?? <Pic>[]) {
          if (pic.url != null) picList.add(pic.url!);
        }
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: _StatsRow(modules: modules),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _AuthorRow(modules: modules),
        ),
        ...(moduleContent.paragraphs ?? <ModuleParagraph>[]).map(
          (ModuleParagraph paragraph) {
            return Column(
              children: [
                if (paragraph.paraType == 1)
                  Container(
                    alignment: TextHelper.getAlignment(paragraph.align),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: SelectableText.rich(
                      TextSpan(
                        children: paragraph.text?.nodes?.map((node) {
                              return TextHelper.buildTextSpan(
                                  node, paragraph.align, context);
                            }).toList() ??
                            [],
                      ),
                    ),
                  )
                else if (paragraph.paraType == 2)
                  ...(paragraph.pic?.pics ?? <Pic>[]).map(
                    (Pic pic) {
                      if (pic.url == null) return const SizedBox.shrink();
                      // 图片尺寸缺失时用到 view 里会崩，这里兜底成正方形
                      final double scale = pic.scale ?? 1.0;
                      final double ratio = pic.aspectRatio ?? 1.0;
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          child: InkWell(
                            onTap: () {
                              onPreviewImg(picList, picList.indexOf(pic.url!));
                            },
                            child: NetworkImgLayer(
                              src: pic.url,
                              width: (Get.size.width - 32) * scale,
                              height: (Get.size.width - 32) * scale / ratio,
                              type: 'emote',
                            ),
                          ),
                        ),
                      );
                    },
                  )
                else
                  const SizedBox.shrink(),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.modules});

  final List<OpusModuleDataModel> modules;

  @override
  Widget build(BuildContext context) {
    final int statIndex =
        modules.lastIndexWhere((module) => module.moduleStat != null);
    if (statIndex == -1) return const SizedBox.shrink();
    final ModuleStat moduleStat = modules[statIndex].moduleStat!;
    return Row(
      children: [
        _MetaText('${moduleStat.comment?.count ?? 0}评论'),
        const SizedBox(width: 10),
        _MetaText('${moduleStat.like?.count ?? 0}赞'),
        const SizedBox(width: 10),
        _MetaText('${moduleStat.favorite?.count ?? 0}转发'),
      ],
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.modules});

  final List<OpusModuleDataModel> modules;

  @override
  Widget build(BuildContext context) {
    final int index =
        modules.indexWhere((module) => module.moduleAuthor != null);
    if (index == -1) return const SizedBox.shrink();
    final ModuleAuthor author = modules[index].moduleAuthor!;
    return Row(
      children: [
        NetworkImgLayer(
          width: 48,
          height: 48,
          type: 'avatar',
          src: author.face,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              _MetaText(author.pubTime ?? ''),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
