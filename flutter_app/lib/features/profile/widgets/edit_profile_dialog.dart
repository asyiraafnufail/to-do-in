import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/repositories/repositories.dart';
import '../../../core/services/pb_client.dart';
import '../../../core/theme/app_theme.dart';

Future<bool> showEditProfileDialog(
  BuildContext context, {
  required Map<String, dynamic> data,
}) async {
  final user = authRepo.currentUser;
  final nameCtrl = TextEditingController(text: data['name'] ?? '');
  final bioCtrl = TextEditingController(text: data['bio'] ?? '');
  final waCtrl = TextEditingController(text: data['whatsapp'] ?? '');
  final igCtrl = TextEditingController(text: data['instagram'] ?? '');
  String privacy = (data['contact_privacy'] as String?)?.isNotEmpty == true
      ? data['contact_privacy'] as String
      : 'public';
  XFile? pickedAvatar;
  bool isSaving = false;

  final updated = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final currentAvatar = data['avatar'] as String? ?? '';

        return AlertDialog(
          title: const Text('Edit Profil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        backgroundImage: pickedAvatar != null
                            ? (kIsWeb
                                ? NetworkImage(pickedAvatar!.path)
                                : FileImage(File(pickedAvatar!.path))
                                    as ImageProvider)
                            : (currentAvatar.isNotEmpty && user != null
                                ? CachedNetworkImageProvider(
                                    pbFileUrl(user, currentAvatar))
                                : null),
                        child: (pickedAvatar == null && currentAvatar.isEmpty)
                            ? const Icon(Icons.person,
                                size: 40, color: AppColors.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () async {
                            final picker = ImagePicker();
                            final img = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 600,
                              maxHeight: 600,
                              imageQuality: 80,
                            );
                            if (img != null) {
                              setDialogState(() => pickedAvatar = img);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Tampilan'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bioCtrl,
                  maxLength: 160,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: waCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp',
                    hintText: '628123456789',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: igCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username Instagram',
                    prefixText: '@',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: privacy,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(10),
                  decoration:
                      const InputDecoration(labelText: 'Privasi Kontak'),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Publik')),
                    DropdownMenuItem(
                        value: 'followers', child: Text('Hanya Pengikut')),
                    DropdownMenuItem(
                        value: 'hidden', child: Text('Sembunyikan')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => privacy = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final userId = authRepo.currentUserId;
                      if (userId == null) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final files = <http.MultipartFile>[];
                        if (pickedAvatar != null) {
                          final bytes = await pickedAvatar!.readAsBytes();
                          files.add(http.MultipartFile.fromBytes(
                            'avatar',
                            bytes,
                            filename: pickedAvatar!.name,
                          ));
                        }
                        await authRepo.updateProfile(
                          userId: userId,
                          name: nameCtrl.text.trim(),
                          bio: bioCtrl.text.trim(),
                          whatsapp: waCtrl.text.trim(),
                          instagram: igCtrl.text.trim(),
                          contactPrivacy: privacy,
                          files: files,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (_) {
                        if (ctx.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan'),
            ),
          ],
        );
      },
    ),
  );

  nameCtrl.dispose();
  bioCtrl.dispose();
  waCtrl.dispose();
  igCtrl.dispose();
  return updated == true;
}
