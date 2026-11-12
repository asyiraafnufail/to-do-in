import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StreamSubscription<AuthStoreEvent>? _authSub;

  String? _selectedCategory;
  bool _isLoading = false;
  List<RecordModel> _latestPosts = [];
  List<RecordModel> _followingPosts = [];

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
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final catFilter = _selectedCategory != null
          ? 'category = "${_selectedCategory!}"'
          : '';

      if (_tabController.index == 0) {
        final res = await pb.collection('posts').getList(
              page: 1,
              perPage: 30,
              sort: '-created',
              expand: 'author',
              filter: catFilter,
            );
        if (mounted) {
          setState(() {
            _latestPosts = res.items;
            _isLoading = false;
          });
        }
      } else {
        final userId = pb.authStore.record?.id;
        if (userId == null) {
          if (mounted) {
            setState(() {
              _followingPosts = [];
              _isLoading = false;
            });
          }
          return;
        }

        // Fetch followed users
        final follows = await pb.collection('social_actions').getFullList(
              filter: 'user = "$userId" && action_type = "follow"',
            );
        final targetIds = follows
            .map((f) => f.getStringValue('target_user'))
            .where((id) => id.isNotEmpty)
            .toList();

        if (targetIds.isEmpty) {
          if (mounted) {
            setState(() {
              _followingPosts = [];
              _isLoading = false;
            });
          }
          return;
        }

        final authorOr =
            targetIds.map((id) => 'author = "$id"').join(' || ');
        final combinedFilter =
            catFilter.isNotEmpty ? '($authorOr) && $catFilter' : authorOr;

        final res = await pb.collection('posts').getList(
              page: 1,
              perPage: 30,
              sort: '-created',
              expand: 'author',
              filter: combinedFilter,
            );
        if (mounted) {
          setState(() {
            _followingPosts = res.items;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
          // Filter kategori chip
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
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
                _buildFeedTab(_latestPosts, 'Belum ada cerita perjalanan.'),
                _buildFollowingTab(),
              ],
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
            setState(() => _selectedCategory = value);
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

  Widget _buildFeedTab(List<RecordModel> posts, String emptyMsg) {
    if (_isLoading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
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
                      const Icon(Icons.explore_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        emptyMsg,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: posts.length,
            itemBuilder: (context, index) =>
                PostCard(key: ValueKey(posts[index].id), post: posts[index]),
          ),
        ),
      ),
    );
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
        _followingPosts, 'Ikuti traveler lain untuk melihat cerita mereka.');
  }
}
