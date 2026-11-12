import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/pb_client.dart';
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
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            extended: MediaQuery.of(context).size.width >= 1024,
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
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = navigationShell.currentIndex;
    // Map branch index (0, 1, 2, 3) to bottom nav index (0, 1, 3, 4) with 2 as center button
    final navIndex = currentIndex >= 2 ? currentIndex + 1 : currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          currentIndex: navIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          onTap: (index) {
            if (index == 2) {
              _openCreateOptions(context);
              return;
            }
            final branchIndex = index > 2 ? index - 1 : index;
            navigationShell.goBranch(
              branchIndex,
              initialLocation: branchIndex == navigationShell.currentIndex,
            );
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
              label: 'Buat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.checklist_rtl_outlined),
              activeIcon: Icon(Icons.checklist_rtl),
              label: 'My To-Do',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateOptions(BuildContext context) {
    final isVerifiedHost =
        pb.authStore.record?.getBoolValue('is_verified_host') ?? false;

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
                if (!pb.authStore.isValid) {
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
                  // shortcut: guide/host listing form sprint 3
                },
              ),
          ],
        ),
      ),
    );
  }
}
