import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';
import '../../core/repositories/repositories.dart';
import '../../core/services/pb_client.dart';
import '../../core/theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  final RecordModel? initialPost;

  const CreatePostScreen({super.key, this.initialPost});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _todoItemCtrl = TextEditingController();

  String _category = AppConstants.postCategories.first;
  String _province = 'DI Yogyakarta';
  bool _isLiveGps = false;
  double? _lat;
  double? _lng;
  bool _isLoadingGps = false;
  String? _gpsError;
  bool _isSubmitting = false;

  final List<String> _todoList = [];
  final List<XFile> _selectedImages = [];
  final _picker = ImagePicker();

  static const int _maxImages = 5;

  /// Nama file foto yang sudah tersimpan di server (mode edit).
  final List<String> _existingImages = [];

  /// Foto lama yang ditandai untuk dihapus saat menyimpan.
  final List<String> _removedImages = [];

  int get _totalImages => _existingImages.length + _selectedImages.length;

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalImages;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal $_maxImages foto per cerita.')),
      );
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked.isNotEmpty && mounted) {
        setState(() {
          _selectedImages.addAll(picked.take(remaining));
        });
        if (picked.length > remaining) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Maksimal $_maxImages foto. ${picked.length - remaining} foto tidak ditambahkan.'),
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final p = widget.initialPost;
    if (p != null) {
      _titleCtrl.text = p.getStringValue('title');
      _contentCtrl.text = p.getStringValue('content');
      _placeCtrl.text = p.getStringValue('place_name');
      _cityCtrl.text = p.getStringValue('city');
      final cat = p.getStringValue('category');
      if (AppConstants.postCategories.contains(cat)) {
        _category = cat;
      }
      final prov = p.getStringValue('province');
      if (prov.isNotEmpty) _province = prov;
      _isLiveGps = p.getBoolValue('is_live_gps');
      _lat = p.getDoubleValue('lat_approx');
      _lng = p.getDoubleValue('lng_approx');
      _todoList.addAll(
        p.getListValue<dynamic>('todo_items').map((e) => e.toString()),
      );
      _existingImages.addAll(p.getListValue<String>('images'));
    } else {
      _fetchGpsLocation();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _placeCtrl.dispose();
    _cityCtrl.dispose();
    _todoItemCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() {
      _isLoadingGps = true;
      _gpsError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingGps = false;
            _gpsError = 'Layanan lokasi (GPS) pada perangkat belum aktif.';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoadingGps = false;
            _gpsError =
                'Izin lokasi ditolak permanen. Aktifkan di Pengaturan perangkat.';
          });
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLoadingGps = false;
            _gpsError = 'Izin lokasi belum diberikan.';
          });
        }
        return;
      }

      Position? pos;
      if (!kIsWeb) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        final LocationSettings settings =
            defaultTargetPlatform == TargetPlatform.android && !kIsWeb
                ? AndroidSettings(
                    accuracy: LocationAccuracy.high,
                    distanceFilter: 0,
                    // shortcut: forceLocationManager bypasses Play Services fuse stalls on Android emulators
                    forceLocationManager: true,
                    timeLimit: const Duration(seconds: 15),
                  )
                : const LocationSettings(
                    accuracy: LocationAccuracy.high,
                    timeLimit: Duration(seconds: 15),
                  );
        pos = await Geolocator.getCurrentPosition(locationSettings: settings);
      }

      // shortcut: round to 3 decimal places (~110m accuracy) per PRD NFR-1 privacy rule
      final latRounded = double.parse(pos.latitude.toStringAsFixed(3));
      final lngRounded = double.parse(pos.longitude.toStringAsFixed(3));

      // Reverse geocoding otomatis per PRD FR-2.2
      String? detectedCity;
      String? detectedProvince;
      String? detectedPlace;
      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final rawCity = place.subAdministrativeArea?.isNotEmpty == true
              ? place.subAdministrativeArea!
              : (place.locality?.isNotEmpty == true ? place.locality! : '');
          if (rawCity.isNotEmpty) {
            detectedCity = rawCity
                .replaceAll(RegExp(r'^(Kabupaten|Kota)\s+', caseSensitive: false), '')
                .trim();
          }

          if (place.administrativeArea?.isNotEmpty == true) {
            final rawProv = place.administrativeArea!;
            detectedProvince = AppConstants.provinces.firstWhere(
              (p) =>
                  p.toLowerCase() == rawProv.toLowerCase() ||
                  rawProv.toLowerCase().contains(p.toLowerCase()) ||
                  p.toLowerCase().contains(rawProv.toLowerCase()),
              orElse: () => _province,
            );
          }

          if (place.name?.isNotEmpty == true &&
              place.name != rawCity &&
              place.name != place.administrativeArea) {
            detectedPlace = place.name;
          }
        }
      } catch (geoErr) {
        debugPrint('Reverse geocoding note: $geoErr');
      }

      if (mounted) {
        setState(() {
          _lat = latRounded;
          _lng = lngRounded;
          _isLiveGps = true;
          _isLoadingGps = false;
          _gpsError = null;
          if (detectedCity != null && _cityCtrl.text.trim().isEmpty) {
            _cityCtrl.text = detectedCity;
          }
          if (detectedProvince != null) {
            _province = detectedProvince;
          }
          if (detectedPlace != null && _placeCtrl.text.trim().isEmpty) {
            _placeCtrl.text = detectedPlace;
          }
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isLoadingGps = false;
          _gpsError =
              'GPS belum merespons. Di emulator: buka "..." > Location > tekan "Set Location", lalu refresh.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGps = false;
          _gpsError = 'Gagal mendeteksi lokasi: $e';
        });
      }
    }
  }

  Future<Uint8List> _compressBytes(XFile file) async {
    final raw = await file.readAsBytes();
    if (kIsWeb || raw.lengthInBytes <= 450000) return raw; // < ~450 KB is safe under 512 KB
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        raw,
        minWidth: 1280,
        minHeight: 1280,
        quality: 75,
      );
      return compressed.lengthInBytes <= 524288 ? compressed : raw;
    } catch (_) {
      return raw;
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan isi cerita wajib diisi.')),
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
      final slugBase = _titleCtrl.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch % 1000000;
      final slug =
          '${slugBase.isEmpty ? 'cerita' : slugBase}-$uniqueSuffix';

      final isEdit = widget.initialPost != null;
      final files = <http.MultipartFile>[];
      for (final img in _selectedImages) {
        final bytes = await _compressBytes(img);
        files.add(http.MultipartFile.fromBytes(
          // Saat edit, gunakan modifier "images+" agar foto lama tidak tertimpa.
          isEdit ? 'images+' : 'images',
          bytes,
          filename: img.name.isNotEmpty ? img.name : 'image.jpg',
        ));
      }

      if (isEdit) {
        await postRepo.updatePost(
          widget.initialPost!.id,
          body: {
            'title': _titleCtrl.text.trim(),
            'content': _contentCtrl.text.trim(),
            'category': _category,
            'place_name': _placeCtrl.text.trim(),
            'city': _cityCtrl.text.trim().isNotEmpty
                ? _cityCtrl.text.trim()
                : 'Yogyakarta',
            'province': _province,
            'todo_items': _todoList,
            'is_edited': true,
            if (_removedImages.isNotEmpty) 'images-': _removedImages,
          },
          files: files,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perubahan cerita disimpan!')),
          );
          context.pop(true);
        }
        return;
      }

      await postRepo.createPost(
        body: {
          'author': userId,
          'title': _titleCtrl.text.trim(),
          'slug': slug,
          'content': _contentCtrl.text.trim(),
          'category': _category,
          'place_name': _placeCtrl.text.trim(),
          'city': _cityCtrl.text.trim().isNotEmpty
              ? _cityCtrl.text.trim()
              : 'Yogyakarta',
          'province': _province,
          'is_live_gps': _isLiveGps,
          'lat_approx': _lat,
          'lng_approx': _lng,
          'todo_items': _todoList,
          'is_edited': false,
        },
        files: files,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cerita berhasil diterbitkan!')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menerbitkan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialPost != null ? 'Edit Cerita & To-Do' : 'Tulis Cerita & To-Do',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.initialPost != null ? 'Simpan' : 'Publikasikan'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 480;
            final maxMenuHeight =
                (MediaQuery.of(context).size.height * 0.45).clamp(220.0, 360.0);

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _buildGpsBanner(isDark),
                    const SizedBox(height: 16),

                    // Judul (wrap otomatis saat teks panjang)
                    TextField(
                      controller: _titleCtrl,
                      style: theme.textTheme.titleMedium,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Judul Cerita Perjalanan...',
                        labelText: 'Judul',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Kategori & Provinsi (responsif terhadap lebar layar)
                    if (isCompact) ...[
                      _buildCategoryField(maxMenuHeight),
                      const SizedBox(height: 14),
                      _buildProvinceField(maxMenuHeight),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildCategoryField(maxMenuHeight)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildProvinceField(maxMenuHeight)),
                        ],
                      ),
                    const SizedBox(height: 14),

                    // Nama Tempat & Kota (responsif terhadap lebar layar)
                    if (isCompact) ...[
                      _buildPlaceField(),
                      const SizedBox(height: 14),
                      _buildCityField(),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildPlaceField()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildCityField()),
                        ],
                      ),
                    const SizedBox(height: 14),

                    // Isi Cerita Panjang (wrap + scroll otomatis)
                    TextField(
                      controller: _contentCtrl,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 6,
                      maxLines: 14,
                      style: theme.textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        hintText:
                            'Tulis pengalaman autentik, suasana, rute, atau tips untuk pembaca...',
                        labelText: 'Isi Cerita',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Foto Perjalanan (Opsional, maks 5 foto)
                    _buildPhotoPickerCard(theme),
                    const SizedBox(height: 16),

                    // Blok To-Do Rekomendasi Penulis
                    _buildTodoCard(theme, isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGpsBanner(bool isDark) {
    final bgColor = _isLiveGps
        ? (isDark ? const Color(0xFF052E16) : AppColors.liveGpsBg)
        : (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB));
    final borderColor = _isLiveGps
        ? AppColors.liveGpsFg
        : (isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B));
    final fgColor = _isLiveGps
        ? (isDark ? const Color(0xFF86EFAC) : AppColors.liveGpsFg)
        : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _isLiveGps ? Icons.gps_fixed : Icons.gps_not_fixed,
            size: 20,
            color: fgColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isLoadingGps
                  ? 'Memeriksa lokasi GPS...'
                  : _isLiveGps
                      ? 'Live GPS Aktif ($_lat, $_lng)'
                      : _gpsError ??
                          'GPS Mati: Cerita tayang tanpa lencana Live GPS',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: _isLoadingGps
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fgColor,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 19),
              color: fgColor,
              tooltip: 'Deteksi Ulang GPS',
              onPressed: _isLoadingGps ? null : _fetchGpsLocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryField(double maxMenuHeight) {
    return DropdownButtonFormField<String>(
      value: _category,
      isExpanded: true,
      menuMaxHeight: maxMenuHeight,
      borderRadius: BorderRadius.circular(10),
      decoration: const InputDecoration(labelText: 'Kategori'),
      items: AppConstants.postCategories
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _category = v);
      },
    );
  }

  Widget _buildProvinceField(double maxMenuHeight) {
    return DropdownButtonFormField<String>(
      value: _province,
      isExpanded: true,
      menuMaxHeight: maxMenuHeight,
      borderRadius: BorderRadius.circular(10),
      decoration: const InputDecoration(labelText: 'Provinsi'),
      items: AppConstants.provinces
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _province = v);
      },
    );
  }

  Widget _buildPlaceField() {
    return TextField(
      controller: _placeCtrl,
      textCapitalization: TextCapitalization.words,
      keyboardType: TextInputType.multiline,
      minLines: 1,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Nama Tempat / Spot',
        hintText: 'Misal: Kopi Klotok',
      ),
    );
  }

  Widget _buildCityField() {
    return TextField(
      controller: _cityCtrl,
      textCapitalization: TextCapitalization.words,
      keyboardType: TextInputType.multiline,
      minLines: 1,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Kota / Kabupaten',
        hintText: 'Misal: Sleman',
      ),
    );
  }

  Widget _buildPhotoPickerCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Foto Perjalanan ($_totalImages/$_maxImages)',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                if (_totalImages < _maxImages)
                  TextButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        size: 18),
                    label: const Text('Tambah Foto'),
                  ),
              ],
            ),
            if (_totalImages > 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _totalImages,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final isExisting = idx < _existingImages.length;
                    final Widget thumb;
                    if (isExisting) {
                      final name = _existingImages[idx];
                      thumb = Image.network(
                        pbFileUrl(widget.initialPost!, name, thumb: '200x200'),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      );
                    } else {
                      final img =
                          _selectedImages[idx - _existingImages.length];
                      thumb = kIsWeb
                          ? Image.network(img.path, fit: BoxFit.cover)
                          : Image.file(File(img.path), fit: BoxFit.cover);
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(width: 86, height: 86, child: thumb),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => setState(() {
                              if (isExisting) {
                                _removedImages
                                    .add(_existingImages.removeAt(idx));
                              } else {
                                _selectedImages
                                    .removeAt(idx - _existingImages.length);
                              }
                            }),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodoCard(ThemeData theme, bool isDark) {
    final itemBg =
        isDark ? AppColors.bgDark : AppColors.bgLight;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_add_check, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rekomendasi To-Do Penulis',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Poin aktivitas praktis yang bisa disalin langsung pembaca ke checklist My To-Do mereka.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _todoItemCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Misal: Datang sebelum jam 07.00 pagi',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _addTodoItem(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  width: 46,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    onPressed: _addTodoItem,
                  ),
                ),
              ],
            ),
            if (_todoList.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._todoList.asMap().entries.map((entry) => Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: itemBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.circle,
                            size: 8, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            softWrap: true,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: AppColors.textMuted),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _todoList.removeAt(entry.key)),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _addTodoItem() {
    final text = _todoItemCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _todoList.add(text);
      _todoItemCtrl.clear();
    });
  }
}
