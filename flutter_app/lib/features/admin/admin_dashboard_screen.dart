import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/repositories/repositories.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/admin_kyc_tab.dart';
import 'widgets/admin_login_view.dart';
import 'widgets/admin_moderation_tabs.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  bool _isAdmin = false;

  int _totalUsers = 0;
  int _totalPosts = 0;
  int _totalListings = 0;
  int _pendingKycCount = 0;

  List<RecordModel> _kycRequests = [];
  String _kycFilter = 'pending'; // 'all', 'pending', 'approved', 'rejected'

  List<RecordModel> _moderationPosts = [];
  List<RecordModel> _moderationListings = [];

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoggingIn = false;
  String? _loginError;
  StreamSubscription<AuthStoreEvent>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = authRepo.onAuthChanged.listen((_) {
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
    final isAdmin = authRepo.isAuthenticated && authRepo.isSuperuserOrAdmin();
    setState(() => _isAdmin = isAdmin);
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
      await authRepo.loginAdminOnly(email, password);
      if (mounted) {
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
      final kycRes = await kycRepo.getAllRequests();
      final postsRes = await postRepo.getPosts(page: 1, perPage: 30);
      final listingsRes = await listingRepo.getListings(page: 1, perPage: 30);
      final totalUsers = await authRepo.countUsers();

      if (mounted) {
        setState(() {
          _kycRequests = kycRes;
          _pendingKycCount = kycRes
              .where((k) => k.getStringValue('status') == 'pending')
              .length;
          _moderationPosts = postsRes.items;
          _moderationListings = listingsRes.items;
          _totalPosts = postsRes.totalItems;
          _totalListings = listingsRes.totalItems;
          _totalUsers = totalUsers;
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
    setState(() => _isLoading = true);
    try {
      await kycRepo.approveRequest(request);
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

    final rawReason = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final reason = rawReason.isNotEmpty
          ? rawReason
          : 'Dokumen belum memenuhi persyaratan verifikasi.';
      await kycRepo.rejectRequest(request, reason);

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
      await postRepo.deletePost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cerita berhasil dimoderasi / dihapus.')),
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
      await listingRepo.deleteListing(listingId);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_isAdmin) {
      return AdminLoginView(
        emailController: _emailCtrl,
        passwordController: _passwordCtrl,
        isLoggingIn: _isLoggingIn,
        loginError: _loginError,
        onSubmit: _loginAsAdmin,
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
                authRepo.logout();
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
                  AdminKycTab(
                    kycRequests: _kycRequests,
                    kycFilter: _kycFilter,
                    totalUsers: _totalUsers,
                    pendingKycCount: _pendingKycCount,
                    isDark: isDark,
                    onRefresh: _loadDashboardData,
                    onFilterChanged: (v) => setState(() => _kycFilter = v),
                    onApprove: _approveKyc,
                    onReject: _rejectKyc,
                  ),
                  AdminPostsModerationTab(
                    posts: _moderationPosts,
                    onRefresh: _loadDashboardData,
                    onDeletePost: _deletePost,
                  ),
                  AdminListingsModerationTab(
                    listings: _moderationListings,
                    onRefresh: _loadDashboardData,
                    onDeleteListing: _deleteListing,
                  ),
                ],
              ),
      ),
    );
  }
}
