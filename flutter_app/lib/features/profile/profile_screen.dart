import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../feed/widgets/post_card.dart';
import '../marketplace/widgets/listing_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StreamSubscription<AuthStoreEvent>? _authSub;

  bool _isLoading = false;
  bool _isRefreshingAuth = false;
  List<RecordModel> _myPosts = [];
  List<RecordModel> _gpsHistory = [];
  List<RecordModel> _savedPosts = [];
  List<RecordModel> _myListings = [];
  int _followersCount = 0;
  int _uniqueCityCount = 0;

  @override
  void initState() {
    super.initState();
    _authSub = pb.authStore.onChange.listen((_) {
      if (mounted && !_isRefreshingAuth) _loadUserData();
    });
    feedRefreshNotifier.addListener(_loadUserData);
    savedRefreshNotifier.addListener(_loadUserData);
    listingsRefreshNotifier.addListener(_loadUserData);
    _loadUserData(refreshAuth: true);
  }

  @override
  void dispose() {
    feedRefreshNotifier.removeListener(_loadUserData);
    savedRefreshNotifier.removeListener(_loadUserData);
    listingsRefreshNotifier.removeListener(_loadUserData);
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData({bool refreshAuth = false}) async {
    final userId = pb.authStore.record?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _myPosts = [];
          _gpsHistory = [];
          _savedPosts = [];
          _myListings = [];
          _followersCount = 0;
          _uniqueCityCount = 0;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    if (refreshAuth) {
      _isRefreshingAuth = true;
      try {
        await pb.collection('users').authRefresh();
      } catch (_) {
      } finally {
        _isRefreshingAuth = false;
      }
    }
    try {
      // 1. My posts (Feeds & Travel History)
      final postRes = await pb.collection('posts').getList(
            filter: 'author = "$userId"',
            sort: '-created',
            expand: 'author',
            perPage: 50,
          );
      final myPosts = postRes.items;
      final gpsHistory =
          myPosts.where((p) => p.getBoolValue('is_live_gps')).toList();

      final cities = myPosts
          .map((p) => p.getStringValue('city').trim().toLowerCase())
          .where((c) => c.isNotEmpty)
          .toSet();

      // 2. Followers count
      int followersCount = 0;
      try {
        final fRes = await pb.collection('social_actions').getList(
              filter:
                  'target_user = "$userId" && action_type = "follow"',
              perPage: 1,
            );
        followersCount = fRes.totalItems;
      } catch (_) {}

      // 3. Saved bookmarked posts
      List<RecordModel> savedPosts = [];
      try {
        final bRes = await pb.collection('social_actions').getList(
              filter: 'user = "$userId" && action_type = "bookmark"',
              sort: '-created',
              perPage: 50,
            );
        final postIds = bRes.items
            .map((b) => b.getStringValue('target_post'))
            .where((id) => id.isNotEmpty)
            .toList();

        if (postIds.isNotEmpty) {
          final filter =
              postIds.map((id) => 'id = "$id"').join(' || ');
          final savedRes = await pb.collection('posts').getList(
                filter: filter,
                expand: 'author',
                perPage: 50,
              );
          final postMap = {for (var p in savedRes.items) p.id: p};
          savedPosts = postIds
              .where(postMap.containsKey)
              .map((id) => postMap[id]!)
              .toList();
        }
      } catch (_) {}

      // 4. My listings
      List<RecordModel> myListings = [];
      try {
        final lRes = await pb.collection('listings').getList(
              filter: 'owner = "$userId"',
              sort: '-created',
              expand: 'owner',
              perPage: 50,
            );
        myListings = lRes.items;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _myPosts = myPosts;
          _gpsHistory = gpsHistory;
          _savedPosts = savedPosts;
          _myListings = myListings;
          _followersCount = followersCount;
          _uniqueCityCount = cities.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _sendingVerification = false;

  Future<void> _resendVerification(String email) async {
    if (email.isEmpty || _sendingVerification) return;
    setState(() => _sendingVerification = true);
    try {
      await pb.collection('users').requestVerification(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email verifikasi dikirim ke $email.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim email verifikasi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  Widget _buildVerifyEmailBanner(String email, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B2F1A) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Email belum diverifikasi. Tarik ke bawah untuk memuat ulang setelah verifikasi.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed:
                _sendingVerification ? null : () => _resendVerification(email),
            child: _sendingVerification
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kirim Ulang', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = pb.authStore.record;
    if (!pb.authStore.isValid || user == null) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'Profil',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline,
                    size: 56, color: AppColors.textMuted),
                const SizedBox(height: 16),
                const Text(
                  'Masuk ke Profil Anda',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kelola cerita perjalanan, Travel History otomatis, dan daftar layanan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Masuk / Daftar'),
                  onPressed: () async {
                    await context.push('/login');
                    if (mounted) _loadUserData();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = user.toJson();
    final isVerifiedHost = user.getBoolValue('is_verified_host') ||
        data['is_verified_host'] == true ||
        data['is_verified_host'] == 1 ||
        data['is_verified_host'] == 'true';
    final isSuperuser = user.collectionName == '_superusers' ||
        user.collectionName == 'admins' ||
        user.getBoolValue('is_admin') ||
        data['collectionName'] == '_superusers' ||
        data['collectionName'] == 'admins';
    final name = (data['name'] as String?)?.isNotEmpty == true
        ? data['name'] as String
        : data['username'] as String? ?? 'Traveler';
    final username = data['username'] as String? ?? '';
    final bio = data['bio'] as String? ?? '';
    final tabs = [
      Tab(text: 'Feeds (${_myPosts.length})'),
      Tab(text: 'Travel History (${_gpsHistory.length})'),
      Tab(text: 'Saved (${_savedPosts.length})'),
      if (isVerifiedHost) Tab(text: 'Layanan (${_myListings.length})'),
    ];

    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            '@$username',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Keluar',
              onPressed: () {
                pb.authStore.clear();
                _loadUserData();
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _loadUserData(refreshAuth: true),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor:
                              AppColors.primary.withOpacity(0.15),
                          backgroundImage: (data['avatar'] as String?)?.isNotEmpty == true
                              ? CachedNetworkImageProvider(
                                  pb.files.getURL(user, data['avatar'] as String).toString())
                              : null,
                          child: (data['avatar'] as String?)?.isNotEmpty == true
                              ? null
                              : Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat('${_myPosts.length}', 'Cerita'),
                              _buildStat('$_followersCount', 'Pengikut'),
                              _buildStat('$_uniqueCityCount', 'Kota'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
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
                    const SizedBox(height: 12),

                    // Actions: Edit Profil & Preview Profil Publik
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showEditProfileDialog(data),
                            child: const Text('Edit Profil'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          icon: const Icon(Icons.visibility_outlined, size: 20),
                          tooltip: 'Lihat Profil Publik',
                          onPressed: () => context.push('/user/${user.id}'),
                        ),
                      ],
                    ),

                    // Banner verifikasi email (hanya untuk akun users yang belum terverifikasi)
                    if (!isSuperuser &&
                        user.collectionName == 'users' &&
                        !user.getBoolValue('verified')) ...[
                      const SizedBox(height: 12),
                      _buildVerifyEmailBanner(
                          data['email'] as String? ?? '', isDark),
                    ],

                    if (isSuperuser) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                          label: const Text('Buka Admin Panel (Superuser)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                          ),
                          onPressed: () => context.push('/admin'),
                        ),
                      ),
                    ],

                    // KYC Local Host Verification Callout (if not yet verified)
                    if (!isVerifiedHost) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => context.push('/kyc'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_user_outlined,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Daftar Jadi Local Host Terverifikasi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Mulai pasang sewa motor/mobil, open trip, atau homestay.',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                    _buildPostsTab(_myPosts, 'Belum ada cerita yang Anda tulis.'),
                    _buildGpsHistoryTab(),
                    _buildPostsTab(
                        _savedPosts, 'Belum ada cerita yang disimpan.'),
                    if (isVerifiedHost) _buildMyListingsTab(),
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
    if (_isLoading && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 240,
            child: Center(
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
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 6, bottom: 20),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(
            key: ValueKey(posts[index].id),
            post: posts[index],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsHistoryTab() {
    if (_isLoading && _gpsHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_gpsHistory.isEmpty) {
      return ListView(
        children: const [
          SizedBox(
            height: 260,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_fixed,
                        size: 44, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Travel History Terverifikasi Kosong',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Saat membuat cerita dengan tombol Live GPS aktif di lokasi wisata, jejak perjalanan Anda akan otomatis tercatat di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color:
                                        AppColors.primary.withOpacity(0.08),
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
                            const SizedBox(height: 4),
                            Text(
                              '$city, $province',
                              style: const TextStyle(
                                color: AppColors.textSecondaryLight,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
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

  Widget _buildMyListingsTab() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Layanan Aktif (${_myListings.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah Layanan',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () => context.push('/create-listing'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_myListings.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'Anda belum memiliki listing layanan aktif.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonal(
                        onPressed: () => context.push('/create-listing'),
                        child: const Text('Tambah Layanan Sekarang'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._myListings.map(
                  (l) => ListingCard(key: ValueKey(l.id), listing: l)),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(Map<String, dynamic> data) {
    final user = pb.authStore.record;
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final bioCtrl = TextEditingController(text: data['bio'] ?? '');
    final waCtrl = TextEditingController(text: data['whatsapp'] ?? '');
    final igCtrl = TextEditingController(text: data['instagram'] ?? '');
    String privacy = (data['contact_privacy'] as String?)?.isNotEmpty == true
        ? data['contact_privacy'] as String
        : 'public';
    XFile? pickedAvatar;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentAvatar = data['avatar'] as String? ?? '';

          return AlertDialog(
            title: const Text('Edit Profil'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          backgroundImage: pickedAvatar != null
                              ? (kIsWeb
                                  ? NetworkImage(pickedAvatar!.path)
                                  : FileImage(File(pickedAvatar!.path))
                                      as ImageProvider)
                              : (currentAvatar.isNotEmpty && user != null
                                  ? CachedNetworkImageProvider(
                                      pb.files.getURL(user, currentAvatar).toString())
                                  : null),
                          child: (pickedAvatar == null && currentAvatar.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 40, color: AppColors.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () async {
                              final picker = ImagePicker();
                              final img = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 600,
                                maxHeight: 600,
                                imageQuality: 80,
                              );
                              if (img != null) {
                                setDialogState(() => pickedAvatar = img);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Tampilan'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bioCtrl,
                    maxLength: 160,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Bio'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: waCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp',
                      hintText: '628123456789',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: igCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username Instagram',
                      prefixText: '@',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: privacy,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(10),
                    decoration:
                        const InputDecoration(labelText: 'Privasi Kontak'),
                    items: const [
                      DropdownMenuItem(value: 'public', child: Text('Publik')),
                      DropdownMenuItem(
                          value: 'followers', child: Text('Hanya Pengikut')),
                      DropdownMenuItem(
                          value: 'hidden', child: Text('Sembunyikan')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => privacy = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final userId = pb.authStore.record?.id;
                        if (userId == null) return;
                        setDialogState(() => isSaving = true);
                        try {
                          final files = <http.MultipartFile>[];
                          if (pickedAvatar != null) {
                            final bytes = await pickedAvatar!.readAsBytes();
                            files.add(http.MultipartFile.fromBytes(
                              'avatar',
                              bytes,
                              filename: pickedAvatar!.name,
                            ));
                          }
                          final updated = await pb.collection('users').update(
                            userId,
                            body: {
                              'name': nameCtrl.text.trim(),
                              'bio': bioCtrl.text.trim(),
                              'whatsapp': waCtrl.text.trim(),
                              'instagram': igCtrl.text.trim(),
                              'contact_privacy': privacy,
                            },
                            files: files,
                          );
                          pb.authStore.save(pb.authStore.token, updated);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadUserData();
                        } catch (_) {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }
}
