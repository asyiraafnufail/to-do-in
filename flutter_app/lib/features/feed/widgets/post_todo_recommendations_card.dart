import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PostTodoRecommendationsCard extends StatelessWidget {
  final List<dynamic> todoItems;
  final Set<String> savedTodoItems;
  final bool isDark;
  final void Function(String taskTitle) onSaveTodo;
  final void Function(List<dynamic> items) onSaveAll;

  const PostTodoRecommendationsCard({
    super.key,
    required this.todoItems,
    required this.savedTodoItems,
    required this.isDark,
    required this.onSaveTodo,
    required this.onSaveAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.copy_all, size: 16),
                  label:
                      const Text('Salin Semua', style: TextStyle(fontSize: 12)),
                  onPressed: () => onSaveAll(todoItems),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Aktivitas praktis dari cerita ini. Tekan tombol untuk menyimpan ke checklist My To-Do Anda.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            ...todoItems.map((item) {
              final taskText = item.toString();
              final isSaved = savedTodoItems.contains(taskText);

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    const Icon(Icons.circle, size: 8, color: AppColors.accent),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        backgroundColor: isSaved ? AppColors.liveGpsBg : null,
                        foregroundColor: isSaved ? AppColors.liveGpsFg : null,
                      ),
                      icon: Icon(
                        isSaved ? Icons.check : Icons.add_task,
                        size: 14,
                      ),
                      label: Text(
                        isSaved ? 'Tersimpan' : 'To-Do',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      onPressed: isSaved ? null : () => onSaveTodo(taskText),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
