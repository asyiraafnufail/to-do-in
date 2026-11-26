import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/repositories/repositories.dart';
import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../feed/widgets/post_card.dart';
import '../marketplace/widgets/listing_card.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  String? _error;
  RecordModel? _user;

  bool _isFollowing = false;
  String? _followActionId;
  bool _isTogglingFollow = false;

  int _postCount = 0;
  int _followerCount = 0;
  int _cityCount = 0;

  List<RecordModel> _posts = [];
  List<RecordModel> _gpsHistory = [];
  List<RecordModel> _listings = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await authRepo.getUser(widget.userId);
      final currentUserId = authRepo.currentUserId;

      // 1. Follow status
      String? followActionId;
      if (currentUserId != null && currentUserId != widget.userId) {
        followActionId = await socialRepo.getFollowActionId(
          userId: currentUserId,
          targetUserId: widget.userId,
        );
      }
      final isFollowing = followActionId != null;

      // 2. Posts & Travel History
      final posts = await postRepo.getPostsByAuthor(widget.userId);
      final gpsHistory =
          posts.where((p) => p.getBoolValue('is_live_gps')).toList();
      final cities = posts
          .map((p) => p.getStringValue('city').trim().toLowerCase())
          .where((c) => c.isNotEmpty)
          .toSet();

      // 3. Followers count
      int followerCount = 0;
      try {
        followerCount = await socialRepo.getFollowerCount(widget.userId);
      } catch (_) {}

      // 4. Listings if host
      List<RecordModel> listings = [];
      if (user.getBoolValue('is_verified_host')) {
        try {
          final lRes = await listingRepo.getListings(
            ownerId: widget.userId,
            perPage: 50,
          );
          listings = lRes.items;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _user = user;
          _isFollowing = isFollowing;
          _followActionId = followActionId;
          _posts = posts;
          _gpsHistory = gpsHistory;
          _listings = listings;
          _postCount = posts.length;
          _followerCount = followerCount;
          _cityCount = cities.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat profil: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = authRepo.currentUserId;
    if (currentUserId == null) {
      context.push('/login');
      return;
    }
    if (_isTogglingFollow) return;

    setState(() => _isTogglingFollow = true);
    try {
      final wasFollowing = _isFollowing && _followActionId != null;
      final newActionId = await socialRepo.toggleFollow(
        userId: currentUserId,
        targetUserId: widget.userId,
        existingActionId: wasFollowing ? _followActionId : null,
      );
      if (mounted) {
        setState(() {
          _isFollowing = newActionId != null;
          _followActionId = newActionId;
          _followerCount = wasFollowing
              ? (_followerCount - 1).clamp(0, 999999)
              : _followerCount + 1;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  Future<void> _handleContactTap(VoidCallback onAuthorized) async {
    if (!authRepo.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Masuk ke akun untuk melihat dan menghubungi kontak kreator.'),
          action: SnackBarAction(
            label: 'Masuk',
            textColor: AppColors.accent,
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }
    onAuthorized();
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
        'https://wa.me/$clean?text=${Uri.encodeComponent("Halo $name, saya menemukan profil Anda di todoin.id.")}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openInstagram(String username) async {
    final clean = username.replaceAll('@', '').trim();
    final uri = Uri.parse('https://instagram.com/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _user == null) {
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
                Text(_error ?? 'User tidak ditemukan'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadAll,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _user!;
    final currentUserId = authRepo.currentUserId;
    final isMe = currentUserId != null && currentUserId == widget.userId;

    final rawName = user.getStringValue('name');
    final username = user.getStringValue('username');
    final name = rawName.isNotEmpty
        ? rawName
        : (username.isNotEmpty ? '@$username' : 'Traveler');
    final avatar = user.getStringValue('avatar');
    final bio = user.getStringValue('bio');
    final isVerifiedHost = user.getBoolValue('is_verified_host');
    final wa = user.getStringValue('whatsapp');
    final ig = user.getStringValue('instagram');
    final privacy = user.getStringValue('contact_privacy', 'public');

    final canViewContact = isMe ||
        privacy == 'public' ||
        (privacy == 'followers' && _isFollowing);

    final tabs = [
      Tab(text: 'Feeds ($_postCount)'),
      Tab(text: 'Travel History (${_gpsHistory.length})'),
      if (isVerifiedHost) Tab(text: 'Layanan (${_listings.length})'),
    ];

    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('@$username'),
        ),
        body: RefreshIndicator(
          onRefresh: _loadAll,
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        backgroundImage: avatar.isNotEmpty
                            ? CachedNetworkImageProvider(
                                pbFileUrl(user, avatar))
                            : null,
                        child: avatar.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStat('$_postCount', 'Cerita'),
                            _buildStat('$_followerCount', 'Pengikut'),
                            _buildStat('$_cityCount', 'Kota'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerifiedHost) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified,
                            size: 18, color: AppColors.primary),
                      ],
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(bio, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 14),

                  // Actions: Follow & Contact Buttons
                  Row(
                    children: [
                      if (!isMe) ...[
                        Expanded(
                          child: _isFollowing
                              ? OutlinedButton.icon(
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Mengikuti'),
                                  onPressed: _isTogglingFollow
                                      ? null
                                      : _toggleFollow,
                                )
                              : FilledButton.icon(
                                  icon: const Icon(Icons.person_add, size: 16),
                                  label: const Text('Ikuti'),
                                  onPressed: _isTogglingFollow
                                      ? null
                                      : _toggleFollow,
                                ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (canViewContact && wa.isNotEmpty)
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.waGreen.withOpacity(0.12),
                            foregroundColor: AppColors.waGreen,
                          ),
                          icon: const Icon(Icons.chat, size: 20),
                          tooltip: 'Chat WhatsApp',
                          onPressed: () =>
                              _handleContactTap(() => _openWhatsApp(wa, name)),
                        ),
                      if (canViewContact && ig.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.purple.withOpacity(0.12),
                            foregroundColor: Colors.purple,
                          ),
                          icon: const Icon(Icons.camera_alt, size: 20),
                          tooltip: 'Instagram @$ig',
                          onPressed: () =>
                              _handleContactTap(() => _openInstagram(ig)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              tabs: tabs,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPostsTab(_posts, 'Belum ada cerita yang ditulis.'),
                  _buildGpsHistoryTab(),
                  if (isVerifiedHost) _buildListingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildStat(String count, String label) {
    return Column(
      children: [
        Text(count,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _buildPostsTab(List<RecordModel> posts, String emptyMsg) {
    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.article_outlined,
                  size: 44, color: AppColors.textMuted),
              const SizedBox(height: 10),
              Text(emptyMsg,
                  style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 6, bottom: 20),
          itemCount: posts.length,
          itemBuilder: (context, index) =>
              PostCard(key: ValueKey(posts[index].id), post: posts[index]),
        ),
      ),
    );
  }

  Widget _buildGpsHistoryTab() {
    if (_gpsHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gps_fixed, size: 44, color: AppColors.textMuted),
              SizedBox(height: 10),
              Text(
                'Belum ada jejak Travel History terverifikasi.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _gpsHistory.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final p = _gpsHistory[index];
            final placeName = p.getStringValue('place_name');
            final city = p.getStringValue('city');
            final province = p.getStringValue('province');
            final lat = p.getDoubleValue('lat_approx');
            final lng = p.getDoubleValue('lng_approx');
            final created = p.getStringValue('created');
            final category = p.getStringValue('category');

            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/post/${p.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF052E16)
                              : AppColors.liveGpsBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.gps_fixed,
                            color: AppColors.liveGpsFg, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    placeName.isNotEmpty ? placeName : city,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$city, $province',
                              style: const TextStyle(
                                color: AppColors.textSecondaryLight,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  DateFormatter.timeAgo(created),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                if (lat != 0.0 && lng != 0.0) ...[
                                  const Text(' • ',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                                  Text(
                                    '($lat, $lng)',
                                    style: const TextStyle(
                                      color: AppColors.liveGpsFg,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListingsTab() {
    if (_listings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined,
                  size: 44, color: AppColors.textMuted),
              SizedBox(height: 10),
              Text(
                'Belum ada listing layanan yang aktif.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _listings.length,
          itemBuilder: (context, index) =>
              ListingCard(key: ValueKey(_listings[index].id), listing: _listings[index]),
        ),
      ),
    );
  }
}
