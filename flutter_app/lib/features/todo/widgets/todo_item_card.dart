import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class TodoItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final void Function(String id, bool nextCompleted) onToggle;
  final void Function(String id, String currentNote, String taskTitle)
      onEditNote;
  final void Function(String id) onDelete;

  const TodoItemCard({
    super.key,
    required this.item,
    required this.isDark,
    required this.onToggle,
    required this.onEditNote,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final id = item['id'] as String;
    final isDone = item['is_completed'] == true;
    final taskTitle = item['task_title']?.toString() ?? 'Aktivitas';
    final city = item['city']?.toString() ?? 'Indonesia';
    final notes = item['notes']?.toString();
    final sourcePostId = item['source_post']?.toString();

    final expand = item['expand'] as Map<String, dynamic>?;
    final sourcePost = expand?['source_post'] as Map<String, dynamic>?;
    final sourceTitle = sourcePost?['title']?.toString() ??
        sourcePost?['place_name']?.toString();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDone
            ? (isDark
                ? const Color(0xFF1E293B).withOpacity(0.4)
                : const Color(0xFFF8FAFC))
            : (isDark
                ? const Color(0xFF1E293B).withOpacity(0.75)
                : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? (isDark
                  ? Colors.white.withOpacity(0.04)
                  : const Color(0xFFE2E8F0).withOpacity(0.6))
              : (isDark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFE2E8F0)),
        ),
        boxShadow: isDone
            ? null
            : [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.12)
                      : const Color(0xFF0F172A).withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => onToggle(id, !isDone),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 2, right: 12),
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? AppColors.primary
                              : (isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFCBD5E1)),
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check,
                              size: 15, color: Colors.white)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['task_title'] ?? '',
                          style: TextStyle(
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                            color: isDone
                                ? AppColors.textMuted
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF334155).withOpacity(0.5)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 11,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    city,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : const Color(0xFF475569),
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
                  IconButton(
                    icon: Icon(
                      notes != null && notes.trim().isNotEmpty
                          ? Icons.edit_note
                          : Icons.note_add_outlined,
                      color: notes != null && notes.trim().isNotEmpty
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    tooltip: 'Catatan Pribadi',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onEditNote(id, notes ?? '', taskTitle),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.textMuted, size: 19),
                    tooltip: 'Hapus',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => onDelete(id),
                  ),
                ],
              ),
              if (notes != null && notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onEditNote(id, notes, taskTitle),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withOpacity(0.4)
                          : const Color(0xFFFEF9C3).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : const Color(0xFFFDE047).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 13, color: Color(0xFFCA8A04)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            notes,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF854D0E),
                            ),
                          ),
                        ),
                        const Icon(Icons.edit,
                            size: 11, color: Color(0xFFCA8A04)),
                      ],
                    ),
                  ),
                ),
              ],
              if (sourcePostId != null && sourcePostId.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => context.push('/post/$sourcePostId'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.article_outlined,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            sourceTitle != null
                                ? 'Dari cerita: $sourceTitle'
                                : 'Lihat cerita asal',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward_ios,
                            size: 9, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
