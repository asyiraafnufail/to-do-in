import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  StreamSubscription<AuthStoreEvent>? _authSub;
  bool _isLoading = false;
  List<Map<String, dynamic>> _todos = [];
  String? _selectedCity;
  String _statusFilter = 'all'; // 'all', 'pending', 'completed'

  @override
  void initState() {
    super.initState();
    _authSub = pb.authStore.onChange.listen((_) {
      if (!mounted) return;
      if (pb.authStore.isValid) {
        _loadTodos();
      } else {
        setState(() {
          _todos = [];
          _selectedCity = null;
        });
      }
    });
    todoRefreshNotifier.addListener(_loadTodos);
    _loadTodos();
  }

  @override
  void dispose() {
    todoRefreshNotifier.removeListener(_loadTodos);
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    if (!pb.authStore.isValid) return;

    final userId = pb.authStore.record?.id;
    setState(() => _isLoading = true);

    // 1. Offline fallback cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_todos_$userId');
      if (cachedStr != null && cachedStr.isNotEmpty && _todos.isEmpty) {
        final decoded = jsonDecode(cachedStr) as List<dynamic>;
        if (mounted) {
          setState(() {
            _todos = decoded.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {}

    // 2. Fetch fresh from PocketBase
    try {
      final records = await pb.collection('user_todos').getFullList(
            sort: '-created',
            expand: 'source_post',
          );
      final list = records.map((r) => r.toJson()).toList();
      if (mounted) {
        setState(() {
          _todos = list;
        });
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_todos_$userId', jsonEncode(list));
      } catch (_) {}
    } catch (_) {
      // Offline fallback: keep existing or cached _todos
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditNoteDialog(
      String id, String currentNote, String taskTitle) async {
    final noteCtrl = TextEditingController(text: currentNote);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catatan Pribadi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(taskTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText:
                    'Misal: Bawa uang tunai, datang sebelum jam 07.00...',
                labelText: 'Catatan Anda',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final newNote = noteCtrl.text.trim();
      try {
        await pb.collection('user_todos').update(id, body: {'notes': newNote});
        _loadTodos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan catatan: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAuthenticated = pb.authStore.isValid;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'My To-Do',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isAuthenticated)
            IconButton(
              icon: const Icon(Icons.add_task, color: AppColors.primary),
              tooltip: 'Tambah Aktivitas Manual',
              onPressed: _showAddBottomSheet,
            ),
        ],
      ),
      body: !isAuthenticated
          ? _buildAuthPrompt()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTodos,
                  child: _todos.isEmpty
                      ? _buildEmptyState()
                      : _buildTodoList(),
                ),
      floatingActionButton: isAuthenticated && _todos.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddBottomSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Tambah Aktivitas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            )
          : null,
    );
  }

  Widget _buildAuthPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/char_splash.png',
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.lock_outline,
                size: 56,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rencana Perjalanan Pribadi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Masuk atau daftar untuk menyimpan rekomendasi aktivitas dari cerita traveler lain.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Masuk ke Akun'),
              onPressed: () async {
                await context.push('/login');
                if (mounted) _loadTodos();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/char_splash.png',
                    height: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.checklist_rtl_outlined,
                      size: 56,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Belum ada aktivitas disimpan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Jelajahi feed dan tekan tombol "+ To-Do" pada postingan untuk merencanakan liburan impian Anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.explore_outlined, size: 18),
                        label: const Text('Jelajahi Feed'),
                        onPressed: () => context.go('/feed'),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah Manual'),
                        onPressed: _showAddBottomSheet,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodoList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalCount = _todos.length;
    final completedCount =
        _todos.where((t) => t['is_completed'] == true).length;
    final pendingCount = totalCount - completedCount;
    final progressPercent =
        totalCount > 0 ? (completedCount / totalCount) : 0.0;

    // Filter cities
    final cities =
        _todos.map((t) => t['city']?.toString().trim() ?? 'Lainnya').where((c) => c.isNotEmpty).toSet();

    // Filter list by city and status
    final filtered = _todos.where((t) {
      final matchCity = _selectedCity == null || t['city'] == _selectedCity;
      if (!matchCity) return false;

      final isDone = t['is_completed'] == true;
      if (_statusFilter == 'pending') return !isDone;
      if (_statusFilter == 'completed') return isDone;
      return true;
    }).toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            // 1. Hero Travel Progress Card
            _buildProgressCard(
              total: totalCount,
              completed: completedCount,
              pending: pendingCount,
              citiesCount: cities.length,
              percent: progressPercent,
            ),

            // 2. Status Segment Filter (Semua, Perlu Dikunjungi, Selesai)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withOpacity(0.65)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155).withOpacity(0.6)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildStatusSegment('Semua ($totalCount)', 'all', isDark),
                    _buildStatusSegment('Perlu ($pendingCount)', 'pending', isDark),
                    _buildStatusSegment('Selesai ($completedCount)', 'completed', isDark),
                  ],
                ),
              ),
            ),

            // 3. Filter Kota Chips
            if (cities.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildCityChip('Semua Wilayah', null, isDark: isDark),
                      ...cities
                          .map((c) => _buildCityChip(c, c, isDark: isDark)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // 4. Todo List Items
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        _statusFilter == 'completed'
                            ? Icons.check_circle_outline
                            : Icons.assignment_outlined,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusFilter == 'completed'
                            ? 'Belum ada aktivitas yang selesai.'
                            : 'Tidak ada aktivitas pada filter ini.',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: filtered.map((item) {
                    final id = item['id'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey(id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Hapus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.delete_outline, color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                        confirmDismiss: (_) async => true,
                        onDismissed: (_) => _deleteTodo(id),
                        child: _buildTodoCard(item, isDark, theme),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard({
    required int total,
    required int completed,
    required int pending,
    required int citiesCount,
    required double percent,
  }) {
    final isDoneAll = total > 0 && completed == total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDoneAll
              ? [const Color(0xFF0F766E), const Color(0xFF16A34A)]
              : [const Color(0xFF0F766E), const Color(0xFF115E59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDoneAll ? Icons.celebration : Icons.luggage_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isDoneAll ? 'Semua Target Selesai!' : 'Rencana Perjalanan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(percent * 100).toInt()}% Selesai',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress indicator bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _buildBannerStat('$total', 'Total To-Do'),
              Container(
                width: 1,
                height: 26,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildBannerStat('$pending', 'Tersisa'),
              Container(
                width: 1,
                height: 26,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildBannerStat('$citiesCount', 'Kota Tujuan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(String count, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSegment(String title, String value, bool isDark) {
    final isSelected = _statusFilter == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _statusFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.textMuted
                      : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodoCard(
      Map<String, dynamic> item, bool isDark, ThemeData theme) {
    final id = item['id'] as String;
    final isDone = item['is_completed'] == true;
    final taskTitle = item['task_title']?.toString() ?? 'Aktivitas';
    final city = item['city']?.toString() ?? 'Indonesia';
    final notes = item['notes']?.toString();
    final sourcePostId = item['source_post']?.toString();

    // Expand source_post title if available
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
                  // Checkbox Circle
                  GestureDetector(
                    onTap: () => _toggleTodo(id, !isDone),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 2, right: 12),
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.primary
                            : Colors.transparent,
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

                  // Title & Location
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
                    onPressed: () =>
                        _showEditNoteDialog(id, notes ?? '', taskTitle),
                  ),
                  const SizedBox(width: 8),

                  // Action Delete Button
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.textMuted, size: 19),
                    tooltip: 'Hapus',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteTodo(id),
                  ),
                ],
              ),

              // Notes section (if any)
              if (notes != null && notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showEditNoteDialog(id, notes, taskTitle),
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

              // Source post link (if saved from feed post)
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

  Widget _buildCityChip(String label, String? value, {required bool isDark}) {
    final isSelected = _selectedCity == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _selectedCity = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    )
                  : null,
              color: isSelected
                  ? null
                  : (isDark
                      ? const Color(0xFF1E293B).withOpacity(0.65)
                      : Colors.white.withOpacity(0.85)),
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? null
                  : Border.all(
                      color: isDark
                          ? const Color(0xFF334155).withOpacity(0.7)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleTodo(String id, bool val) async {
    try {
      await pb.collection('user_todos').update(id, body: {'is_completed': val});
      _loadTodos();
    } catch (_) {}
  }

  Future<void> _deleteTodo(String id) async {
    try {
      await pb.collection('user_todos').delete(id);
      _loadTodos();
    } catch (_) {}
  }

  void _showAddBottomSheet() {
    final cityController = TextEditingController();
    final taskController = TextEditingController();
    final notesController = TextEditingController();

    // Suggest existing cities
    final existingCities = _todos
        .map((t) => t['city']?.toString().trim())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Tambah Rencana To-Do',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tambahkan aktivitas baru ke daftar perjalanan Anda.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 18),

                  // Kota / Kabupaten Field
                  TextField(
                    controller: cityController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Kota / Kabupaten',
                      hintText: 'Misal: Sleman, Yogyakarta, Bali',
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                      suffixIcon: existingCities.isNotEmpty
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.arrow_drop_down),
                              tooltip: 'Pilih Kota Yang Ada',
                              onSelected: (val) {
                                setModalState(() {
                                  cityController.text = val;
                                });
                              },
                              itemBuilder: (_) => existingCities
                                  .map((c) => PopupMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ))
                                  .toList(),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nama Aktivitas Field
                  TextField(
                    controller: taskController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Nama Aktivitas',
                      hintText: 'Misal: Sunrise di Candi Plaosan',
                      prefixIcon: Icon(Icons.checklist, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Catatan (Opsional)
                  TextField(
                    controller: notesController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      hintText: 'Misal: Datang jam 05.00 pagi, bawa jaket',
                      prefixIcon:
                          Icon(Icons.sticky_note_2_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check, size: 19),
                      label: const Text(
                        'Simpan ke My To-Do',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      onPressed: () async {
                        final task = taskController.text.trim();
                        final city = cityController.text.trim();
                        if (task.isEmpty || city.isEmpty) return;

                        try {
                          await pb.collection('user_todos').create(body: {
                            'user': pb.authStore.record?.id,
                            'city': city,
                            'task_title': task,
                            'notes': notesController.text.trim(),
                            'is_completed': false,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadTodos();
                        } catch (_) {}
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
