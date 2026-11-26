import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';
import '../../core/repositories/repositories.dart';
import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';
import '../feed/widgets/post_card.dart';
import '../marketplace/widgets/listing_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedProvince;

  // 'posts' or 'listings'
  String _activeTab = 'posts';
  String? _listingType;

  bool _isLoading = false;
  List<RecordModel> _posts = [];
  List<RecordModel> _listings = [];

  @override
  void initState() {
    super.initState();
    feedRefreshNotifier.addListener(_fetchData);
    listingsRefreshNotifier.addListener(_fetchData);
    _fetchData();
  }

  @override
  void dispose() {
    feedRefreshNotifier.removeListener(_fetchData);
    listingsRefreshNotifier.removeListener(_fetchData);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final q = _searchCtrl.text.trim();

      if (_activeTab == 'posts') {
        final res = await postRepo.getPosts(
          page: 1,
          perPage: 30,
          province: _selectedProvince,
          query: q,
          searchContent: false,
        );
        if (mounted) {
          setState(() {
            _posts = res.items;
            _isLoading = false;
          });
        }
      } else {
        final res = await listingRepo.getListings(
          page: 1,
          perPage: 30,
          province: _selectedProvince,
          type: _listingType,
          query: q,
        );
        if (mounted) {
          setState(() {
            _listings = res.items;
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
        title: Text(
          'Explore & Sewa',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search box
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B).withOpacity(0.85)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: isDark
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _fetchData(),
                            decoration: InputDecoration(
                              filled: false,
                              fillColor: Colors.transparent,
                              isDense: true,
                              hintText: _activeTab == 'posts'
                                  ? 'Cari destinasi, kota, tempat...'
                                  : 'Cari sewa motor, open trip, homestay...',
                              hintStyle: TextStyle(
                                fontSize: 13.5,
                                color: isDark
                                    ? AppColors.textMuted
                                    : const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 13),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.search,
                                    color: AppColors.primary, size: 21),
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_searchCtrl.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear,
                                          size: 18, color: AppColors.textMuted),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _fetchData();
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.tune,
                                        color: AppColors.primary, size: 20),
                                    tooltip: 'Filter Provinsi',
                                    onPressed: _showFilterDialog,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Segmented Mode Switcher (Cerita & To-Do vs Sewa & Layanan)
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withOpacity(0.7)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
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
                            Expanded(
                              child: _buildSegmentItem(
                                label: 'Cerita & To-Do',
                                icon: Icons.article_outlined,
                                isSelected: _activeTab == 'posts',
                                isDark: isDark,
                                onTap: () {
                                  if (_activeTab != 'posts') {
                                    setState(() => _activeTab = 'posts');
                                    _fetchData();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildSegmentItem(
                                label: 'Sewa & Layanan',
                                icon: Icons.storefront_outlined,
                                isSelected: _activeTab == 'listings',
                                isDark: isDark,
                                onTap: () {
                                  if (_activeTab != 'listings') {
                                    setState(() => _activeTab = 'listings');
                                    _fetchData();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Provinsi filter chips
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildProvChip('Semua Wilayah', null, isDark: isDark),
                            ...[
                              'DI Yogyakarta',
                              'Bali',
                              'Jawa Barat',
                              'Jawa Timur',
                              'DKI Jakarta',
                            ].map((p) => _buildProvChip(p, p, isDark: isDark)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Kategori Layanan Cepat (Shortcut buttons)
                      if (_activeTab == 'posts') ...[
                        Text(
                          'Layanan Lokal Terverifikasi',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCategoryCard(
                                title: 'Sewa Motor/Mobil',
                                icon: Icons.two_wheeler,
                                subtitle: 'Mulai Rp70rb/hari',
                                color: AppColors.primary,
                                isDark: isDark,
                                onTap: () {
                                  setState(() {
                                    _activeTab = 'listings';
                                    _listingType = 'vehicle';
                                  });
                                  _fetchData();
                                },
                              ),
                              const SizedBox(width: 10),
                              _buildCategoryCard(
                                title: 'Open Trip',
                                icon: Icons.hiking,
                                subtitle: 'Local Guide',
                                color: AppColors.accent,
                                isDark: isDark,
                                onTap: () {
                                  setState(() {
                                    _activeTab = 'listings';
                                    _listingType = 'open_trip';
                                  });
                                  _fetchData();
                                },
                              ),
                              const SizedBox(width: 10),
                              _buildCategoryCard(
                                title: 'Homestay & Kos',
                                icon: Icons.hotel,
                                subtitle: 'Dekat Wisata',
                                color: Colors.indigo,
                                isDark: isDark,
                                onTap: () {
                                  setState(() {
                                    _activeTab = 'listings';
                                    _listingType = 'stay';
                                  });
                                  _fetchData();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _selectedProvince == null
                              ? 'Cerita Destinasi (${_posts.length})'
                              : 'Destinasi di $_selectedProvince (${_posts.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ] else ...[
                        // Type filter chips for listings
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildListingTypeChip('Semua Jenis', null, isDark: isDark),
                              _buildListingTypeChip('Kendaraan', 'vehicle', isDark: isDark),
                              _buildListingTypeChip('Open Trip', 'open_trip', isDark: isDark),
                              _buildListingTypeChip('Homestay', 'stay', isDark: isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _selectedProvince == null
                              ? 'Layanan Tersedia (${_listings.length})'
                              : 'Layanan di $_selectedProvince (${_listings.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),

                if (_isLoading && (_posts.isEmpty && _listings.isEmpty))
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_activeTab == 'posts')
                  if (_posts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.map_outlined,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              _selectedProvince == null
                                  ? 'Belum ada cerita untuk pencarian ini.'
                                  : 'Belum ada cerita di $_selectedProvince',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._posts.map((p) => PostCard(key: ValueKey(p.id), post: p))
                else if (_activeTab == 'listings')
                  if (_listings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.storefront_outlined,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              _selectedProvince == null
                                  ? 'Belum ada layanan yang terdaftar.'
                                  : 'Belum ada layanan di $_selectedProvince',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._listings.map(
                        (l) => ListingCard(key: ValueKey(l.id), listing: l)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListingTypeChip(String label, String? value,
      {required bool isDark}) {
    final isSelected = _listingType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _listingType = value);
            _fetchData();
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
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProvChip(String label, String? value, {required bool isDark}) {
    final isSelected = _selectedProvince == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _selectedProvince = value);
            _fetchData();
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
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentItem({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  )
                : null,
            borderRadius: BorderRadius.circular(9),
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
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withOpacity(0.7)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.15)
                  : const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.2),
                          color.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 17, color: color),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pilih Provinsi',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    if (_selectedProvince != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedProvince = null);
                          Navigator.pop(ctx);
                          _fetchData();
                        },
                        child: const Text('Reset'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: AppConstants.provinces
                        .map((p) => ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              title: Text(p),
                              trailing: _selectedProvince == p
                                  ? const Icon(Icons.check,
                                      color: AppColors.primary)
                                  : null,
                              onTap: () {
                                setState(() => _selectedProvince = p);
                                Navigator.pop(ctx);
                                _fetchData();
                              },
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
