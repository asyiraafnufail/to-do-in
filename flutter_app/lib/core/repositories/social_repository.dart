import 'package:pocketbase/pocketbase.dart';

import '../services/pb_client.dart';

class PostSocialStatus {
  final int likeCount;
  final bool isLiked;
  final String? likeActionId;
  final bool isBookmarked;
  final String? bookmarkActionId;

  const PostSocialStatus({
    required this.likeCount,
    required this.isLiked,
    this.likeActionId,
    required this.isBookmarked,
    this.bookmarkActionId,
  });
}

class SocialRepository {
  const SocialRepository();

  Future<PostSocialStatus> getPostStatus(
    String postId, {
    String? userId,
  }) async {
    final likes = await pb.collection('social_actions').getList(
          filter: pb.filter(
            'target_post = {:pid} && action_type = "like"',
            {'pid': postId},
          ),
          perPage: 100,
        );

    bool isLiked = false;
    String? likeActionId;
    if (userId != null) {
      final myLike =
          likes.items.where((a) => a.getStringValue('user') == userId);
      if (myLike.isNotEmpty) {
        isLiked = true;
        likeActionId = myLike.first.id;
      }
    }

    bool isBookmarked = false;
    String? bookmarkActionId;
    if (userId != null) {
      final bms = await pb.collection('social_actions').getList(
            filter: pb.filter(
              'target_post = {:pid} && user = {:uid} && action_type = "bookmark"',
              {'pid': postId, 'uid': userId},
            ),
            perPage: 1,
          );
      if (bms.items.isNotEmpty) {
        isBookmarked = true;
        bookmarkActionId = bms.items.first.id;
      }
    }

    return PostSocialStatus(
      likeCount: likes.totalItems,
      isLiked: isLiked,
      likeActionId: likeActionId,
      isBookmarked: isBookmarked,
      bookmarkActionId: bookmarkActionId,
    );
  }

  /// Toggle like; mengembalikan ID action baru jika like dibuat, atau `null` jika dihapus.
  Future<String?> toggleLike({
    required String postId,
    required String userId,
    String? existingActionId,
  }) async {
    if (existingActionId != null) {
      await pb.collection('social_actions').delete(existingActionId);
      return null;
    }
    final action = await pb.collection('social_actions').create(body: {
      'user': userId,
      'target_post': postId,
      'action_type': 'like',
    });
    return action.id;
  }

  /// Toggle bookmark; mengembalikan ID action baru jika disimpan, atau `null` jika dihapus.
  Future<String?> toggleBookmark({
    required String postId,
    required String userId,
    String? existingActionId,
  }) async {
    if (existingActionId != null) {
      await pb.collection('social_actions').delete(existingActionId);
      savedRefreshNotifier.value++;
      return null;
    }
    final action = await pb.collection('social_actions').create(body: {
      'user': userId,
      'target_post': postId,
      'action_type': 'bookmark',
    });
    savedRefreshNotifier.value++;
    return action.id;
  }

  Future<List<RecordModel>> getComments(String postId, {int perPage = 50}) async {
    final res = await pb.collection('social_actions').getList(
          filter: pb.filter(
            'target_post = {:pid} && action_type = "comment"',
            {'pid': postId},
          ),
          sort: 'created',
          expand: 'user',
          perPage: perPage,
        );
    return res.items;
  }

  Future<RecordModel> addComment({
    required String postId,
    required String userId,
    required String body,
  }) {
    return pb.collection('social_actions').create(body: {
      'user': userId,
      'target_post': postId,
      'action_type': 'comment',
      'comment_body': body,
    });
  }

  Future<List<String>> getFollowedUserIds(String userId) async {
    final follows = await pb.collection('social_actions').getFullList(
          filter: pb.filter(
            'user = {:uid} && action_type = "follow"',
            {'uid': userId},
          ),
        );
    return follows
        .map((f) => f.getStringValue('target_user'))
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<String?> getFollowActionId({
    required String userId,
    required String targetUserId,
  }) async {
    final res = await pb.collection('social_actions').getList(
          filter: pb.filter(
            'user = {:uid} && target_user = {:tid} && action_type = "follow"',
            {'uid': userId, 'tid': targetUserId},
          ),
          perPage: 1,
        );
    return res.items.isNotEmpty ? res.items.first.id : null;
  }

  Future<int> getFollowerCount(String targetUserId) async {
    final res = await pb.collection('social_actions').getList(
          filter: pb.filter(
            'target_user = {:tid} && action_type = "follow"',
            {'tid': targetUserId},
          ),
          perPage: 1,
        );
    return res.totalItems;
  }

  Future<String?> toggleFollow({
    required String userId,
    required String targetUserId,
    String? existingActionId,
  }) async {
    if (existingActionId != null) {
      await pb.collection('social_actions').delete(existingActionId);
      feedRefreshNotifier.value++;
      return null;
    }
    final action = await pb.collection('social_actions').create(body: {
      'user': userId,
      'target_user': targetUserId,
      'action_type': 'follow',
    });
    feedRefreshNotifier.value++;
    return action.id;
  }

  Future<List<String>> getBookmarkedPostIds(
    String userId, {
    int perPage = 50,
  }) async {
    final res = await pb.collection('social_actions').getList(
          filter: pb.filter(
            'user = {:uid} && action_type = "bookmark"',
            {'uid': userId},
          ),
          sort: '-created',
          perPage: perPage,
        );
    return res.items
        .map((b) => b.getStringValue('target_post'))
        .where((id) => id.isNotEmpty)
        .toList();
  }
}

const socialRepo = SocialRepository();
