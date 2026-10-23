import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/html_render.dart';
import 'package:pilipala/common/widgets/http_error.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/read/opus.dart';
import 'package:pilipala/models/read/read.dart';
import 'package:pilipala/pages/opus/text_helper.dart';
import 'package:pilipala/pages/opus/widgets/module_view.dart';
import 'package:pilipala/utils/utils.dart';
import 'controller.dart';

class ReadPage extends StatefulWidget {
  const ReadPage({super.key});

  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  final ReadPageController controller = Get.put(ReadPageController());
  late Future _futureBuilderFuture;

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = controller.fetchCvData();
  }

  List<String> extractDataSrc(String input) {
    final regex = RegExp(r'data-src="([^"]*)"');
    final matches = regex.allMatches(input);
    return matches.map((match) {
      final dataSrc = match.group(1)!;
      return dataSrc.startsWith('//') ? 'https:$dataSrc' : dataSrc;
    }).toList();
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
          // 接口异常 / 解析失败时 snapshot.data 为 null，
          // 原代码返回空 SizedBox 导致整页白屏无提示、无法重试
          if (snapshot.data == null) {
            return HttpError(
              errMsg: snapshot.error?.toString(),
              fn: () {
                setState(() {
                  _futureBuilderFuture = controller.fetchCvData();
                });
              },
            );
          }
          if (snapshot.data['status'] == true) {
            return _buildContent(snapshot.data['data']);
          } else {
            // http 层失败分支返回 'msg'（lib/http/read.dart:97/:99/:106），
            // 原来读 'message' 得到 null 传给非空 String → TypeError 红屏
            final String msg =
                (snapshot.data['msg'] ?? snapshot.data['message'] ?? '加载失败')
                    .toString();
            return _buildError(msg);
          }
        } else {
          return _buildLoading();
        }
      },
    );
  }

  Widget _buildContent(ReadDataModel cvData) {
    // B 站新版 cv 页面只返回 detail.modules（老 readInfo 已不存在），
    // 这时交给共用的图文渲染器；老页面继续走 readInfo 逻辑。
    final ReadInfo? readInfo = cvData.readInfo;
    final OpusDataModel opusData = controller.opusData.value;
    if (readInfo == null) {
      if (opusData.detail?.modules != null &&
          opusData.detail!.modules!.isNotEmpty) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.of(context).padding.bottom + 40),
          child: OpusModuleView(
            opusData: opusData,
            onPreviewImg: (pics, index) =>
                controller.onPreviewImg(pics, index, context),
          ),
        );
      }
      return _buildError('专栏内容缺失');
    }
    final List<String> picList = _extractPicList(cvData);
    final List<String> imgList = extractDataSrc(readInfo.content ?? '');
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).padding.bottom + 40),
      child: readInfo.opus == null
          ? _buildNonOpusContent(cvData, imgList)
          : _buildOpusContent(cvData, picList),
    );
  }

  List<String> _extractPicList(ReadDataModel cvData) {
    final List<String> picList = [];
    final List<ModuleParagraph> paragraphs =
        cvData.readInfo?.opus?.content?.paragraphs ?? <ModuleParagraph>[];
    for (var paragraph in paragraphs) {
      if (paragraph.paraType == 2) {
        for (var pic in paragraph.pic?.pics ?? <Pic>[]) {
          if (pic.url != null) picList.add(pic.url!);
        }
      }
    }
    return picList;
  }

  Widget _buildNonOpusContent(ReadDataModel cvData, List<String> imgList) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: _buildStatsWidget(cvData),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildAuthorWidget(cvData),
        ),
        SelectionArea(
          child: HtmlRender(
            htmlContent: cvData.readInfo?.content ?? '',
            imgList: imgList,
          ),
        ),
      ],
    );
  }

  Widget _buildOpusContent(ReadDataModel cvData, List<String> picList) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: _buildStatsWidget(cvData),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildAuthorWidget(cvData),
        ),
        ...(cvData.readInfo?.opus?.content?.paragraphs ?? <ModuleParagraph>[])
            .map(
          (ModuleParagraph paragraph) {
            return Column(
              children: [
                if (paragraph.paraType == 1)
                  _buildTextParagraph(paragraph)
                else if (paragraph.paraType == 2)
                  ..._buildPics(paragraph, picList)
                else
                  const SizedBox(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextParagraph(ModuleParagraph paragraph) {
    return Container(
      alignment: TextHelper.getAlignment(paragraph.align),
      margin: const EdgeInsets.only(bottom: 10),
      child: SelectableText.rich(
        TextSpan(
          children: paragraph.text?.nodes?.map((node) {
                return TextHelper.buildTextSpan(node, paragraph.align, context);
              }).toList() ??
              [],
        ),
      ),
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
                  _futureBuilderFuture = controller.fetchCvData();
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

  Widget _buildStatsWidget(ReadDataModel cvData) {
    return Row(
      children: [
        StyledText(Utils.CustomStamp_str(
          timestamp: cvData.readInfo?.publishTime ?? 0,
          date: 'YY-MM-DD hh:mm',
          toInt: false,
        )),
        const SizedBox(width: 10),
        StyledText('${Utils.numFormat(cvData.readInfo?.stats?['view'])}浏览'),
        const StyledText(' · '),
        StyledText('${cvData.readInfo?.stats?['like'] ?? 0}点赞'),
        // const StyledText(' · '),
        // StyledText('${cvData.readInfo!.stats!['reply']}评论'),
      ],
    );
  }

  Widget _buildAuthorWidget(ReadDataModel cvData) {
    // author 在部分老文章 / 接口降级时缺失，原来是裸 ! 断言
    final Author? author = cvData.readInfo?.author;
    if (author == null) return const SizedBox(height: 8);
    final int? nicknameColor = author.vip?.nicknameColor;
    return Row(
      children: [
        NetworkImgLayer(
          width: 48,
          height: 48,
          type: 'avatar',
          src: author.face,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  author.name ?? '',
                  style: TextStyle(
                    color:
                        nicknameColor != null ? Color(nicknameColor) : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Image.asset(
                  'assets/images/lv/lv${author.level}.png',
                  height: 11,
                ),
              ],
            ),
            Row(
              children: [
                StyledText('粉丝: ${Utils.numFormat(author.fans)}'),
                const SizedBox(width: 10),
                StyledText(
                    '文章: ${Utils.numFormat(cvData.readInfo?.totalArtNum ?? 0)}'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildPics(ModuleParagraph paragraph, List<String> picList) {
    return paragraph.pic?.pics
            ?.map(
              (Pic pic) => Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
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
                      height:
                          (Get.size.width - 32) * pic.scale! / pic.aspectRatio!,
                      type: 'emote',
                    ),
                  ),
                ),
              ),
            )
            .toList() ??
        [];
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
