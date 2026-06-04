import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import '../../core/inference/inference_service.dart';
import '../../data/models/study_session.dart';
import '../../data/remote/study_log_repository.dart';
import '../detection/camera_view.dart';
import '../detection/filter_preview_view.dart';

class CreateLogbookView extends StatefulWidget {
  const CreateLogbookView({super.key, this.initialSession});

  final StudySession? initialSession;

  @override
  State<CreateLogbookView> createState() => _CreateLogbookViewState();
}

class _CreateLogbookViewState extends State<CreateLogbookView>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _objectController = TextEditingController();

  // ── State ─────────────────────────────────────────────────────
  String _selectedType = 'Kuliah';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(
    hour: (TimeOfDay.now().hour + 1) % 24,
    minute: TimeOfDay.now().minute,
  );
  final List<String> _photoPaths = [];
  final List<String> _detectedObjects = [];
  VibeAnalysis _selectedVibe = const VibeAnalysis(
    label: 'Belum dianalisis',
    description: 'Tambahkan foto agar vibe kegiatan terdeteksi otomatis.',
  );
  bool _isSaving = false;
  bool _isPickingGallery = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final ImagePicker _imagePicker = ImagePicker();
  final InferenceService _inferenceService = InferenceService();

  // ── Design tokens (matching VibeNotes teal theme) ─────────────
  static const _teal = Color(0xFF2EC4A9);
  static const _tealDark = Color(0xFF25A892);
  static const _tealLight = Color(0xFFE0F7F4);
  static const _bg = Color(0xFFF5F7FA);
  static const _cardBg = Colors.white;
  static const _textPrimary = Color(0xFF1A1A2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);

  final List<String> _sessionTypes = [
    'Kuliah',
    'Organisasi',
    'Pribadi',
    'Lainnya',
  ];

  final Map<String, Color> _typeColors = {
    'Kuliah': const Color(0xFF3B82F6),
    'Organisasi': const Color(0xFF10B981),
    'Pribadi': const Color(0xFFF59E0B),
    'Lainnya': const Color(0xFF8B5CF6),
  };

  @override
  void initState() {
    super.initState();
    final initialSession = widget.initialSession;
    if (initialSession != null) {
      _titleController.text = initialSession.title;
      _descController.text = initialSession.description;
      _selectedType = initialSession.type;
      _selectedDate = initialSession.date;
      _startTime = _readTime(initialSession.startTime);
      _endTime = _readTime(initialSession.endTime);
      _photoPaths.addAll(initialSession.photos);
      _detectedObjects.addAll(initialSession.detectedObjects);
      _selectedVibe = initialSession.vibe;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _objectController.dispose();
    _animController.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _calcDuration() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final diff = endMinutes - startMinutes;
    return diff > 0 ? diff : 0;
  }

  TimeOfDay _readTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return TimeOfDay.now();

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return TimeOfDay.now();

    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  // ── Pickers ───────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths.removeAt(index);
      if (_photoPaths.isEmpty) {
        _selectedVibe = const VibeAnalysis(
          label: 'Belum dianalisis',
          description: 'Tambahkan foto agar vibe kegiatan terdeteksi otomatis.',
        );
      }
    });
  }

  void _applyVibe(VibeResult vibe) {
    _selectedVibe = VibeAnalysis(
      label: vibe.label,
      description: vibe.description,
    );
  }

  Future<void> _openCamera() async {
    final result = await Navigator.of(context).push<CameraCaptureResult>(
      MaterialPageRoute(builder: (_) => const CameraView()),
    );

    if (result == null) return;

    setState(() {
      if (_photoPaths.length < 5) {
        _photoPaths.add(result.photo.path);
      }

      for (final object in result.relevantObjects) {
        if (!_detectedObjects.contains(object)) {
          _detectedObjects.add(object);
        }
      }

      _applyVibe(result.vibe);
    });
  }

  Future<void> _openGallery() async {
    if (_isPickingGallery || _photoPaths.length >= 5) return;

    setState(() => _isPickingGallery = true);

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (picked == null) return;

      if (!_inferenceService.isInitialized) {
        await _inferenceService.initialize();
      }

      final photo = File(picked.path);
      final bytes = await photo.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Foto galeri tidak bisa dibaca.');
      }

      final detections = await _inferenceService.runInferenceOnImage(decoded);
      final vibe = InferenceService.analyzeVibe(detections);

      if (!mounted) return;
      final filtered = await Navigator.of(context).push<FilterPreviewResult>(
        MaterialPageRoute(
          builder: (_) => FilterPreviewView(
            photo: photo,
            detections: detections,
            vibe: vibe,
          ),
        ),
      );

      if (filtered == null || !mounted) return;

      setState(() {
        if (_photoPaths.length < 5) {
          _photoPaths.add(filtered.photo.path);
        }

        for (final object in InferenceService.filterRelevantObjects(
          detections,
        )) {
          if (!_detectedObjects.contains(object)) {
            _detectedObjects.add(object);
          }
        }

        _applyVibe(vibe);
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Gagal mengambil foto galeri: $e');
      }
    } finally {
      if (mounted) setState(() => _isPickingGallery = false);
    }
  }

  // ── Detected objects chips ────────────────────────────────────
  void _addObject() {
    final text = _objectController.text.trim();
    if (text.isNotEmpty && !_detectedObjects.contains(text)) {
      setState(() {
        _detectedObjects.add(text);
        _objectController.clear();
      });
    }
  }

  void _removeObject(String obj) {
    setState(() => _detectedObjects.remove(obj));
  }

  // ── Save ──────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final session = StudySession(
        id: widget.initialSession?.id ?? ObjectId(),
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        date: _selectedDate,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        durationMinutes: _calcDuration(),
        photos: List<String>.from(_photoPaths),
        detectedObjects: _detectedObjects,
        vibe: _selectedVibe,
        createdAt: widget.initialSession?.createdAt ?? DateTime.now(),
      );

      await StudyLogRepository().save(session);

      if (mounted) {
        Navigator.of(context).pop(session);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Gagal menyimpan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _buildTypeSelector(),
                    const SizedBox(height: 12),
                    _buildTitleField(),
                    const SizedBox(height: 12),
                    _buildDateTimeCard(),
                    const SizedBox(height: 12),
                    _buildDescriptionField(),
                    const SizedBox(height: 12),
                    _buildPhotosSection(),
                    const SizedBox(height: 12),
                    _buildObjectsSection(),
                    const SizedBox(height: 12),
                    _buildVibeSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Header ────────────────────────────────────────────────────
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialSession == null
                          ? 'Buat Logbook'
                          : 'Edit Logbook',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      widget.initialSession == null
                          ? 'Catat kegiatanmu'
                          : 'Perbarui catatan sesi',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Type selector ─────────────────────────────────────────────
  Widget _buildTypeSelector() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Tipe Sesi'),
          const SizedBox(height: 10),
          Row(
            children: _sessionTypes.map((type) {
              final selected = _selectedType == type;
              final color = _typeColors[type]!;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color : color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      type,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white : color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Title field ───────────────────────────────────────────────
  Widget _buildTitleField() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Judul Sesi'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration('Contoh: Rapat proyek PCD'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
          ),
        ],
      ),
    );
  }

  // ── Date & time card ──────────────────────────────────────────
  Widget _buildDateTimeCard() {
    final duration = _calcDuration();
    final durationText = duration > 0
        ? '${duration ~/ 60 > 0 ? '${duration ~/ 60}j ' : ''}${duration % 60 > 0 ? '${duration % 60}m' : ''}'
        : '--';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Jadwal'),
          const SizedBox(height: 10),

          // Date
          _pickerRow(
            icon: Icons.calendar_today_outlined,
            label: _formatDate(_selectedDate),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),

          // Time row
          Row(
            children: [
              Expanded(
                child: _pickerRow(
                  icon: Icons.access_time_outlined,
                  label: _formatTime(_startTime),
                  hint: 'Mulai',
                  onTap: _pickStartTime,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: _textSecondary,
                ),
              ),
              Expanded(
                child: _pickerRow(
                  icon: Icons.access_time_filled_outlined,
                  label: _formatTime(_endTime),
                  hint: 'Selesai',
                  onTap: _pickEndTime,
                ),
              ),
            ],
          ),

          if (duration > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _tealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: _teal, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Durasi: $durationText',
                    style: const TextStyle(
                      color: _teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Description ───────────────────────────────────────────────
  Widget _buildDescriptionField() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Deskripsi'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descController,
            maxLines: 3,
            style: const TextStyle(color: _textPrimary, fontSize: 14),
            decoration: _inputDecoration('Ceritakan kegiatanmu...'),
          ),
        ],
      ),
    );
  }

  // ── Photos section ────────────────────────────────────────────
  Widget _buildPhotosSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _label('Foto Sesi'),
              const Spacer(),
              Text(
                '${_photoPaths.length}/5',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (_photoPaths.length < 5)
                  _photoSourceTile(
                    icon: Icons.camera_alt_outlined,
                    label: 'Kamera',
                    onTap: _openCamera,
                  ),
                if (_photoPaths.length < 5)
                  _photoSourceTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeri',
                    onTap: _openGallery,
                    isLoading: _isPickingGallery,
                  ),

                // Photo thumbnails
                ..._photoPaths.asMap().entries.map((entry) {
                  final index = entry.key;
                  final photo = entry.value;
                  return Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          image: DecorationImage(
                            image: _imageProvider(photo),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoSourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 90,
        height: 90,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _tealLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _teal.withValues(alpha: 0.4),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: _teal, strokeWidth: 2),
              )
            else
              Icon(icon, color: _teal, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _teal,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _imageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  Widget _buildVibeSection() {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: _teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Vibe Analysis'),
                const SizedBox(height: 5),
                Text(
                  _selectedVibe.label,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_selectedVibe.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _selectedVibe.description,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detected objects ──────────────────────────────────────────
  Widget _buildObjectsSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Objek Terdeteksi'),
          const SizedBox(height: 4),
          const Text(
            'Tambah manual atau gunakan deteksi kamera',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),

          // Input row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _objectController,
                  style: const TextStyle(color: _textPrimary, fontSize: 14),
                  decoration: _inputDecoration('Contoh: Laptop, Buku'),
                  onFieldSubmitted: (_) => _addObject(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addObject,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),

          if (_detectedObjects.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _detectedObjects
                  .map(
                    (obj) => Chip(
                      label: Text(
                        obj,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _teal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: _tealLight,
                      deleteIcon: const Icon(
                        Icons.close,
                        size: 14,
                        color: _teal,
                      ),
                      onDeleted: () => _removeObject(obj),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: _teal, width: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom save bar ───────────────────────────────────────────
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
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _teal.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.initialSession == null
                      ? 'Simpan Logbook'
                      : 'Update Logbook',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
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
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _pickerRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? hint,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _teal),
            const SizedBox(width: 6),
            if (hint != null) ...[
              Text(
                hint,
                style: const TextStyle(color: _textSecondary, fontSize: 11),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
