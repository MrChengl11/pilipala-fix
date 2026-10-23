import 'dart:math';

import 'storage.dart';

class RecommendFilter {
  // static late int filterUnfollowedRatio;
  // 默认值与 update() 中的 defaultValue 保持一致；若请求早于 RecommendFilter()
  // 构造调用，也不能抛 LateInitializationError
  static int minDurationForRcmd = 0;
  static int minLikeRatioForRecommend = 0;
  static bool exemptFilterForFollowed = true;
  static bool applyFilterToRelatedVideos = true;
  RecommendFilter() {
    update();
  }

  static void update() {
    var setting = GStrorage.setting;
    // filterUnfollowedRatio =
    //     setting.get(SettingBoxKey.filterUnfollowedRatio, defaultValue: 0);
    minDurationForRcmd =
        setting.get(SettingBoxKey.minDurationForRcmd, defaultValue: 0);
    minLikeRatioForRecommend =
        setting.get(SettingBoxKey.minLikeRatioForRecommend, defaultValue: 0);
    exemptFilterForFollowed =
        setting.get(SettingBoxKey.exemptFilterForFollowed, defaultValue: true);
    applyFilterToRelatedVideos = setting
        .get(SettingBoxKey.applyFilterToRelatedVideos, defaultValue: true);
  }

  static bool filter(dynamic videoItem, {bool relatedVideos = false}) {
    if (relatedVideos && !applyFilterToRelatedVideos) {
      return false;
    }
    //由于相关视频中没有已关注标签，只能视为非关注视频
    if (!relatedVideos &&
        videoItem.isFollowed == 1 &&
        exemptFilterForFollowed) {
      return false;
    }
    if (videoItem.duration > 0 && videoItem.duration < minDurationForRcmd) {
      return true;
    }
    if (videoItem.stat.view is int &&
        videoItem.stat.view > -1 &&
        videoItem.stat.like is int &&
        videoItem.stat.like > -1 &&
        videoItem.stat.like * 100 <
            minLikeRatioForRecommend * videoItem.stat.view) {
      return true;
    }
    return false;
  }
}
