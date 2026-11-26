import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_client.dart';

class PostRepository {
  const PostRepository();

  Future<ResultList<RecordModel>> getPosts({
    int page = 1,
    int perPage = 15,
    String? category,
    String? province,
    String? query,
    List<String>? authorIds,
    bool searchContent = true,
  }) {
    final parts = <String>[];
    if (authorIds != null && authorIds.isNotEmpty) {
      final authorOr = authorIds
          .map((id) => pb.filter('author = {:id}', {'id': id}))
          .join(' || ');
      parts.add('($authorOr)');
    }
    if (category != null && category.isNotEmpty) {
      parts.add(pb.filter('category = {:cat}', {'cat': category}));
    }
    if (province != null && province.isNotEmpty) {
      parts.add(pb.filter('province = {:prov}', {'prov': province}));
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      parts.add(pb.filter(
        searchContent
            ? '(title ~ {:q} || content ~ {:q} || place_name ~ {:q} || city ~ {:q})'
            : '(title ~ {:q} || place_name ~ {:q} || city ~ {:q})',
        {'q': q},
      ));
    }

    return pb.collection('posts').getList(
          page: page,
          perPage: perPage,
          sort: '-created',
          expand: 'author',
          filter: parts.join(' && '),
        );
  }

  Future<List<RecordModel>> getPostsByAuthor(
    String authorId, {
    int perPage = 50,
  }) async {
    final res = await pb.collection('posts').getList(
          filter: pb.filter('author = {:id}', {'id': authorId}),
          sort: '-created',
          expand: 'author',
          perPage: perPage,
        );
    return res.items;
  }

  Future<List<RecordModel>> getPostsByIds(
    List<String> postIds, {
    int perPage = 50,
  }) async {
    if (postIds.isEmpty) return [];
    final filter =
        postIds.map((id) => pb.filter('id = {:id}', {'id': id})).join(' || ');
    final res = await pb.collection('posts').getList(
          filter: filter,
          expand: 'author',
          perPage: perPage,
        );
    final postMap = {for (final p in res.items) p.id: p};
    return postIds.where(postMap.containsKey).map((id) => postMap[id]!).toList();
  }

  Future<RecordModel> getPost(String postId) {
    return pb.collection('posts').getOne(postId, expand: 'author');
  }

  Future<RecordModel> createPost({
    required Map<String, dynamic> body,
    List<http.MultipartFile> files = const [],
  }) async {
    final created = await pb.collection('posts').create(
          body: body,
          files: files,
        );
    feedRefreshNotifier.value++;
    return created;
  }

  Future<RecordModel> updatePost(
    String postId, {
    required Map<String, dynamic> body,
    List<http.MultipartFile> files = const [],
  }) async {
    final updated = await pb.collection('posts').update(
          postId,
          body: body,
          files: files,
        );
    feedRefreshNotifier.value++;
    return updated;
  }

  Future<void> deletePost(String postId) async {
    await pb.collection('posts').delete(postId);
    feedRefreshNotifier.value++;
  }
}

const postRepo = PostRepository();
