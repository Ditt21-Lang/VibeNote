import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/inference/inference_service.dart';
import '../../data/local/gallery_save_service.dart';

class FilterPreviewResult {
  const FilterPreviewResult({required this.photo, required this.filterName});

  final File photo;
  final String filterName;
}

class FilterPreviewView extends StatefulWidget {
  const FilterPreviewView({
    super.key,
    required this.photo,
    required this.detections,
    required this.vibe,
    this.primaryActionLabel = 'Gunakan Foto',
  });

  final File photo;
  final List<DetectionResult> detections;
  final VibeResult vibe;
  final String primaryActionLabel;

  @override
  State<FilterPreviewView> createState() => _FilterPreviewViewState();
}

class _FilterPreviewViewState extends State<FilterPreviewView> {
  static const _teal = Color(0xFF2EC4A9);
  static const _tealDark = Color(0xFF25A892);
  static const _tealLight = Color(0xFFE0F7F4);
  static const _bg = Color(0xFFF5F7FA);
  static const _textPrimary = Color(0xFF1A1A2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  late final List<SmartPhotoFilter> _filters;
  late SmartPhotoFilter _selectedFilter;

  File? _previewPhoto;
  final Map<String, File> _filteredCache = {};
  bool _isApplying = true;
  bool _isSavingToGallery = false;
  String? _errorMessage;

  final GallerySaveService _gallerySaveService = const GallerySaveService();

  @override
  void initState() {
    super.initState();
    _filters = SmartPhotoFilter.recommendFor(widget.detections);
    _selectedFilter = _filters.first;
    _applySelectedFilter();
  }

  Future<void> _applySelectedFilter() async {
    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    try {
      final cached = _filteredCache[_selectedFilter.id];
      if (cached != null && await cached.exists()) {
        if (!mounted) return;
        setState(() => _previewPhoto = cached);
        return;
      }

      final filtered = await _selectedFilter.applyTo(widget.photo);
      if (!mounted) return;
      _filteredCache[_selectedFilter.id] = filtered;
      setState(() => _previewPhoto = filtered);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Filter gagal diterapkan: $e');
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  void _selectFilter(SmartPhotoFilter filter) {
    if (_selectedFilter.id == filter.id || _isApplying) return;
    setState(() => _selectedFilter = filter);
    _applySelectedFilter();
  }

  void _usePhoto() {
    final photo = _previewPhoto ?? widget.photo;
    Navigator.of(
      context,
    ).pop(FilterPreviewResult(photo: photo, filterName: _selectedFilter.name));
  }

  Future<void> _saveToGallery() async {
    if (_isApplying || _isSavingToGallery) return;

    setState(() => _isSavingToGallery = true);

    try {
      await _gallerySaveService.saveImage(_previewPhoto ?? widget.photo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.photo_library_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Foto tersimpan ke galeri.'),
            ],
          ),
          backgroundColor: _teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan ke galeri: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingToGallery = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final objects = InferenceService.filterRelevantObjects(widget.detections);

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _buildPhotoPreview(),
                const SizedBox(height: 14),
                _buildAutoFilterCard(objects),
                const SizedBox(height: 12),
                _buildFilterRecommendations(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildError(),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_teal, _tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Otomatis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Pilih vibe terbaik untuk fotomu',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    final image = _previewPhoto ?? widget.photo;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              image,
              fit: BoxFit.cover,
              key: ValueKey('${image.path}-${_selectedFilter.id}'),
            ),
            if (_isApplying)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _selectedFilter.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoFilterCard(List<String> objects) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: _teal, size: 18),
              const SizedBox(width: 8),
              Expanded(child: _label('Filter otomatis dipilih')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter.reason,
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
          if (objects.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: objects
                  .map(
                    (object) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _tealLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        object,
                        style: const TextStyle(
                          color: _tealDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRecommendations() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Rekomendasi Filter'),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = filter.id == _selectedFilter.id;
                return GestureDetector(
                  onTap: () => _selectFilter(filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 132,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? _tealLight : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? _teal : _border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: filter.accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            filter.icon,
                            size: 18,
                            color: filter.accent,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          filter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          filter.shortLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: (_isApplying || _isSavingToGallery)
                    ? null
                    : _saveToGallery,
                icon: _isSavingToGallery
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Simpan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: const BorderSide(color: _teal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isApplying ? null : _usePhoto,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(widget.primaryActionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _teal.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

enum SmartFilterKind { original, focusPop, warmStudy, mutedFocus, cleanDesk }

class SmartPhotoFilter {
  const SmartPhotoFilter({
    required this.id,
    required this.name,
    required this.shortLabel,
    required this.reason,
    required this.kind,
    required this.icon,
    required this.accent,
  });

  final String id;
  final String name;
  final String shortLabel;
  final String reason;
  final SmartFilterKind kind;
  final IconData icon;
  final Color accent;

  static List<SmartPhotoFilter> recommendFor(List<DetectionResult> detections) {
    final labels = detections.map((d) => d.label.toLowerCase()).toSet();
    final hasFocusTool = labels.any(
      (label) =>
          label == 'laptop' ||
          label == 'book' ||
          label == 'keyboard' ||
          label == 'mouse',
    );
    final hasCup = labels.contains('cup');
    final hasPhone = labels.contains('cell phone');

    final all = <SmartPhotoFilter>[
      const SmartPhotoFilter(
        id: 'focus-pop',
        name: 'Focus Pop',
        shortLabel: 'Tajam dan terang',
        reason:
            'Objek pendukung aktivitas terdeteksi, jadi foto dibuat lebih kontras agar detail catatan dan perangkat terlihat jelas.',
        kind: SmartFilterKind.focusPop,
        icon: Icons.center_focus_strong_rounded,
        accent: Color(0xFF2563EB),
      ),
      const SmartPhotoFilter(
        id: 'warm-study',
        name: 'Warm Moment',
        shortLabel: 'Hangat dan nyaman',
        reason:
            'Cocok untuk suasana kegiatan santai, terutama saat ada minuman atau area terlihat redup.',
        kind: SmartFilterKind.warmStudy,
        icon: Icons.wb_sunny_rounded,
        accent: Color(0xFFF59E0B),
      ),
      const SmartPhotoFilter(
        id: 'muted-focus',
        name: 'Muted Focus',
        shortLabel: 'Minim distraksi',
        reason:
            'Warna dibuat lebih tenang supaya foto terasa rapi dan tidak terlalu ramai.',
        kind: SmartFilterKind.mutedFocus,
        icon: Icons.visibility_off_outlined,
        accent: Color(0xFF7C3AED),
      ),
      const SmartPhotoFilter(
        id: 'clean-desk',
        name: 'Clean Desk',
        shortLabel: 'Bersih dan natural',
        reason:
            'Pencahayaan diseimbangkan agar detail meja tetap natural untuk logbook.',
        kind: SmartFilterKind.cleanDesk,
        icon: Icons.auto_fix_high_rounded,
        accent: Color(0xFF10B981),
      ),
      const SmartPhotoFilter(
        id: 'original',
        name: 'Original',
        shortLabel: 'Tanpa filter',
        reason: 'Gunakan tampilan asli foto tanpa penyesuaian warna.',
        kind: SmartFilterKind.original,
        icon: Icons.image_outlined,
        accent: Color(0xFF64748B),
      ),
    ];

    final preferredId = hasPhone
        ? 'muted-focus'
        : hasCup
        ? 'warm-study'
        : hasFocusTool
        ? 'focus-pop'
        : 'clean-desk';

    final preferred = all.firstWhere((filter) => filter.id == preferredId);
    return [preferred, ...all.where((filter) => filter.id != preferred.id)];
  }

  Future<File> applyTo(File source) async {
    if (kind == SmartFilterKind.original) return source;

    final safeId = id.replaceAll(RegExp('[^a-z0-9-]'), '');
    final outputPath =
        '${Directory.systemTemp.path}/vibenotes_${DateTime.now().microsecondsSinceEpoch}_$safeId.jpg';

    return compute(_applySmartFilterInIsolate, {
      'sourcePath': source.path,
      'outputPath': outputPath,
      'kindIndex': kind.index,
    });
  }
}

File _applySmartFilterInIsolate(Map<String, Object?> args) {
  final sourcePath = args['sourcePath']! as String;
  final outputPath = args['outputPath']! as String;
  final kind = SmartFilterKind.values[args['kindIndex']! as int];

  final bytes = File(sourcePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception('Foto tidak bisa dibaca.');
  }

  final base = _resizeForFilter(decoded);
  final filtered = switch (kind) {
    SmartFilterKind.focusPop => img.adjustColor(
      base,
      brightness: 1.05,
      contrast: 1.16,
      saturation: 1.1,
    ),
    SmartFilterKind.warmStudy => img.sepia(
      img.adjustColor(base, brightness: 1.04, contrast: 1.06, saturation: 1.04),
      amount: 0.28,
    ),
    SmartFilterKind.mutedFocus => img.adjustColor(
      base,
      brightness: 1.02,
      contrast: 1.04,
      saturation: 0.7,
    ),
    SmartFilterKind.cleanDesk => img.adjustColor(
      base,
      brightness: 1.07,
      contrast: 1.08,
      saturation: 0.96,
    ),
    SmartFilterKind.original => base,
  };

  final output = File(outputPath);
  output.writeAsBytesSync(img.encodeJpg(filtered, quality: 88));
  return output;
}

img.Image _resizeForFilter(img.Image source) {
  const maxSide = 1600;
  final longestSide = source.width > source.height
      ? source.width
      : source.height;
  if (longestSide <= maxSide) {
    return img.Image.from(source);
  }

  final scale = maxSide / longestSide;
  return img.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: img.Interpolation.linear,
  );
}
