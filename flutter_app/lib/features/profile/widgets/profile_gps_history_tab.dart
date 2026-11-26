import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';

class ProfileGpsHistoryTab extends StatelessWidget {
  final List<RecordModel> gpsHistory;
  final bool isLoading;

  const ProfileGpsHistoryTab({
    super.key,
    required this.gpsHistory,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && gpsHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gpsHistory.isEmpty) {
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
                    Icon(Icons.gps_fixed, size: 44, color: AppColors.textMuted),
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
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
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
          itemCount: gpsHistory.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final p = gpsHistory[index];
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
}
