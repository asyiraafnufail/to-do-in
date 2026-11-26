import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/services/pb_client.dart';
import '../../../core/theme/app_theme.dart';

class ListingCard extends StatelessWidget {
  final RecordModel listing;

  const ListingCard({super.key, required this.listing});

  String _formatPrice(num price) {
    // shortcut: manual thousand separator without external intl dependency
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

  (String label, IconData icon, Color color) _typeConfig(String type) {
    switch (type) {
      case 'vehicle':
        return ('Sewa Kendaraan', Icons.two_wheeler, AppColors.primary);
      case 'open_trip':
        return ('Open Trip', Icons.hiking, AppColors.accent);
      case 'stay':
        return ('Homestay', Icons.hotel, Colors.indigo);
      default:
        return ('Layanan', Icons.storefront, AppColors.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = listing.getStringValue('title');
    final type = listing.getStringValue('type');
    final price = listing.getDoubleValue('price');
    final unit = listing.getStringValue('price_unit');
    final city = listing.getStringValue('city');
    final province = listing.getStringValue('province');
    final images = listing.getListValue<String>('images');
    final isAvailable = listing.data['is_available'] != false;

    final owner = listing.get<RecordModel?>('expand.owner');
    final rawOwnerName = owner?.getStringValue('name') ?? '';
    final rawOwnerUsername = owner?.getStringValue('username') ?? '';
    final ownerName = rawOwnerName.isNotEmpty
        ? rawOwnerName
        : (rawOwnerUsername.isNotEmpty ? '@$rawOwnerUsername' : 'Host');
    final ownerAvatar = owner?.getStringValue('avatar') ?? '';
    final isVerifiedHost = owner?.getBoolValue('is_verified_host') ?? false;

    final (typeLabel, typeIcon, typeColor) = _typeConfig(type);

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withOpacity(0.75)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/listing/${listing.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image thumbnail preview
              if (images.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: pbFileUrl(listing, images.first),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.textMuted.withOpacity(0.1),
                            child: const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.textMuted.withOpacity(0.1),
                            child: const Icon(Icons.broken_image,
                                color: AppColors.textMuted),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon, size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  typeLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isAvailable)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Penuh',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: typeColor),
                          const SizedBox(width: 5),
                          Text(
                            typeLabel,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isAvailable) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Penuh',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 10),

              // Title
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Location
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$city, $province',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Bottom footer: Price & Host Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price
                  Text.rich(
                    TextSpan(
                      text: 'Rp ${_formatPrice(price)} ',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                      ),
                      children: [
                        TextSpan(
                          text: _unitLabel(unit),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Host mini tag
                  Flexible(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: owner != null
                          ? () => context.push('/user/${owner.id}')
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor:
                                  typeColor.withOpacity(0.15),
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
                                      style: TextStyle(
                                        color: typeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                ownerName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerifiedHost) ...[
                              const SizedBox(width: 3),
                              const Icon(Icons.verified,
                                  size: 14, color: AppColors.primary),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
