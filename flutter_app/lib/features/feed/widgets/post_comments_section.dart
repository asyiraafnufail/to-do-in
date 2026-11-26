import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/services/pb_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';

class PostCommentsSection extends StatelessWidget {
  final List<RecordModel> comments;
  final bool isLoading;
  final bool isDark;

  const PostCommentsSection({
    super.key,
    required this.comments,
    required this.isLoading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diskusi (${comments.length})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Belum ada komentar. Jadilah yang pertama berkomentar!',
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          ...comments.map((c) {
            final user = c.get<RecordModel?>('expand.user');
            final rawName = user?.getStringValue('name') ?? '';
            final rawUser = user?.getStringValue('username') ?? '';
            final uName = rawName.isNotEmpty
                ? rawName
                : (rawUser.isNotEmpty ? '@$rawUser' : 'Traveler');
            final uAvatar = user?.getStringValue('avatar') ?? '';
            final commentText = c.getStringValue('comment_body');
            final cDate = c.getStringValue('created');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    backgroundImage: uAvatar.isNotEmpty && user != null
                        ? CachedNetworkImageProvider(pbFileUrl(user, uAvatar))
                        : null,
                    child: uAvatar.isEmpty
                        ? Text(
                            uName.isNotEmpty ? uName[0].toUpperCase() : 'T',
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            style: const TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class PostCommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isDark;
  final VoidCallback onSend;

  const PostCommentInputBar({
    super.key,
    required this.controller,
    required this.isSending,
    required this.isDark,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tulis tanggapan atau tanya rute...',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: isSending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 18),
            onPressed: isSending ? null : onSend,
          ),
        ],
      ),
    );
  }
}
