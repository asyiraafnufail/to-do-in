import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/services/pb_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';

class PostCard extends StatefulWidget {
  final RecordModel post;
  final VoidCallback? onTodoSaved;

  const PostCard({
    super.key,
    required this.post,
    this.onTodoSaved,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final Set<String> _savedTodoItems = {};
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
    savedRefreshNotifier.addListener(_checkStatus);
    _checkStatus();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _savedTodoItems.clear();
      _isLiked = false;
      _likeCount = 0;
      _likeActionId = null;
      _isBookmarked = false;
      _bookmarkActionId = null;
      _checkStatus();
    }
  }

  @override
  void dispose() {
    savedRefreshNotifier.removeListener(_checkStatus);
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final userId = pb.authStore.record?.id;
    try {
      final likes = await pb.collection('social_actions').getList(
            filter:
                'target_post = "${widget.post.id}" && action_type = "like"',
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
                  'target_post = "${widget.post.id}" && user = "$userId" && action_type = "bookmark"',
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
          'target_post': widget.post.id,
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
          'target_post': widget.post.id,
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

  void _sharePost() {
    final slug = widget.post.getStringValue('slug');
    final id = widget.post.id;
    final path = slug.isNotEmpty ? slug : id;
    final url = 'https://todoin.id/p/$path';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tautan disalin: $url'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveTodo(String taskTitle) async {
    final userId = pb.authStore.record?.id;
    if (userId == null) {
      final loggedIn = await context.push<bool>('/login');
      if (loggedIn != true || !mounted) return;
    }

    final city = widget.post.getStringValue('city', 'Indonesia');
    try {
      await pb.collection('user_todos').create(body: {
        'user': pb.authStore.record?.id,
        'source_post': widget.post.id,
        'city': city,
        'task_title': taskTitle,
        'is_completed': false,
      });

      if (mounted) {
        setState(() => _savedTodoItems.add(taskTitle));
        todoRefreshNotifier.value++;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$taskTitle" ditambahkan ke My To-Do!'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Lihat',
              textColor: AppColors.accent,
              onPressed: () => context.go('/todo'),
            ),
          ),
        );
        widget.onTodoSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan to-do: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final post = widget.post;
    final author = post.get<RecordModel?>('expand.author');
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withOpacity(0.75)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/post/${post.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Author, Verified Badge, Date & Category Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                              radius: 20,
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.12),
                              backgroundImage:
                                  authorAvatar.isNotEmpty && author != null
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
                                        fontSize: 15,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          authorName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
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
                                      fontSize: 11.5,
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                // Location row & Live GPS trust pill
                if (placeName.isNotEmpty || city.isNotEmpty || isLiveGps) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          placeName.isNotEmpty ? '$placeName, $city' : city,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
                ],
                const SizedBox(height: 10),

                // Title
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
              const SizedBox(height: 6),

              // Snippet Content
              Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
              ),

              // Post Images Gallery Preview (if present)
              if (images.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: pb.files.getURL(post, images.first).toString(),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.textMuted.withOpacity(0.1),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.textMuted.withOpacity(0.1),
                        child: const Icon(Icons.broken_image,
                            color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
              ],

              // Blok "Rekomendasi To-Do Penulis"
              if (todoItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withOpacity(0.5)
                        : const Color(0xFFF8FAFC).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155).withOpacity(0.6)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.playlist_add_check,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'To-Do Rekomendasi Penulis (${todoItems.length})',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...todoItems.take(3).map((item) {
                        final taskText = item.toString();
                        final isSaved = _savedTodoItems.contains(taskText);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  size: 6, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  taskText,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: isSaved ? null : () => _saveTodo(taskText),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    gradient: isSaved
                                        ? null
                                        : LinearGradient(
                                            colors: [
                                              AppColors.accent.withOpacity(
                                                  isDark ? 0.22 : 0.12),
                                              const Color(0xFFF97316)
                                                  .withOpacity(
                                                      isDark ? 0.15 : 0.05),
                                            ],
                                          ),
                                    color: isSaved
                                        ? (isDark
                                            ? const Color(0xFF052E16)
                                            : AppColors.liveGpsBg)
                                        : null,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSaved
                                          ? AppColors.liveGpsFg.withOpacity(0.4)
                                          : AppColors.accent.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSaved ? Icons.check : Icons.add_rounded,
                                        size: 13,
                                        color: isSaved
                                            ? AppColors.liveGpsFg
                                            : AppColors.accent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isSaved ? 'Tersimpan' : 'To-Do',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSaved
                                              ? AppColors.liveGpsFg
                                              : AppColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (todoItems.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+ ${todoItems.length - 3} aktivitas lainnya (buka untuk lihat semua)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Card Action Bar (Like, Comment, Bookmark, Location)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: _toggleLike,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                                color: _isLiked
                                    ? Colors.red
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_likeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isLiked
                                      ? Colors.red
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => context.push('/post/${post.id}'),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 17,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Diskusi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _toggleBookmark,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Icon(
                            _isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 18,
                            color: _isBookmarked
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: _sharePost,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Icon(
                            Icons.share_outlined,
                            size: 17,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            province,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
