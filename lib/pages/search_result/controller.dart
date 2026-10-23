import 'package:get/get.dart';
import 'package:pilipala/http/search.dart';
import 'package:pilipala/models/common/search_type.dart';

class SearchResultController extends GetxController {
  String? keyword;
  int tabIndex = 0;
  RxList searchTabs = [].obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.parameters.keys.isNotEmpty) {
      keyword = Get.parameters['keyword'];
    }
    searchTabs.value = SearchType.values
        .map((type) => {'label': type.label, 'id': type.type})
        .toList();
    querySearchCount();
  }

  Future querySearchCount() async {
    final String? kw = keyword;
    if (kw == null || kw.isEmpty) {
      return {'status': false, 'msg': '关键词为空'};
    }
    var result = await SearchHttp.searchCount(keyword: kw);
    if (result['status']) {
      final topTList = result['data']?.topTList;
      for (var i in searchTabs) {
        final dynamic raw = topTList?[i['id']];
        if (raw is int && raw > 99) {
          i['count'] = '99+';
        } else {
          i['count'] = raw is int ? raw.toString() : '0';
        }
      }
      searchTabs.refresh();
    }
    return result;
  }
}
