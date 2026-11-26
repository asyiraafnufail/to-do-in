import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/repositories.dart';
import '../theme/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 720;

    if (isDesktop) {
      return _buildDesktopLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showRightPanel = width >= 1150;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            extended: width >= 1024,
            minExtendedWidth: 220,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Buat Postingan'),
                onPressed: () => _openCreateOptions(context),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppColors.primary),
                label: Text('Beranda'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore, color: AppColors.primary),
                label: Text('Explore & Sewa'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checklist_rtl_outlined),
                selectedIcon:
                    Icon(Icons.checklist_rtl, color: AppColors.primary),
                label: Text('My To-Do'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: AppColors.primary),
                label: Text('Profil'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: navigationShell),
          if (showRightPanel) ...[
            const VerticalDivider(width: 1, thickness: 1),
            SizedBox(
              width: 320,
              child: _buildRightContextPanel(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRightContextPanel(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Destinasi Trending',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...[
          ('Kopi Klotok Pakem', 'Sleman, DI Yogyakarta', Icons.restaurant),
          ('Tebing Breksi', 'Sleman, DI Yogyakarta', Icons.landscape),
          ('Kelingking Beach', 'Nusa Penida, Bali', Icons.beach_access),
          ('Gunung Bromo', 'Probolinggo, Jawa Timur', Icons.terrain),
        ].map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.go('/explore'),
              child: Container(
                padding: const EdgeInsets.all(10),
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
                    Icon(d.$3, size: 16, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.$1,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(d.$2,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F2B26), const Color(0xFF0F172A)]
                  : [const Color(0xFFF0FDFA), const Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Local Guide & Host',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Punya unit motor/mobil, open trip, atau kamar homestay? Daftarkan diri jadi Verified Host di todoin.id.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () => context.push('/kyc'),
                child: const Text('Ajukan Verifikasi',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.4)
                      : const Color(0xFF0F172A).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(isDark ? 0.12 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withOpacity(0.92)
                        : Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155).withOpacity(0.8)
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        context: context,
                        index: 0,
                        currentIndex: currentIndex,
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Beranda',
                        onTap: () => navigationShell.goBranch(
                          0,
                          initialLocation: 0 == currentIndex,
                        ),
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        context: context,
                        index: 1,
                        currentIndex: currentIndex,
                        icon: Icons.explore_outlined,
                        activeIcon: Icons.explore_rounded,
                        label: 'Explore',
                        onTap: () => navigationShell.goBranch(
                          1,
                          initialLocation: 1 == currentIndex,
                        ),
                        isDark: isDark,
                      ),
                      _buildCenterActionButton(context, isDark: isDark),
                      _buildNavItem(
                        context: context,
                        index: 2,
                        currentIndex: currentIndex,
                        icon: Icons.checklist_rtl_outlined,
                        activeIcon: Icons.checklist_rtl_rounded,
                        label: 'My To-Do',
                        onTap: () => navigationShell.goBranch(
                          2,
                          initialLocation: 2 == currentIndex,
                        ),
                        isDark: isDark,
                      ),
                      _buildNavItem(
                        context: context,
                        index: 3,
                        currentIndex: currentIndex,
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: 'Profil',
                        onTap: () => navigationShell.goBranch(
                          3,
                          initialLocation: 3 == currentIndex,
                        ),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required int currentIndex,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = isDark ? const Color(0xFF2DD4BF) : AppColors.primary;
    final inactiveColor =
        isDark ? AppColors.textMuted : const Color(0xFF64748B);

    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: activeColor.withOpacity(0.12),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? const Color(0xFF2DD4BF).withOpacity(0.14)
                        : AppColors.primary.withOpacity(0.09))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      size: 21,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                      letterSpacing: -0.2,
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

  Widget _buildCenterActionButton(BuildContext context,
      {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Buat Cerita atau Layanan',
        child: InkWell(
          onTap: () => _openCreateOptions(context),
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withOpacity(0.38),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  void _openCreateOptions(BuildContext context) {
    final isVerifiedHost =
        authRepo.currentUser?.getBoolValue('is_verified_host') ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.liveGpsBg,
                child: Icon(Icons.edit_note, color: AppColors.liveGpsFg),
              ),
              title: const Text('Tulis Cerita & To-Do',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Bagikan cerita perjalanan dengan validasi Live GPS.'),
              onTap: () async {
                Navigator.pop(ctx);
                if (!authRepo.isAuthenticated) {
                  final loggedIn = await context.push<bool>('/login');
                  if (loggedIn != true || !context.mounted) return;
                }
                if (context.mounted) context.push('/create');
              },
            ),
            if (isVerifiedHost)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent.withOpacity(0.15),
                  child: const Icon(Icons.storefront, color: AppColors.accent),
                ),
                title: const Text('Tambah Layanan Sewa / Trip',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Listing Open Trip, sewa motor/mobil, atau homestay.'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/create-listing');
                },
              ),
          ],
        ),
      ),
    );
  }
}
