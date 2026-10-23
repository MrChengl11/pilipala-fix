import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/http/read.dart';
import 'package:pilipala/models/read/opus.dart';
import 'package:pilipala/models/read/read.dart';
import 'package:pilipala/plugin/pl_gallery/hero_dialog_route.dart';
import 'package:pilipala/plugin/pl_gallery/interactiveviewer_gallery.dart';

class ReadPageController extends GetxController {
  late String url;
  RxString title = ''.obs;
  late String id;
  late String articleType;
  Rx<ReadDataModel> cvData = ReadDataModel().obs;
  // B 站新版 cv 页面只返回 detail.modules，老 readInfo 为空，
  // 需要同时持有 opus 结构，页面据此选择渲染方式
  Rx<OpusDataModel> opusData = OpusDataModel().obs;
  final ScrollController scrollController = ScrollController();
  late StreamController<bool> appbarStream = StreamController<bool>.broadcast();

  @override
  void onInit() {
    super.onInit();
    title.value = Get.parameters['title'] ?? '';
    id = Get.parameters['id']!;
    articleType = Get.parameters['articleType'] ?? 'read';
    url = 'https://www.bilibili.com/read/cv$id';
    scrollController.addListener(_scrollListener);
    fetchViewInfo();
  }

  Future fetchCvData() async {
    var res = await ReadHttp.parseArticleCv(id: id);
    if (res['status'] == true) {
      try {
        cvData.value = res['data'] ?? ReadDataModel();
        final OpusDataModel? opus = res['opus'];
        if (opus != null) opusData.value = opus;
        title.value = cvData.value.readInfo?.title ??
            opus?.detail?.basic?.title ??
            title.value;
      } catch (e, s) {
        debugPrint('fetchCvData apply error: $e\n$s');
        return {'status': false, 'msg': '专栏内容解析失败'};
      }
    }
    return res;
  }

  void _scrollListener() {
    final double offset = scrollController.position.pixels;
    if (offset > 100) {
      appbarStream.add(true);
    } else {
      appbarStream.add(false);
    }
  }

  void onPreviewImg(picList, initIndex, context) {
    Navigator.of(context).push(
      HeroDialogRoute<void>(
        builder: (BuildContext context) => InteractiveviewerGallery(
          sources: picList,
          initIndex: initIndex,
          onPageChanged: (int pageIndex) {},
        ),
      ),
    );
  }

  void fetchViewInfo() {
    ReadHttp.getViewInfo(id: id);
  }

  // 跳转webview
  void onJumpWebview() {
    Get.toNamed('/webview', parameters: {
      'url': url,
      'type': 'webview',
      'pageTitle': title.value,
    });
  }

  @override
  void onClose() {
    scrollController.removeListener(_scrollListener);
    appbarStream.close();
    super.onClose();
  }
}
