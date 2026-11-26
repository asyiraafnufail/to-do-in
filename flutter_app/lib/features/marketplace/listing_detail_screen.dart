import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/repositories/repositories.dart';
import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  bool _isLoading = true;
  String? _error;
  RecordModel? _listing;
  bool _isSavingTodo = false;
  bool _isSavedToTodo = false;
  bool _isUpdatingAvail = false;

  @override
  void initState() {
    super.initState();
    _loadListing();
  }

  Future<void> _loadListing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final record = await listingRepo.getListing(widget.listingId);
      if (mounted) {
        setState(() {
          _listing = record;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat layanan: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatPrice(num price) {
    final s = price.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  String _unitLabel(String unit) {
    switch (unit) {
      case 'day':
        return '/ hari';
      case 'night':
        return '/ malam';
      case 'pax':
        return '/ orang';
      case 'month':
        return '/ bulan';
      default:
        return '';
    }
  }

  Future<void> _contactHost(String wa, String hostName, String title) async {
    if (wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nomor WhatsApp host belum terdaftar.')),
      );
      return;
    }

    final clean = wa.replaceAll(RegExp(r'[^0-9]'), '');
    final msg =
        'Halo $hostName, saya tertarik dengan layanan "$title" di todoin.id. Apakah masih tersedia?';
    final uri =
        Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleAvailability(bool nextVal) async {
    if (_isUpdatingAvail || _listing == null) return;
    setState(() => _isUpdatingAvail = true);
    try {
      final updated =
          await listingRepo.setAvailability(_listing!.id, nextVal);
      if (mounted) {
        setState(() => _listing = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextVal
                  ? 'Status layanan diubah menjadi Tersedia'
                  : 'Status layanan diubah menjadi Penuh',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAvail = false);
    }
  }

  Future<void> _saveListingToTodo(String title, String city) async {
    if (_isSavingTodo || _isSavedToTodo) return;
    if (authRepo.currentUserId == null) {
      final loggedIn = await context.push<bool>('/login');
      if (loggedIn != true || !mounted) return;
    }
    final userId = authRepo.currentUserId;
    if (userId == null) return;

    setState(() => _isSavingTodo = true);
    try {
      await todoRepo.addTodo(
        userId: userId,
        city: city.isNotEmpty ? city : 'Indonesia',
        taskTitle: 'Layanan: $title',
      );
      if (mounted) {
        setState(() => _isSavedToTodo = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Layanan ditambahkan ke My To-Do!'),
            action: SnackBarAction(
              label: 'Lihat',
              textColor: AppColors.accent,
              onPressed: () => context.go('/todo'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan ke To-Do: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingTodo = false);
    }
  }

  Future<void> _deleteListing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Layanan?'),
        content: const Text('Layanan ini akan dihapus dari pencarian publik.'),
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

    if (confirm == true && mounted) {
      try {
        await listingRepo.deleteListing(widget.listingId);
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Layanan berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _listing == null) {
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
                Text(_error ?? 'Layanan tidak ditemukan'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadListing,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final listing = _listing!;
    final owner = listing.get<RecordModel?>('expand.owner');
    final ownerId = listing.getStringValue('owner');
    final currentUserId = authRepo.currentUserId;
    final isOwnListing = currentUserId != null && currentUserId == ownerId;

    final rawOwnerName = owner?.getStringValue('name') ?? '';
    final rawOwnerUsername = owner?.getStringValue('username') ?? '';
    final ownerName = rawOwnerName.isNotEmpty
        ? rawOwnerName
        : (rawOwnerUsername.isNotEmpty ? '@$rawOwnerUsername' : 'Host Lokal');
    final ownerAvatar = owner?.getStringValue('avatar') ?? '';
    final isVerifiedHost = owner?.getBoolValue('is_verified_host') ?? false;
    final ownerWa = owner?.getStringValue('whatsapp') ?? '';

    final title = listing.getStringValue('title');
    final description = listing.getStringValue('description');
    final type = listing.getStringValue('type');
    final price = listing.getDoubleValue('price');
    final unit = listing.getStringValue('price_unit');
    final city = listing.getStringValue('city');
    final province = listing.getStringValue('province');
    final images = listing.getListValue<String>('images');
    final specs = listing.get<Map<String, dynamic>?>('specs') ?? {};
    final isAvailable = listing.getBoolValue('is_available', true);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isOwnListing) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Layanan',
              onPressed: () async {
                final updated = await context.push<bool>(
                  '/create-listing',
                  extra: listing,
                );
                if (updated == true) _loadListing();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Hapus Layanan',
              onPressed: _deleteListing,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Image Gallery
                      if (images.isNotEmpty) ...[
                        SizedBox(
                          height: 230,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, idx) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: CachedNetworkImage(
                                    imageUrl: pbFileUrl(listing, images[idx]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Type pill & Location
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type == 'vehicle'
                                  ? 'Sewa Motor / Mobil'
                                  : type == 'open_trip'
                                      ? 'Open Trip'
                                      : 'Homestay & Kos',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: AppColors.accent),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '$city, $province',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Availability status & Host toggle (FR-5.2)
                      if (isOwnListing)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? AppColors.liveGpsBg
                                : Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isAvailable
                                  ? AppColors.liveGpsFg.withOpacity(0.35)
                                  : Colors.red.withOpacity(0.35),
                            ),
                          ),
                          child: SwitchListTile(
                            dense: true,
                            title: Text(
                              isAvailable
                                  ? 'Status: Tersedia'
                                  : 'Status: Penuh / Tidak Tersedia',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: isAvailable
                                    ? AppColors.liveGpsFg
                                    : Colors.red,
                              ),
                            ),
                            subtitle: const Text(
                              'Ubah status agar traveler tahu ketersediaan terbaru.',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            value: isAvailable,
                            onChanged:
                                _isUpdatingAvail ? null : _toggleAvailability,
                          ),
                        )
                      else if (!isAvailable)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.35)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.event_busy,
                                  size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Layanan ini sedang penuh / tidak tersedia saat ini.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),

                      // Price Display Card
                      Container(
                        padding: const EdgeInsets.all(14),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tarif Resmi Host',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text.rich(
                              TextSpan(
                                text: 'Rp ${_formatPrice(price)} ',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  fontFamily:
                                      theme.textTheme.bodyMedium?.fontFamily,
                                ),
                                children: [
                                  TextSpan(
                                    text: _unitLabel(unit),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Specs Table (if any)
                      if (specs.isNotEmpty) ...[
                        Text('Spesifikasi & Fasilitas',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: specs.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${e.key}: ${e.value}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Description
                      Text('Deskripsi Layanan',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Host Profile Card
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: owner != null
                              ? () => context.push('/user/${owner.id}')
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.12),
                                  backgroundImage: ownerAvatar.isNotEmpty &&
                                          owner != null
                                      ? CachedNetworkImageProvider(
                                          pbFileUrl(owner, ownerAvatar))
                                      : null,
                                  child: ownerAvatar.isEmpty
                                      ? Text(
                                          ownerName.isNotEmpty
                                              ? ownerName[0].toUpperCase()
                                              : 'H',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              ownerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isVerifiedHost) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified,
                                                size: 16,
                                                color: AppColors.primary),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Local Host Terverifikasi • Tekan untuk lihat profil & ulasan',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // Sticky Bottom Action Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isSavedToTodo
                              ? AppColors.liveGpsFg
                              : AppColors.primary,
                          side: BorderSide(
                            color: _isSavedToTodo
                                ? AppColors.liveGpsFg
                                : AppColors.primary,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        icon: Icon(
                          _isSavedToTodo ? Icons.check : Icons.add_task,
                          size: 18,
                        ),
                        label: Text(
                          _isSavedToTodo ? 'Tersimpan' : '+ To-Do',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: (_isSavingTodo || _isSavedToTodo)
                            ? null
                            : () => _saveListingToTodo(title, city),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isAvailable
                                ? AppColors.waGreen
                                : AppColors.textMuted,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.chat, size: 18),
                          label: Text(
                            isAvailable
                                ? 'Hubungi via WhatsApp'
                                : 'Tanya Host via WA',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () =>
                              _contactHost(ownerWa, ownerName, title),
                        ),
                      ),
                    ],
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
