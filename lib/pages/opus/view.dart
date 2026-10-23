import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/read/opus.dart';
import 'controller.dart';
import 'text_helper.dart';

class OpusPage extends StatefulWidget {
  const OpusPage({super.key});

  @override
  State<OpusPage> createState() => _OpusPageState();
}

class _OpusPageState extends State<OpusPage> {
  final OpusController controller = Get.put(OpusController());
  late Future _futureBuilderFuture;

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = controller.fetchOpusData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        controller: controller.scrollController,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle(),
            _buildFutureContent(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: StreamBuilder(
        stream: controller.appbarStream.stream.distinct(),
        initialData: false,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          return AnimatedOpacity(
            opacity: snapshot.data ? 1 : 0,
            curve: Curves.easeOut,
            duration: const Duration(milliseconds: 500),
            child: Obx(
              () => Text(
                controller.title.value,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          );
        },
      ),
      actions: [
        PopupMenuButton(
          icon: const Icon(Icons.more_vert_outlined),
          itemBuilder: (BuildContext context) => <PopupMenuEntry>[
            PopupMenuItem(
              onTap: controller.onJumpWebview,
              child: const Text('查看原网页'),
            )
          ],
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Obx(
        () => Text(
          controller.title.value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFutureContent() {
    return FutureBuilder(
      future: _futureBuilderFuture,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // data == null 说明接口抛异常，原来返回空 SizedBox 整页白屏
          if (snapshot.data == null) {
            return _buildError(
              snapshot.error?.toString() ?? '加载失败，请检查网络后重试',
            );
          }
          if (snapshot.data['status'] == true) {
            return _buildContent(controller.opusData.value);
          } else {
            // http 层失败分支返回的键是 'msg'，原来读 'message' 得到 null，
            // 传给非空 String 形参直接 TypeError（断网进图文必红屏）
            final String msg = (snapshot.data['msg'] ??
                    snapshot.data['message'] ??
                    '加载失败')
                .toString();
            return _buildError(msg);
          }
        } else {
          return _buildLoading();
        }
      },
    );
  }

  Widget _buildContent(OpusDataModel opusData) {
    if (opusData.detail == null) {
      return const SizedBox();
    }
    // modules 可能为 null（接口只返回部分模块），
    // 原来 detail!.modules! 会抛空指针让整篇图文白屏
    final List<OpusModuleDataModel>? modules = opusData.detail!.modules;
    if (modules == null) {
      return _buildError('图文内容缺失');
    }
    // 原来用 late ModuleContent，找不到 moduleContent 时下面
    // moduleContent.paragraphs 会抛 LateInitializationError 直接崩
    ModuleContent? moduleContent;
    // 获取所有的图片链接
    final List<String> picList = [];
    final int moduleIndex =
        modules.indexWhere((module) => module.moduleContent != null);
    if (moduleIndex != -1) {
      moduleContent = modules[moduleIndex].moduleContent;
    }
    if (moduleContent == null) {
      return _buildError('图文内容缺失');
    }
    for (var paragraph in moduleContent.paragraphs ?? <ModuleParagraph>[]) {
      if (paragraph.paraType == 2) {
        for (var pic in paragraph.pic?.pics ?? <Pic>[]) {
          if (pic.url != null) picList.add(pic.url!);
        }
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).padding.bottom + 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: _buildStatsWidget(opusData),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildAuthorWidget(opusData),
          ),
          ...(moduleContent.paragraphs ?? <ModuleParagraph>[]).map(
            (ModuleParagraph paragraph) {
              return Column(
                children: [
                  if (paragraph.paraType == 1) ...[
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
                  ] else if (paragraph.paraType == 2) ...[
                    ...paragraph.pic?.pics?.map(
                          (Pic pic) => Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(top: 10, bottom: 10),
                              child: InkWell(
                                onTap: () {
                                  controller.onPreviewImg(
                                    picList,
                                    picList.indexOf(pic.url!),
                                    context,
                                  );
                                },
                                child: NetworkImgLayer(
                                  src: pic.url,
                                  width: (Get.size.width - 32) * pic.scale!,
                                  height: (Get.size.width - 32) *
                                      pic.scale! /
                                      pic.aspectRatio!,
                                  type: 'emote',
                                ),
                              ),
                            ),
                          ),
                        ) ??
                        [],
                  ] else
                    const SizedBox(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorWidget(OpusDataModel opusData) {
    final List<OpusModuleDataModel> modules =
        opusData.detail?.modules ?? <OpusModuleDataModel>[];
    late ModuleAuthor moduleAuthor;
    final int moduleIndex =
        modules.indexWhere((module) => module.moduleAuthor != null);
    if (moduleIndex != -1) {
      moduleAuthor = modules[moduleIndex].moduleAuthor!;
    } else {
      return const SizedBox();
    }
    return Row(
      children: [
        NetworkImgLayer(
          width: 48,
          height: 48,
          type: 'avatar',
          src: moduleAuthor.face,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              moduleAuthor.name ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            StyledText(moduleAuthor.pubTime ?? ''),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsWidget(OpusDataModel opusData) {
    // modules 为空 / 末尾模块没有 moduleStat / 各计数为 null
    // 都会让原来那行强解直接抛，整篇图文页白屏崩掉
    final List<OpusModuleDataModel> modules =
        opusData.detail?.modules ?? <OpusModuleDataModel>[];
    final int statIndex =
        modules.lastIndexWhere((module) => module.moduleStat != null);
    if (statIndex == -1) return const SizedBox();
    final ModuleStat moduleStat = modules[statIndex].moduleStat!;
    return Row(
      children: [
        StyledText('${moduleStat.comment?.count ?? 0}评论'),
        const SizedBox(width: 10),
        StyledText('${moduleStat.like?.count ?? 0}赞'),
        const SizedBox(width: 10),
        StyledText('${moduleStat.favorite?.count ?? 0}转发'),
      ],
    );
  }

  Widget _buildError(String? message) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/images/error.svg', height: 160),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message ?? '请求异常',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _futureBuilderFuture = controller.fetchOpusData();
                });
              },
              child: const Text('点击重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 100,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class StyledText extends StatelessWidget {
  final String text;

  const StyledText(this.text, {Key? key}) : super(key: key);

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
