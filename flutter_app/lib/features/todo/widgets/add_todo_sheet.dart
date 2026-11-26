import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

Future<String?> showEditTodoNoteDialog(
  BuildContext context, {
  required String currentNote,
  required String taskTitle,
}) async {
  final noteCtrl = TextEditingController(text: currentNote);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Catatan Pribadi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(taskTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.primary)),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Misal: Bawa uang tunai, datang sebelum jam 07.00...',
              labelText: 'Catatan Anda',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  final result = saved == true ? noteCtrl.text.trim() : null;
  noteCtrl.dispose();
  return result;
}

Future<void> showAddTodoBottomSheet(
  BuildContext context, {
  required List<String> existingCities,
  required Future<void> Function(String city, String task, String notes) onSave,
}) async {
  final cityController = TextEditingController();
  final taskController = TextEditingController();
  final notesController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Tambah Rencana To-Do',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tambahkan aktivitas baru ke daftar perjalanan Anda.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Kota / Kabupaten',
                    hintText: 'Misal: Sleman, Yogyakarta, Bali',
                    prefixIcon:
                        const Icon(Icons.location_on_outlined, size: 20),
                    suffixIcon: existingCities.isNotEmpty
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.arrow_drop_down),
                            tooltip: 'Pilih Kota Yang Ada',
                            onSelected: (val) {
                              setModalState(() {
                                cityController.text = val;
                              });
                            },
                            itemBuilder: (_) => existingCities
                                .map((c) => PopupMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ))
                                .toList(),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: taskController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nama Aktivitas',
                    hintText: 'Misal: Sunrise di Candi Plaosan',
                    prefixIcon: Icon(Icons.checklist, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    hintText: 'Misal: Datang jam 05.00 pagi, bawa jaket',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check, size: 19),
                    label: const Text(
                      'Simpan ke My To-Do',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    onPressed: () async {
                      final task = taskController.text.trim();
                      final city = cityController.text.trim();
                      if (task.isEmpty || city.isEmpty) return;

                      await onSave(city, task, notesController.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  cityController.dispose();
  taskController.dispose();
  notesController.dispose();
}
