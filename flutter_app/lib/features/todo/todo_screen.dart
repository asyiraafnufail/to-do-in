import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/repositories/repositories.dart';
import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/add_todo_sheet.dart';
import 'widgets/todo_item_card.dart';
import 'widgets/todo_progress_card.dart';

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
    _authSub = authRepo.onAuthChanged.listen((_) {
      if (!mounted) return;
      if (authRepo.isAuthenticated) {
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
    if (!authRepo.isAuthenticated) return;

    final userId = authRepo.currentUserId;
    if (userId == null) return;
    setState(() => _isLoading = true);

    // 1. Offline fallback cache
    if (_todos.isEmpty) {
      final cached = await todoRepo.loadCachedTodos(userId);
      if (cached.isNotEmpty && mounted) {
        setState(() => _todos = cached);
      }
    }

    // 2. Fetch fresh from PocketBase & update cache
    try {
      final list = await todoRepo.fetchAndCacheTodos(userId);
      if (mounted) {
        setState(() => _todos = list);
      }
    } catch (_) {
      // Offline fallback: keep existing or cached _todos
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onEditNote(
      String id, String currentNote, String taskTitle) async {
    final newNote = await showEditTodoNoteDialog(
      context,
      currentNote: currentNote,
      taskTitle: taskTitle,
    );
    if (newNote == null || !mounted) return;

    try {
      await todoRepo.updateNote(id, newNote);
      _loadTodos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan catatan: $e')),
        );
      }
    }
  }

  Future<void> _toggleTodo(String id, bool val) async {
    try {
      await todoRepo.setCompleted(id, val);
      _loadTodos();
    } catch (_) {}
  }

  Future<void> _deleteTodo(String id) async {
    try {
      await todoRepo.deleteTodo(id);
      _loadTodos();
    } catch (_) {}
  }

  void _openAddBottomSheet() {
    final existingCities = _todos
        .map((t) => t['city']?.toString().trim())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    showAddTodoBottomSheet(
      context,
      existingCities: existingCities,
      onSave: (city, task, notes) async {
        final userId = authRepo.currentUserId;
        if (userId == null) return;
        try {
          await todoRepo.addTodo(
            userId: userId,
            city: city,
            taskTitle: task,
            notes: notes,
            notify: false,
          );
          _loadTodos();
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAuthenticated = authRepo.isAuthenticated;

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
              onPressed: _openAddBottomSheet,
            ),
        ],
      ),
      body: !isAuthenticated
          ? _buildAuthPrompt()
          : _isLoading && _todos.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTodos,
                  child: _todos.isEmpty ? _buildEmptyState() : _buildTodoList(),
                ),
      floatingActionButton: isAuthenticated && _todos.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openAddBottomSheet,
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
                        onPressed: _openAddBottomSheet,
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

    final cities = _todos
        .map((t) => t['city']?.toString().trim() ?? 'Lainnya')
        .where((c) => c.isNotEmpty)
        .toSet();

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
            TodoProgressCard(
              total: totalCount,
              completed: completedCount,
              pending: pendingCount,
              citiesCount: cities.length,
              percent: progressPercent,
            ),
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
                    _buildStatusSegment(
                        'Perlu ($pendingCount)', 'pending', isDark),
                    _buildStatusSegment(
                        'Selesai ($completedCount)', 'completed', isDark),
                  ],
                ),
              ),
            ),
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
                              Icon(Icons.delete_outline,
                                  color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                        confirmDismiss: (_) async => true,
                        onDismissed: (_) => _deleteTodo(id),
                        child: TodoItemCard(
                          item: item,
                          isDark: isDark,
                          onToggle: _toggleTodo,
                          onEditNote: _onEditNote,
                          onDelete: _deleteTodo,
                        ),
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
                  : (isDark ? AppColors.textMuted : const Color(0xFF64748B)),
            ),
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
}
