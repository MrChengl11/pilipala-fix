import 'package:get/get.dart';
import 'package:pilipala/http/msg.dart';
import 'package:pilipala/models/msg/like.dart';

class MessageLikeController extends GetxController {
  Cursor? cursor;
  RxList<MessageLikeItem> likeItems = <MessageLikeItem>[].obs;

  Future queryMessageLike({String type = 'init'}) async {
    if (type == 'onLoad' && cursor != null && cursor!.isEnd == true) {
      return {};
    }
    if (type == 'init') {
      cursor = null;
      likeItems.clear();
    }
    var params = {
      if (type == 'onLoad' && cursor != null) 'id': cursor!.id,
      if (type == 'onLoad' && cursor != null) 'likeTime': cursor!.time,
    };
    var res = await MsgHttp.messageLike(
        id: params['id'], likeTime: params['likeTime']);
    if (res['status']) {
      // MessageLikeModel.total 在设计上可为 null（模型里是条件解析），
      // 接口只返回 latest 时 total.cursor 会抛空指针 → 「收到的赞」整页失败
      final Total? total = res['data'].total;
      cursor = total?.cursor;
      likeItems.addAll(total?.items ?? <MessageLikeItem>[]);
    }
    return res;
  }

  Future expandedUsersAvatar(i) async {
    likeItems[i].isExpand = !likeItems[i].isExpand;
    likeItems.refresh();
  }
}
