import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/post_card.dart';

/// State paginasi per tab feed (Terbaru / Mengikuti).
class _FeedPage {
  List<RecordModel> items = [];
  int page = 0;
  bool hasMore = true;
  bool isLoading = false;
  bool isLoadingMore = false;

  /// Token untuk membuang respons lama ketika filter berubah cepat.
  int token = 0;
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  static const int _perPage = 15;

  late final TabController _tabController;
  StreamSubscription<AuthStoreEvent>? _authSub;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String? _selectedCategory;
  String? _selectedProvince;
  String _query = '';

  final _latest = _FeedPage();
  final _following = _FeedPage();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadFeed();
      }
    });
    _authSub = pb.authStore.onChange.listen((_) {
      if (mounted) _loadFeed();
    });
    feedRefreshNotifier.addListener(_loadFeed);
    _loadFeed();
  }

  @override
  void dispose() {
    feedRefreshNotifier.removeListener(_loadFeed);
    _authSub?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  _FeedPage get _current => _tabController.index == 0 ? _latest : _following;

  bool get _hasActiveFilter =>
      _selectedCategory != null || _selectedProvince != null || _query.isNotEmpty;

  /// Menyusun filter dasar (kategori, provinsi, kata kunci) secara aman.
  String _baseFilter() {
    final parts = <String>[];
    if (_selectedCategory != null) {
      parts.add(pb.filter('category = {:cat}', {'cat': _selectedCategory}));
    }
    if (_selectedProvince != null) {
      parts.add(pb.filter('province = {:prov}', {'prov': _selectedProvince}));
    }
    if (_query.isNotEmpty) {
      parts.add(pb.filter(
        '(title ~ {:q} || content ~ {:q} || place_name ~ {:q} || city ~ {:q})',
        {'q': _query},
      ));
    }
    return parts.join(' && ');
  }

  /// Filter penulis yang diikuti; null jika belum login / belum mengikuti siapa pun.
  Future<String?> _followingFilter() async {
    final userId = pb.authStore.record?.id;
    if (userId == null) return null;
    final follows = await pb.collection('social_actions').getFullList(
          filter: pb.filter(
              'user = {:uid} && action_type = "follow"', {'uid': userId}),
        );
    final ids = follows
        .map((f) => f.getStringValue('target_user'))
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return null;
    return '(${ids.map((id) => pb.filter('author = {:id}', {'id': id})).join(' || ')})';
  }

  String? _followCache;

  /// Muat ulang dari halaman pertama untuk tab aktif.
  Future<void> _loadFeed() async {
    final target = _current;
    final isFollowingTab = target == _following;
    final token = ++target.token;

    setState(() {
      target.isLoading = true;
      target.page = 0;
      target.hasMore = true;
    });

    try {
      if (isFollowingTab) {
        _followCache = await _followingFilter();
        if (_followCache == null) {
          if (mounted && token == target.token) {
            setState(() {
              target.items = [];
              target.hasMore = false;
              target.isLoading = false;
            });
          }
          return;
        }
      }
      final res = await _fetchPage(1, isFollowingTab);
      if (!mounted || token != target.token) return;
      setState(() {
        target.items = res.items;
        target.page = 1;
        target.hasMore = res.page < res.totalPages;
        target.isLoading = false;
      });
    } catch (_) {
      if (mounted && token == target.token) {
        setState(() => target.isLoading = false);
      }
    }
  }

  /// Muat halaman berikutnya (infinite scroll).
  Future<void> _loadMore() async {
    final target = _current;
    final isFollowingTab = target == _following;
    if (target.isLoading || target.isLoadingMore || !target.hasMore) return;
    if (isFollowingTab && _followCache == null) return;

    final token = target.token;
    setState(() => target.isLoadingMore = true);
    try {
      final res = await _fetchPage(target.page + 1, isFollowingTab);
      if (!mounted || token != target.token) return;
      setState(() {
        final existing = target.items.map((e) => e.id).toSet();
        target.items = [
          ...target.items,
          ...res.items.where((e) => !existing.contains(e.id)),
        ];
        target.page = res.page;
        target.hasMore = res.page < res.totalPages;
        target.isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => target.isLoadingMore = false);
    }
  }

  Future<ResultList<RecordModel>> _fetchPage(int page, bool isFollowingTab) {
    final base = _baseFilter();
    final filter = isFollowingTab
        ? [_followCache!, if (base.isNotEmpty) base].join(' && ')
        : base;
    return pb.collection('posts').getList(
          page: page,
          perPage: _perPage,
          sort: '-created',
          expand: 'author',
          filter: filter,
        );
  }

  void _onSearchChanged(String value) {
    setState(() {}); // perbarui tombol clear
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      final q = value.trim();
      if (q == _query) return;
      _query = q;
      _loadFeed();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    FocusScope.of(context).unfocus();
    if (_query.isEmpty) {
      setState(() {});
      return;
    }
    _query = '';
    _loadFeed();
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _query = '';
    _selectedCategory = null;
    _selectedProvince = null;
    _loadFeed();
  }

  Future<void> _pickProvince() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Filter Provinsi',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                children: [
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Semua Provinsi'),
                    trailing: _selectedProvince == null
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                  const Divider(height: 1),
                  ...AppConstants.provinces.map(
                    (p) => ListTile(
                      title: Text(p),
                      trailing: _selectedProvince == p
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final next = result.isEmpty ? null : result;
    if (next == _selectedProvince) return;
    _selectedProvince = next;
    _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo_landscape.png',
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            'todoin.id',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          dividerHeight: 0,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          labelColor: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Terbaru'),
            Tab(text: 'Mengikuti'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          // Filter kategori chip
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip('Semua', null, isDark: isDark),
                  ...AppConstants.postCategories
                      .map((cat) => _buildFilterChip(cat, cat, isDark: isDark)),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeedTab(_latest, 'Belum ada cerita perjalanan.'),
                _buildFollowingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    final fieldBg = isDark
        ? const Color(0xFF1E293B).withOpacity(0.65)
        : const Color(0xFFF1F5F9);
    final hasProvince = _selectedProvince != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _searchDebounce?.cancel();
                  final q = v.trim();
                  if (q != _query) {
                    _query = q;
                    _loadFeed();
                  }
                },
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: fieldBg,
                  hintText: 'Cari cerita, tempat, atau kota…',
                  hintStyle:
                      const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppColors.textMuted),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _clearSearch,
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(21),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(21),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(21),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tombol filter provinsi
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickProvince,
              borderRadius: BorderRadius.circular(21),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 42,
                constraints: const BoxConstraints(minWidth: 42, maxWidth: 150),
                padding: EdgeInsets.symmetric(horizontal: hasProvince ? 12 : 0),
                decoration: BoxDecoration(
                  color: hasProvince
                      ? AppColors.primary.withOpacity(0.12)
                      : fieldBg,
                  borderRadius: BorderRadius.circular(21),
                  border: hasProvince
                      ? Border.all(color: AppColors.primary.withOpacity(0.5))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.place_outlined,
                        size: 20,
                        color: hasProvince
                            ? AppColors.primary
                            : AppColors.textMuted),
                    if (hasProvince) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _selectedProvince!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, {required bool isDark}) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (_selectedCategory == value) return;
            _selectedCategory = value;
            _loadFeed();
          },
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
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedTab(_FeedPage data, String emptyMsg) {
    final posts = data.items;
    if (data.isLoading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      final filtered = _hasActiveFilter;
      return RefreshIndicator(
        onRefresh: _loadFeed,
        child: ListView(
          children: [
            SizedBox(
              height: 360,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          filtered
                              ? Icons.search_off_rounded
                              : Icons.explore_outlined,
                          size: 48,
                          color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        filtered
                            ? 'Tidak ada cerita yang cocok dengan pencarian/filter Anda.'
                            : emptyMsg,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (filtered) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined,
                              size: 18),
                          label: const Text('Reset Filter'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical &&
              n.metrics.extentAfter < 600) {
            _loadMore();
          }
          return false;
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: posts.length + 1,
              itemBuilder: (context, index) {
                if (index == posts.length) {
                  return _buildListFooter(data);
                }
                return PostCard(
                    key: ValueKey(posts[index].id), post: posts[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListFooter(_FeedPage data) {
    if (data.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (!data.hasMore && data.items.length > 3) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Kamu sudah melihat semua cerita ✨',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  Widget _buildFollowingTab() {
    if (!pb.authStore.isValid) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_outlined,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'Masuk untuk melihat cerita dari traveler yang Anda ikuti.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push('/login'),
                child: const Text('Masuk ke Akun'),
              ),
            ],
          ),
        ),
      );
    }
    return _buildFeedTab(
        _following, 'Ikuti traveler lain untuk melihat cerita mereka.');
  }
}
