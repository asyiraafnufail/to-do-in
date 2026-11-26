import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';

class AdminKycTab extends StatelessWidget {
  final List<RecordModel> kycRequests;
  final String kycFilter;
  final int totalUsers;
  final int pendingKycCount;
  final bool isDark;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onFilterChanged;
  final void Function(RecordModel kyc) onApprove;
  final void Function(RecordModel kyc) onReject;

  const AdminKycTab({
    super.key,
    required this.kycRequests,
    required this.kycFilter,
    required this.totalUsers,
    required this.pendingKycCount,
    required this.isDark,
    required this.onRefresh,
    required this.onFilterChanged,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = kycRequests.where((k) {
      if (kycFilter == 'all') return true;
      return k.getStringValue('status') == kycFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _buildKpiCard('Total User', '$totalUsers', Icons.people_outline,
                  const Color(0xFF0F766E)),
              const SizedBox(width: 10),
              _buildKpiCard('KYC Pending', '$pendingKycCount',
                  Icons.pending_actions, AppColors.accent),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Pending ($pendingKycCount)', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Semua (${kycRequests.length})', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Disetujui (${kycRequests.where((k) => k.getStringValue('status') == 'approved').length})',
                  'approved',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Ditolak (${kycRequests.where((k) => k.getStringValue('status') == 'rejected').length})',
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
                      'Tidak ada permohonan KYC pada filter "$kycFilter".',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((kyc) => _buildKycCard(context, kyc)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
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
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: kycFilter == value,
      onSelected: (_) => onFilterChanged(value),
    );
  }

  Widget _buildKycCard(BuildContext context, RecordModel kyc) {
    final status = kyc.getStringValue('status', 'pending');
    final user = kyc.get<RecordModel?>('expand.user');
    final name = user?.getStringValue('name') ?? '';
    final username = user?.getStringValue('username') ?? '';
    final email = user?.getStringValue('email') ?? '';
    final displayName = name.isNotEmpty
        ? name
        : (username.isNotEmpty
            ? '@$username'
            : 'User: ${kyc.getStringValue('user')}');

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
            const Text(
              'Dokumen Pengajuan KYC (Ketuk untuk memperbesar):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (idCard.isNotEmpty)
                  _buildDocThumbnail(
                    context,
                    'KTP / Identitas',
                    kycRepo.getProtectedDocumentUrl(kyc, idCard),
                    Icons.badge_outlined,
                  ),
                if (selfie.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildDocThumbnail(
                    context,
                    'Swafoto / Wajah',
                    kycRepo.getProtectedDocumentUrl(kyc, selfie),
                    Icons.face_outlined,
                  ),
                ],
                if (assetProof.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildDocThumbnail(
                    context,
                    'Bukti Aset',
                    kycRepo.getProtectedDocumentUrl(kyc, assetProof),
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
                if (status == 'pending')
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Tolak'),
                        onPressed: () => onReject(kyc),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.waGreen),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Setujui'),
                        onPressed: () => onApprove(kyc),
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Ubah Keputusan'),
                    onPressed: () => onReject(kyc),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocThumbnail(
    BuildContext context,
    String label,
    String url,
    IconData fallbackIcon,
  ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showImagePreview(context, label, url),
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

  void _showImagePreview(BuildContext context, String title, String fileUrl) {
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
}
