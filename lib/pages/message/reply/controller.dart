import 'package:get/get.dart';
import 'package:pilipala/http/msg.dart';
import 'package:pilipala/models/msg/reply.dart';

class MessageReplyController extends GetxController {
  Cursor? cursor;
  RxList<MessageReplyItem> replyItems = <MessageReplyItem>[].obs;

  Future queryMessageReply({String type = 'init'}) async {
    if (type == 'onLoad' && cursor != null && cursor!.isEnd == true) {
      return {};
    }
    if (type == 'init') {
      cursor = null;
      replyItems.clear();
    }
    var params = {
      if (type == 'onLoad' && cursor != null) 'id': cursor!.id,
      if (type == 'onLoad' && cursor != null) 'replyTime': cursor!.time,
    };
    var res = await MsgHttp.messageReply(
        id: params['id'], replyTime: params['replyTime']);
    if (res['status']) {
      cursor = res['data'].cursor;
      replyItems.addAll(res['data'].items);
    }
    return res;
  }
}
