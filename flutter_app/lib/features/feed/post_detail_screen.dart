import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../marketplace/widgets/listing_card.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _isLoading = true;
  String? _error;
  RecordModel? _post;
  List<RecordModel> _authorListings = [];

  final Set<String> _savedTodoItems = {};
  List<RecordModel> _comments = [];
  bool _isLoadingComments = false;
  final _commentCtrl = TextEditingController();
  bool _isSendingComment = false;

  bool _isLiked = false;
  int _likeCount = 0;
  String? _likeActionId;
  bool _isTogglingLike = false;

  bool _isBookmarked = false;
  String? _bookmarkActionId;
  bool _isTogglingBookmark = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadComments();
    _checkStatus();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final post = await pb.collection('posts').getOne(
            widget.postId,
            expand: 'author',
          );
      List<RecordModel> authorListings = [];
      final authorId = post.getStringValue('author');
      if (authorId.isNotEmpty) {
        try {
          final lRes = await pb.collection('listings').getList(
                filter: 'owner = "$authorId" && is_available = true',
                sort: '-created',
                perPage: 3,
                expand: 'owner',
              );
          authorListings = lRes.items;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _post = post;
          _authorListings = authorListings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat cerita: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkStatus() async {
    final userId = pb.authStore.record?.id;
    try {
      final likes = await pb.collection('social_actions').getList(
            filter:
                'target_post = "${widget.postId}" && action_type = "like"',
            perPage: 100,
          );
      if (!mounted) return;
      setState(() {
        _likeCount = likes.totalItems;
        if (userId != null) {
          final myLike =
              likes.items.where((a) => a.getStringValue('user') == userId);
          if (myLike.isNotEmpty) {
            _isLiked = true;
            _likeActionId = myLike.first.id;
          }
        }
      });

      if (userId != null) {
        final bms = await pb.collection('social_actions').getList(
              filter:
                  'target_post = "${widget.postId}" && user = "$userId" && action_type = "bookmark"',
              perPage: 1,
            );
        if (mounted && bms.items.isNotEmpty) {
          setState(() {
            _isBookmarked = true;
            _bookmarkActionId = bms.items.first.id;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final userId = pb.authStore.record?.id;
    if (userId == null) {
      context.push('/login');
      return;
    }
    if (_isTogglingLike) return;

    setState(() => _isTogglingLike = true);
    try {
      if (_isLiked && _likeActionId != null) {
        await pb.collection('social_actions').delete(_likeActionId!);
        if (mounted) {
          setState(() {
            _isLiked = false;
            _likeCount = (_likeCount - 1).clamp(0, 999999);
            _likeActionId = null;
          });
        }
      } else {
        final action = await pb.collection('social_actions').create(body: {
          'user': userId,
          'target_post': widget.postId,
          'action_type': 'like',
        });
        if (mounted) {
          setState(() {
            _isLiked = true;
            _likeCount++;
            _likeActionId = action.id;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
    }
  }

  Future<void> _toggleBookmark() async {
    final userId = pb.authStore.record?.id;
    if (userId == null) {
      context.push('/login');
      return;
    }
    if (_isTogglingBookmark) return;

    setState(() => _isTogglingBookmark = true);
    try {
      if (_isBookmarked && _bookmarkActionId != null) {
        await pb.collection('social_actions').delete(_bookmarkActionId!);
        if (mounted) {
          setState(() {
            _isBookmarked = false;
            _bookmarkActionId = null;
          });
          savedRefreshNotifier.value++;
        }
      } else {
        final action = await pb.collection('social_actions').create(body: {
          'user': userId,
          'target_post': widget.postId,
          'action_type': 'bookmark',
        });
        if (mounted) {
          setState(() {
            _isBookmarked = true;
            _bookmarkActionId = action.id;
          });
          savedRefreshNotifier.value++;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isTogglingBookmark = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final res = await pb.collection('social_actions').getList(
            filter:
                'target_post = "${widget.postId}" && action_type = "comment"',
            sort: 'created',
            expand: 'user',
            perPage: 50,
          );
      if (mounted) {
        setState(() {
          _comments = res.items;
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final userId = pb.authStore.record?.id;
    if (userId == null) {
      final loggedIn = await context.push<bool>('/login');
      if (loggedIn != true || !mounted) return;
    }

    setState(() => _isSendingComment = true);
    try {
      await pb.collection('social_actions').create(body: {
        'user': pb.authStore.record?.id,
        'target_post': widget.postId,
        'action_type': 'comment',
        'comment_body': text,
      });

      _commentCtrl.clear();
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim komentar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _saveTodo(String taskTitle) async {
    final userId = pb.authStore.record?.id;
    if (userId == null) {
      final loggedIn = await context.push<bool>('/login');
      if (loggedIn != true || !mounted) return;
    }

    final city = _post?.getStringValue('city', 'Indonesia') ?? 'Indonesia';
    try {
      await pb.collection('user_todos').create(body: {
        'user': pb.authStore.record?.id,
        'source_post': widget.postId,
        'city': city,
        'task_title': taskTitle,
        'is_completed': false,
      });

      if (mounted) {
        setState(() => _savedTodoItems.add(taskTitle));
        todoRefreshNotifier.value++;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$taskTitle" ditambahkan ke My To-Do!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  Future<void> _saveAllTodos(List<dynamic> items) async {
    final userId = pb.authStore.record?.id;
    if (userId == null) {
      final loggedIn = await context.push<bool>('/login');
      if (loggedIn != true || !mounted) return;
    }

    final city = _post?.getStringValue('city', 'Indonesia') ?? 'Indonesia';
    int savedCount = 0;
    for (final item in items) {
      final taskTitle = item.toString();
      if (_savedTodoItems.contains(taskTitle)) continue;
      try {
        await pb.collection('user_todos').create(body: {
          'user': pb.authStore.record?.id,
          'source_post': widget.postId,
          'city': city,
          'task_title': taskTitle,
          'is_completed': false,
        });
        _savedTodoItems.add(taskTitle);
        savedCount++;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {});
      if (savedCount > 0) todoRefreshNotifier.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount aktivitas berhasil disimpan ke My To-Do!'),
          action: SnackBarAction(
            label: 'Lihat',
            textColor: AppColors.accent,
            onPressed: () => context.go('/todo'),
          ),
        ),
      );
    }
  }

  void _sharePost() {
    final slug = _post?.getStringValue('slug');
    final id = _post?.id ?? widget.postId;
    final path = (slug != null && slug.isNotEmpty) ? slug : id;
    final url = 'https://todoin.id/p/$path';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tautan disalin: $url'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDeletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Cerita?'),
        content: const Text(
            'Cerita ini beserta gambar dan diskusi terkait akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await pb.collection('posts').delete(widget.postId);
        feedRefreshNotifier.value++;
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cerita berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus cerita: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(_error ?? 'Cerita tidak ditemukan'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadPost,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final post = _post!;
    final author = post.get<RecordModel?>('expand.author');
    final authorId = post.getStringValue('author');
    final currentUserId = pb.authStore.record?.id;
    final isOwnPost = currentUserId != null && currentUserId == authorId;

    final name = author?.getStringValue('name') ?? '';
    final username = author?.getStringValue('username') ?? '';
    final authorName = name.isNotEmpty
        ? name
        : (username.isNotEmpty ? '@$username' : 'Traveler');
    final authorAvatar = author?.getStringValue('avatar') ?? '';
    final isVerifiedHost = author?.getBoolValue('is_verified_host') ?? false;

    final title = post.getStringValue('title');
    final content = post.getStringValue('content');
    final category = post.getStringValue('category');
    final placeName = post.getStringValue('place_name');
    final city = post.getStringValue('city');
    final province = post.getStringValue('province');
    final isLiveGps = post.getBoolValue('is_live_gps');
    final created = post.getStringValue('created');
    final isEdited = post.getBoolValue('is_edited');
    final images = post.getListValue<String>('images');
    final todoItems = post.getListValue<dynamic>('todo_items');

    return Scaffold(
      appBar: AppBar(
        title: Text(placeName.isNotEmpty ? placeName : city),
        actions: [
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : null,
            ),
            tooltip: 'Suka',
            onPressed: _toggleLike,
          ),
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? AppColors.accent : null,
            ),
            tooltip: 'Simpan',
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Bagikan',
            onPressed: _sharePost,
          ),
          if (isOwnPost)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Cerita',
              onPressed: () async {
                final updated =
                    await context.push<bool>('/create', extra: post);
                if (updated == true) _loadPost();
              },
            ),
          if (isOwnPost)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Hapus Cerita',
              onPressed: _confirmDeletePost,
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header: Author Info
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: author != null
                                  ? () => context.push('/user/${author.id}')
                                  : null,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.12),
                                    backgroundImage: authorAvatar.isNotEmpty &&
                                            author != null
                                        ? CachedNetworkImageProvider(
                                            pb.files
                                                .getURL(author, authorAvatar)
                                                .toString(),
                                          )
                                        : null,
                                    child: authorAvatar.isEmpty
                                        ? Text(
                                            authorName.isNotEmpty
                                                ? authorName[0].toUpperCase()
                                                : 'T',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                authorName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isVerifiedHost) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.verified,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${DateFormatter.timeAgo(created)}${isEdited ? ' • (Diedit)' : ''}',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(isDark ? 0.22 : 0.12),
                                  const Color(0xFF0D9488)
                                      .withOpacity(isDark ? 0.14 : 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Spot & City Subtitle + Live GPS badge
                      if (placeName.isNotEmpty || city.isNotEmpty || isLiveGps)
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                placeName.isNotEmpty
                                    ? '$placeName, $city • $province'
                                    : '$city • $province',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLiveGps) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF10B981)
                                          .withOpacity(isDark ? 0.25 : 0.16),
                                      const Color(0xFF059669)
                                          .withOpacity(isDark ? 0.18 : 0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 12, color: AppColors.liveGpsFg),
                                    SizedBox(width: 3.5),
                                    Text(
                                      'Live GPS',
                                      style: TextStyle(
                                        color: AppColors.liveGpsFg,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 16),

                      // Images Gallery
                      if (images.isNotEmpty) ...[
                        SizedBox(
                          height: 220,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, idx) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: CachedNetworkImage(
                                    imageUrl: pb.files
                                        .getURL(post, images[idx])
                                        .toString(),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Full Story Content
                      Text(
                        content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.65,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Blok Rekomendasi To-Do Penulis Lengkap
                      if (todoItems.isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.playlist_add_check,
                                            color: AppColors.accent,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Rekomendasi To-Do Penulis',
                                              style:
                                                  theme.textTheme.titleMedium,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      icon: const Icon(Icons.copy_all,
                                          size: 16),
                                      label: const Text('Salin Semua',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () =>
                                          _saveAllTodos(todoItems),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Aktivitas praktis dari cerita ini. Tekan tombol untuk menyimpan ke checklist My To-Do Anda.',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 12),
                                ...todoItems.map((item) {
                                  final taskText = item.toString();
                                  final isSaved =
                                      _savedTodoItems.contains(taskText);

                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.circle,
                                            size: 8, color: AppColors.accent),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            taskText,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.tonalIcon(
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size(0, 32),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10),
                                            backgroundColor: isSaved
                                                ? AppColors.liveGpsBg
                                                : null,
                                            foregroundColor: isSaved
                                                ? AppColors.liveGpsFg
                                                : null,
                                          ),
                                          icon: Icon(
                                            isSaved
                                                ? Icons.check
                                                : Icons.add_task,
                                            size: 14,
                                          ),
                                          label: Text(
                                            isSaved ? 'Tersimpan' : 'To-Do',
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          onPressed: isSaved
                                              ? null
                                              : () => _saveTodo(taskText),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      // Layanan Penulis (User Flow 2.2 Conversion Loop)
                      if (_authorListings.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.storefront,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Layanan oleh Penulis',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sewa kendaraan, open trip, atau penginapan terverifikasi yang dikelola langsung oleh penulis cerita ini.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 10),
                        ..._authorListings.map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListingCard(
                              key: ValueKey(l.id),
                              listing: l,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Diskusi / Komentar
                      Text(
                        'Diskusi (${_comments.length})',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingComments)
                        const Center(child: CircularProgressIndicator())
                      else if (_comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Belum ada komentar. Jadilah yang pertama berkomentar!',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      else
                        ..._comments.map((c) {
                          final user = c.get<RecordModel?>('expand.user');
                          final rawName = user?.getStringValue('name') ?? '';
                          final rawUser =
                              user?.getStringValue('username') ?? '';
                          final uName = rawName.isNotEmpty
                              ? rawName
                              : (rawUser.isNotEmpty ? '@$rawUser' : 'Traveler');
                          final uAvatar =
                              user?.getStringValue('avatar') ?? '';
                          final commentText =
                              c.getStringValue('comment_body');
                          final cDate = c.getStringValue('created');

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.12),
                                  backgroundImage: uAvatar.isNotEmpty &&
                                          user != null
                                      ? CachedNetworkImageProvider(
                                          pb.files
                                              .getURL(user, uAvatar)
                                              .toString(),
                                        )
                                      : null,
                                  child: uAvatar.isEmpty
                                      ? Text(
                                          uName.isNotEmpty
                                              ? uName[0].toUpperCase()
                                              : 'T',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                uName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12.5,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormatter.timeAgo(cDate),
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          commentText,
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.35),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Comment Input Box at bottom
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Tulis tanggapan atau tanya rute...',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: _isSendingComment
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send, size: 18),
                        onPressed: _isSendingComment ? null : _sendComment,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
