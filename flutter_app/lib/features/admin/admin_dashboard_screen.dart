import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  bool _isAdmin = false;

  // Overview metrics
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalListings = 0;
  int _pendingKycCount = 0;

  // KYC items
  List<RecordModel> _kycRequests = [];
  String _kycFilter = 'pending'; // 'all', 'pending', 'approved', 'rejected'

  // Posts items for moderation
  List<RecordModel> _moderationPosts = [];

  // Listings for moderation
  List<RecordModel> _moderationListings = [];

  // Superuser login controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoggingIn = false;
  String? _loginError;
  StreamSubscription<AuthStoreEvent>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = pb.authStore.onChange.listen((_) {
      if (mounted) _checkAdminStatus();
    });
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _checkAdminStatus() {
    final record = pb.authStore.record;
    final collectionName = record?.collectionName ?? '';
    final isSuperuser = collectionName == '_superusers' ||
        collectionName == 'admins' ||
        record?.getBoolValue('is_admin') == true ||
        record?.getStringValue('username') == 'admin' ||
        record?.getStringValue('email').startsWith('admin@') == true ||
        record?.data['collectionName'] == '_superusers' ||
        record?.data['collectionName'] == 'admins';

    setState(() {
      _isAdmin = isSuperuser && pb.authStore.isValid;
    });

    if (_isAdmin) {
      _loadDashboardData();
    }
  }

  Future<void> _loginAsAdmin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginError = 'Email dan kata sandi admin wajib diisi.');
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    try {
      // 1. Try modern PocketBase v0.23+ superusers collection
      bool authed = false;
      try {
        await pb.collection('_superusers').authWithPassword(email, password);
        authed = true;
      } catch (_) {
        // 2. Fallback to legacy admins endpoint if older pocketbase
        try {
          final res = await pb.send('/api/admins/auth-with-password',
              method: 'POST',
              body: {'identity': email, 'password': password});
          if (res is Map && res['token'] != null) {
            final token = res['token'] as String;
            final adminData = (res['admin'] as Map<String, dynamic>?) ?? {};
            pb.authStore.save(
              token,
              RecordModel({
                ...adminData,
                'id': adminData['id'] ?? 'admin',
                'email': email,
                'collectionName': '_superusers',
              }),
            );
            authed = true;
          }
        } catch (_) {
          // 3. Fallback to users collection with is_admin = true
          final userAuth =
              await pb.collection('users').authWithPassword(email, password);
          final rec = userAuth.record;
          if (rec.getBoolValue('is_admin') ||
              rec.getStringValue('username') == 'admin' ||
              rec.getStringValue('email').startsWith('admin@')) {
            authed = true;
          } else {
            pb.authStore.clear();
            throw 'Akun ini bukan administrator.';
          }
        }
      }

      if (authed && mounted) {
        setState(() {
          _isAdmin = true;
          _isLoggingIn = false;
        });
        _loadDashboardData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _loginError = 'Kredensial admin salah atau server menolak: $e';
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Load KYC Requests
      final kycRes = await pb.collection('kyc_requests').getFullList(
            sort: '-created',
            expand: 'user',
          );

      // 2. Load Recent Posts
      final postsRes = await pb.collection('posts').getList(
            page: 1,
            perPage: 30,
            sort: '-created',
            expand: 'author',
          );

      // 3. Load Recent Listings
      final listingsRes = await pb.collection('listings').getList(
            page: 1,
            perPage: 30,
            sort: '-created',
            expand: 'owner',
          );

      // 4. Count users
      final usersRes = await pb.collection('users').getList(perPage: 1);

      if (mounted) {
        setState(() {
          _kycRequests = kycRes;
          _pendingKycCount =
              kycRes.where((k) => k.getStringValue('status') == 'pending').length;
          _moderationPosts = postsRes.items;
          _moderationListings = listingsRes.items;
          _totalPosts = postsRes.totalItems;
          _totalListings = listingsRes.totalItems;
          _totalUsers = usersRes.totalItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data admin: $e')),
        );
      }
    }
  }

  Future<void> _approveKyc(RecordModel request) async {
    final userId = request.getStringValue('user');
    setState(() => _isLoading = true);

    try {
      // 1. Update KYC status to approved
      await pb.collection('kyc_requests').update(request.id, body: {
        'status': 'approved',
        'admin_note': 'Disetujui oleh Admin pada ${DateTime.now().toLocal()}',
      });

      // 2. Set user as verified host
      if (userId.isNotEmpty) {
        await pb.collection('users').update(userId, body: {
          'is_verified_host': true,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.waGreen,
            content: Text('KYC Disetujui! Lencana Verified Host aktif.'),
          ),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui KYC: $e')),
        );
      }
    }
  }

  Future<void> _rejectKyc(RecordModel request) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Pengajuan KYC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan alasan penolakan agar pemohon dapat memperbaikinya:',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Misal: Foto KTP buram atau tidak terbaca.',
                labelText: 'Catatan Admin',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak KYC'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final reason = noteCtrl.text.trim().isNotEmpty
          ? noteCtrl.text.trim()
          : 'Dokumen belum memenuhi persyaratan verifikasi.';

      await pb.collection('kyc_requests').update(request.id, body: {
        'status': 'rejected',
        'admin_note': reason,
      });

      // Revert verified host if previously approved
      final userId = request.getStringValue('user');
      if (userId.isNotEmpty) {
        await pb.collection('users').update(userId, body: {
          'is_verified_host': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan KYC ditolak.')),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak KYC: $e')),
        );
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Cerita (Moderasi)?'),
        content: const Text(
          'Postingan ini akan dihapus secara permanen dari feed dan database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await pb.collection('posts').delete(postId);
      feedRefreshNotifier.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cerita berhasil dimoderasi / dihapus.')),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus postingan: $e')),
        );
      }
    }
  }

  Future<void> _deleteListing(String listingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Layanan (Moderasi)?'),
        content: const Text(
          'Listing layanan ini akan dihapus permanen dari direktori Explore & Profil Host.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await pb.collection('listings').delete(listingId);
      listingsRefreshNotifier.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing layanan berhasil dihapus.')),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus listing: $e')),
        );
      }
    }
  }

  void _showImagePreview(String title, String fileUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              title: Text(title, style: const TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: fileUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Center(
                    child: Text(
                      'Gagal memuat gambar',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Login Admin Panel'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.admin_panel_settings,
                      size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Panel Moderasi & KYC',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Masuk menggunakan kredensial PocketBase Superuser untuk memverifikasi KYC & moderasi konten.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  if (_loginError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _loginError!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Superuser Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Kata Sandi Superuser',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    onSubmitted: (_) => _loginAsAdmin(),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _isLoggingIn ? null : _loginAsAdmin,
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Masuk ke Dashboard Admin'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Admin Panel',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat Ulang',
              onPressed: _loadDashboardData,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Keluar Admin',
              onPressed: () {
                pb.authStore.clear();
                setState(() => _isAdmin = false);
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('KYC Host'),
                    if (_pendingKycCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_pendingKycCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(text: 'Cerita ($_totalPosts)'),
              Tab(text: 'Layanan ($_totalListings)'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildKycTab(isDark, theme),
                  _buildPostsModerationTab(isDark, theme),
                  _buildListingsModerationTab(isDark, theme),
                ],
              ),
      ),
    );
  }

  Widget _buildKycTab(bool isDark, ThemeData theme) {
    final filtered = _kycRequests.where((k) {
      if (_kycFilter == 'all') return true;
      return k.getStringValue('status') == _kycFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Metrics KPI row
          Row(
            children: [
              _buildKpiCard('Total User', '$_totalUsers',
                  Icons.people_outline, const Color(0xFF0F766E), isDark),
              const SizedBox(width: 10),
              _buildKpiCard('KYC Pending', '$_pendingKycCount',
                  Icons.pending_actions, AppColors.accent, isDark),
            ],
          ),
          const SizedBox(height: 16),

          // KYC filter segmented chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildKycFilterChip('Pending ($_pendingKycCount)', 'pending'),
                const SizedBox(width: 8),
                _buildKycFilterChip('Semua (${_kycRequests.length})', 'all'),
                const SizedBox(width: 8),
                _buildKycFilterChip(
                  'Disetujui (${_kycRequests.where((k) => k.getStringValue('status') == 'approved').length})',
                  'approved',
                ),
                const SizedBox(width: 8),
                _buildKycFilterChip(
                  'Ditolak (${_kycRequests.where((k) => k.getStringValue('status') == 'rejected').length})',
                  'rejected',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada permohonan KYC pada filter "$_kycFilter".',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((kyc) => _buildKycCard(kyc, isDark, theme)),
        ],
      ),
    );
  }

  Widget _buildKycCard(RecordModel kyc, bool isDark, ThemeData theme) {
    final status = kyc.getStringValue('status', 'pending');
    final user = kyc.get<RecordModel?>('expand.user');
    final name = user?.getStringValue('name') ?? '';
    final username = user?.getStringValue('username') ?? '';
    final email = user?.getStringValue('email') ?? '';
    final displayName = name.isNotEmpty
        ? name
        : (username.isNotEmpty ? '@$username' : 'User: ${kyc.getStringValue('user')}');

    final idCard = kyc.getStringValue('id_card');
    final selfie = kyc.getStringValue('selfie');
    final assetProof = kyc.getStringValue('asset_proof');
    final note = kyc.getStringValue('admin_note');
    final created = kyc.getStringValue('created');

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = AppColors.waGreen;
        statusLabel = 'Disetujui';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'Ditolak';
        break;
      default:
        statusColor = AppColors.accent;
        statusLabel = 'Pending Review';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: User & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email.isNotEmpty ? email : '@$username',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Document Image Previews
            const Text(
              'Dokumen Pengajuan KYC (Ketuk untuk memperbesar):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (idCard.isNotEmpty)
                  _buildDocThumbnail(
                    'KTP / Identitas',
                    '${AppConstants.pbUrl}/api/files/kyc_requests/${kyc.id}/$idCard?token=${pb.authStore.token}',
                    Icons.badge_outlined,
                  ),
                if (selfie.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildDocThumbnail(
                    'Swafoto / Wajah',
                    '${AppConstants.pbUrl}/api/files/kyc_requests/${kyc.id}/$selfie?token=${pb.authStore.token}',
                    Icons.face_outlined,
                  ),
                ],
                if (assetProof.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildDocThumbnail(
                    'Bukti Aset',
                    '${AppConstants.pbUrl}/api/files/kyc_requests/${kyc.id}/$assetProof?token=${pb.authStore.token}',
                    Icons.directions_car_outlined,
                  ),
                ],
              ],
            ),

            if (note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Catatan: $note',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormatter.timeAgo(created),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                ),
                if (status == 'pending') ...[
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style:
                            OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Tolak'),
                        onPressed: () => _rejectKyc(kyc),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.waGreen),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Setujui'),
                        onPressed: () => _approveKyc(kyc),
                      ),
                    ],
                  ),
                ] else ...[
                  TextButton.icon(
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Ubah Keputusan'),
                    onPressed: () => _rejectKyc(kyc),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocThumbnail(String label, String url, IconData fallbackIcon) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showImagePreview(label, url),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(fallbackIcon, size: 20, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsModerationTab(bool isDark, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _moderationPosts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final post = _moderationPosts[idx];
          final title = post.getStringValue('title');
          final author = post.get<RecordModel?>('expand.author');
          final authorName = author?.getStringValue('name') ??
              author?.getStringValue('username') ??
              'Penulis';
          final city = post.getStringValue('city');
          final created = post.getStringValue('created');

          return Card(
            child: ListTile(
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Oleh $authorName • $city • ${DateFormatter.timeAgo(created)}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Hapus Postingan',
                onPressed: () => _deletePost(post.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListingsModerationTab(bool isDark, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _moderationListings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final listing = _moderationListings[idx];
          final title = listing.getStringValue('title');
          final owner = listing.get<RecordModel?>('expand.owner');
          final ownerName = owner?.getStringValue('name') ??
              owner?.getStringValue('username') ??
              'Host';
          final city = listing.getStringValue('city');
          final price = listing.getIntValue('price');
          final priceUnit = listing.getStringValue('price_unit');

          return Card(
            child: ListTile(
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Rp $price / $priceUnit • $ownerName ($city)',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Hapus Listing',
                onPressed: () => _deleteListing(listing.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style:
                      const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKycFilterChip(String label, String value) {
    final isSelected = _kycFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _kycFilter = value),
    );
  }
}
