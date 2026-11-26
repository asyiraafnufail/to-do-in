import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';
import '../../core/repositories/repositories.dart';
import '../../core/theme/app_theme.dart';

class CreateListingScreen extends StatefulWidget {
  final RecordModel? initialListing;

  const CreateListingScreen({super.key, this.initialListing});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  final _spec1KeyCtrl = TextEditingController(text: 'Tipe / Model');
  final _spec1ValCtrl = TextEditingController();
  final _spec2KeyCtrl = TextEditingController(text: 'Kapasitas / Fasilitas');
  final _spec2ValCtrl = TextEditingController();

  String _type = 'vehicle';
  String _priceUnit = 'day';
  String _province = 'DI Yogyakarta';

  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final l = widget.initialListing;
    if (l != null) {
      _titleCtrl.text = l.getStringValue('title');
      _descCtrl.text = l.getStringValue('description');
      _priceCtrl.text = l.getIntValue('price').toString();
      _cityCtrl.text = l.getStringValue('city');
      _type = l.getStringValue('type', 'vehicle');
      _priceUnit = l.getStringValue('price_unit', 'day');
      final prov = l.getStringValue('province');
      if (prov.isNotEmpty) _province = prov;

      final specs = l.get<Map<String, dynamic>?>('specs');
      if (specs != null && specs.isNotEmpty) {
        final entries = specs.entries.toList();
        if (entries.isNotEmpty) {
          _spec1KeyCtrl.text = entries[0].key;
          _spec1ValCtrl.text = entries[0].value?.toString() ?? '';
        }
        if (entries.length > 1) {
          _spec2KeyCtrl.text = entries[1].key;
          _spec2ValCtrl.text = entries[1].value?.toString() ?? '';
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _cityCtrl.dispose();
    _spec1KeyCtrl.dispose();
    _spec1ValCtrl.dispose();
    _spec2KeyCtrl.dispose();
    _spec2ValCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(String newType) {
    setState(() {
      _type = newType;
      if (newType == 'vehicle') {
        _priceUnit = 'day';
        _spec1KeyCtrl.text = 'Tipe / Model';
        _spec2KeyCtrl.text = 'Transmisi & Bensin';
      } else if (newType == 'open_trip') {
        _priceUnit = 'pax';
        _spec1KeyCtrl.text = 'Durasi Trip';
        _spec2KeyCtrl.text = 'Meeting Point';
      } else if (newType == 'stay') {
        _priceUnit = 'night';
        _spec1KeyCtrl.text = 'Tipe Kamar';
        _spec2KeyCtrl.text = 'Fasilitas Utama';
      }
    });
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (images.isNotEmpty) {
        setState(() {
          final spaceLeft = 6 - _selectedImages.length;
          _selectedImages.addAll(images.take(spaceLeft));
        });
      }
    } catch (_) {}
  }

  Future<Uint8List> _compressBytes(XFile file) async {
    final raw = await file.readAsBytes();
    if (kIsWeb || raw.lengthInBytes <= 524288) return raw;
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: 1024,
        minHeight: 768,
        quality: 75,
      );
      return compressed.lengthInBytes <= 524288 ? compressed : raw;
    } catch (_) {
      return raw;
    }
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = authRepo.currentUserId;
    if (userId == null) {
      context.push('/login');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final priceNum =
          double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
              0;

      final specs = <String, dynamic>{};
      if (_spec1ValCtrl.text.trim().isNotEmpty) {
        specs[_spec1KeyCtrl.text.trim()] = _spec1ValCtrl.text.trim();
      }
      if (_spec2ValCtrl.text.trim().isNotEmpty) {
        specs[_spec2KeyCtrl.text.trim()] = _spec2ValCtrl.text.trim();
      }

      final files = <http.MultipartFile>[];
      for (final img in _selectedImages) {
        final bytes = await _compressBytes(img);
        files.add(http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: img.name.isNotEmpty ? img.name : 'listing.jpg',
        ));
      }

      if (widget.initialListing != null) {
        await listingRepo.updateListing(
          widget.initialListing!.id,
          body: {
            'type': _type,
            'title': _titleCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'price': priceNum,
            'price_unit': _priceUnit,
            'city': _cityCtrl.text.trim(),
            'province': _province,
            'specs': specs,
          },
          files: files,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perubahan layanan disimpan!')),
          );
          context.pop(true);
        }
        return;
      }

      await listingRepo.createListing(
        body: {
          'owner': userId,
          'type': _type,
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'price': priceNum,
          'price_unit': _priceUnit,
          'city': _cityCtrl.text.trim(),
          'province': _province,
          'specs': specs,
          'is_available': true,
        },
        files: files,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan berhasil dipublikasikan!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat layanan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialListing != null
            ? 'Edit Layanan Host'
            : 'Tambah Layanan Host'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Type Selector
                  const Text('Jenis Layanan',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'vehicle',
                        label: Text('Kendaraan', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.two_wheeler, size: 16),
                      ),
                      ButtonSegment(
                        value: 'open_trip',
                        label: Text('Open Trip', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.hiking, size: 16),
                      ),
                      ButtonSegment(
                        value: 'stay',
                        label: Text('Homestay', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.hotel, size: 16),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (set) {
                      _onTypeChanged(set.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Title
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Judul Layanan',
                      hintText: _type == 'vehicle'
                          ? 'Cth: Sewa Honda Scoopy 2024 Dekat Stasiun'
                          : _type == 'open_trip'
                              ? 'Cth: One Day Trip Sunrise Merapi & Jeep'
                              : 'Cth: Paviliun Homestay Dekat Malioboro',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),

                  // Price & Unit
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga (Rp)',
                            hintText: '85000',
                            prefixText: 'Rp ',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Harga wajib diisi'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _priceUnit,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Satuan'),
                          items: const [
                            DropdownMenuItem(
                                value: 'day', child: Text('/ Hari')),
                            DropdownMenuItem(
                                value: 'pax', child: Text('/ Orang')),
                            DropdownMenuItem(
                                value: 'night', child: Text('/ Malam')),
                            DropdownMenuItem(
                                value: 'month', child: Text('/ Bulan')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _priceUnit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // City & Province
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Kota / Kabupaten',
                            hintText: 'Sleman',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Kota wajib diisi'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _province,
                          isExpanded: true,
                          menuMaxHeight: 320,
                          decoration: const InputDecoration(labelText: 'Provinsi'),
                          items: AppConstants.provinces
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _province = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Specs Form
                  const Text('Fasilitas & Detail',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _spec1KeyCtrl,
                          decoration: const InputDecoration(labelText: 'Label 1'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _spec1ValCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nilai 1',
                            hintText: 'Cth: Matic 125cc / 1 Hari',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _spec2KeyCtrl,
                          decoration: const InputDecoration(labelText: 'Label 2'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _spec2ValCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nilai 2',
                            hintText: 'Cth: Helm 2 + Jas Hujan',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Description
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Lengkap',
                      hintText:
                          'Jelaskan syarat sewa, fasilitas yang didapat, lokasi penjemputan/antar, dll.',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Deskripsi wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Image Upload Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Foto Layanan (${_selectedImages.length}/6)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      if (_selectedImages.length < 6)
                        TextButton.icon(
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text('Pilih Foto'),
                          onPressed: _pickImages,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedImages.isEmpty)
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Center(
                        child: InkWell(
                          onTap: _pickImages,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  size: 32, color: AppColors.textMuted),
                              SizedBox(height: 6),
                              Text(
                                'Unggah foto kendaraan, rute trip, atau kamar',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: FutureBuilder<Uint8List>(
                                  future: _selectedImages[idx].readAsBytes(),
                                  builder: (ctx, snap) {
                                    if (!snap.hasData) {
                                      return Container(
                                        width: 90,
                                        height: 90,
                                        color: Colors.grey.withOpacity(0.2),
                                      );
                                    }
                                    return Image.memory(
                                      snap.data!,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedImages.removeAt(idx);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(3),
                                    child: const Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Submit Button
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitListing,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.initialListing != null
                                ? 'Simpan Perubahan'
                                : 'Publikasikan Layanan',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
