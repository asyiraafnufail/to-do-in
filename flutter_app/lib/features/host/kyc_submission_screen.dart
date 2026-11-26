import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/repositories/repositories.dart';
import '../../core/theme/app_theme.dart';

class KycSubmissionScreen extends StatefulWidget {
  const KycSubmissionScreen({super.key});

  @override
  State<KycSubmissionScreen> createState() => _KycSubmissionScreenState();
}

class _KycSubmissionScreenState extends State<KycSubmissionScreen> {
  bool _isLoading = true;
  RecordModel? _existingRequest;

  XFile? _idCardFile;
  XFile? _selfieFile;
  XFile? _assetProofFile;
  final _noteCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkExistingKyc();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkExistingKyc() async {
    final userId = authRepo.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      try {
        await authRepo.refreshAuth();
      } catch (_) {}
      final latest = await kycRepo.getLatestUserRequest(userId);
      if (mounted) {
        setState(() {
          if (latest != null) {
            _existingRequest = latest;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _compressBytes(XFile file) async {
    final raw = await file.readAsBytes();
    if (kIsWeb || raw.lengthInBytes <= 5242880) return raw;
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: 1280,
        minHeight: 960,
        quality: 80,
      );
      return compressed.lengthInBytes <= 5242880 ? compressed : raw;
    } catch (_) {
      return raw;
    }
  }

  Future<void> _submitKyc() async {
    if (_idCardFile == null || _selfieFile == null || _assetProofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Lengkapi semua dokumen: KTP, Selfie dengan KTP, dan Bukti Aset.'),
        ),
      );
      return;
    }

    final userId = authRepo.currentUserId;
    if (userId == null) {
      context.push('/login');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final idBytes = await _compressBytes(_idCardFile!);
      final selfieBytes = await _compressBytes(_selfieFile!);
      final assetBytes = await _compressBytes(_assetProofFile!);

      final files = [
        http.MultipartFile.fromBytes(
          'id_card',
          idBytes,
          filename: _idCardFile!.name.isNotEmpty
              ? _idCardFile!.name
              : 'id_card.jpg',
        ),
        http.MultipartFile.fromBytes(
          'selfie',
          selfieBytes,
          filename:
              _selfieFile!.name.isNotEmpty ? _selfieFile!.name : 'selfie.jpg',
        ),
        http.MultipartFile.fromBytes(
          'asset_proof',
          assetBytes,
          filename: _assetProofFile!.name.isNotEmpty
              ? _assetProofFile!.name
              : 'asset.jpg',
        ),
      ];

      final created = await kycRepo.submitRequest(
        userId: userId,
        note: _noteCtrl.text.trim(),
        files: files,
      );

      if (mounted) {
        setState(() {
          _existingRequest = created;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan KYC berhasil dikirim! Menunggu verifikasi.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pengajuan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verifikasi Local Host')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Status pending / approved display
    String? rejectedNote;
    if (_existingRequest != null) {
      final status = _existingRequest!.getStringValue('status');
      final note = _existingRequest!.getStringValue('admin_note');
      if (status == 'rejected') {
        rejectedNote = note.isNotEmpty
            ? note
            : 'Dokumen belum memenuhi syarat. Silakan unggah ulang dengan foto yang jelas.';
      } else if (status == 'pending') {
        return Scaffold(
          appBar: AppBar(title: const Text('Status Verifikasi Host')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.hourglass_top,
                          size: 56, color: Colors.amber),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Pengajuan Sedang Diverifikasi',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Dokumen identitas (KTP) dan bukti aset kendaraan/homestay Anda sedang ditinjau oleh tim verifikator todoin.id. Proses verifikasi biasanya selesai dalam 1x24 jam kerja.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.tonal(
                      onPressed: () => context.pop(),
                      child: const Text('Kembali ke Profil'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else if (status == 'approved') {
        return Scaffold(
          appBar: AppBar(title: const Text('Status Verifikasi Host')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.liveGpsBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified,
                          size: 56, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Selamat! Anda Local Host Terverifikasi',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Akun Anda sudah memiliki centang verifikasi resmi. Anda sekarang dapat mempublikasikan listing sewa kendaraan, open trip, atau homestay di Marketplace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.push('/create-listing'),
                      child: const Text('Buat Listing Pertama'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Local Host Terverifikasi'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (rejectedNote != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pengajuan Sebelumnya Ditolak',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rejectedNote,
                                style: const TextStyle(fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Info Banner
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
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield, color: AppColors.primary, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Standar Keamanan Anti-Penipuan todoin.id',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Hanya traveler dan pemilik usaha lokal dengan identitas asli serta bukti kepemilikan aset yang berhak memasang listing sewa di platform.',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 1. KTP
                _buildDocTile(
                  title: '1. Foto KTP / Paspor',
                  subtitle:
                      'Pastikan NIK, nama lengkap, dan foto wajah terbaca jelas tanpa pantulan cahaya.',
                  file: _idCardFile,
                  onPick: () async {
                    final f = await _pickImage(ImageSource.gallery);
                    if (f != null) setState(() => _idCardFile = f);
                  },
                  onRemove: () => setState(() => _idCardFile = null),
                ),
                const SizedBox(height: 16),

                // 2. Selfie + KTP
                _buildDocTile(
                  title: '2. Foto Selfie dengan KTP',
                  subtitle:
                      'Pegang KTP di samping wajah. Pastikan wajah dan kartu terlihat jelas.',
                  file: _selfieFile,
                  onPick: () async {
                    final f = await _pickImage(ImageSource.camera);
                    if (f != null) setState(() => _selfieFile = f);
                  },
                  onRemove: () => setState(() => _selfieFile = null),
                ),
                const SizedBox(height: 16),

                // 3. Bukti Aset
                _buildDocTile(
                  title: '3. Bukti Kepemilikan Aset',
                  subtitle:
                      'Foto STNK kendaraan, sertifikat tour guide, atau bukti izin operasional homestay.',
                  file: _assetProofFile,
                  onPick: () async {
                    final f = await _pickImage(ImageSource.gallery);
                    if (f != null) setState(() => _assetProofFile = f);
                  },
                  onRemove: () => setState(() => _assetProofFile = null),
                ),
                const SizedBox(height: 16),

                // Catatan tambahan
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan untuk Admin (Opsional)',
                    hintText:
                        'Cth: Pemilik rental motor Jogja armada 10 unit Honda.',
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                FilledButton(
                  onPressed: _isSubmitting ? null : _submitKyc,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kirim Dokumen Verifikasi',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocTile({
    required String title,
    required String subtitle,
    required XFile? file,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                if (file != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.liveGpsBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 14, color: AppColors.liveGpsFg),
                        SizedBox(width: 4),
                        Text(
                          'Siap',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.liveGpsFg,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            if (file == null)
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Unggah Foto Dokumen'),
                onPressed: onPick,
              )
            else
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: FutureBuilder<Uint8List>(
                      future: file.readAsBytes(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.withOpacity(0.2),
                          );
                        }
                        return Image.memory(
                          snap.data!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      file.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: onRemove,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
