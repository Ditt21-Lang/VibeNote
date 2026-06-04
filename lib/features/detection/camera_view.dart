import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/camera/camera_service.dart';
import '../../core/inference/inference_service.dart';
import '../../core/overlay/detection_overlay.dart';

class CameraCaptureResult {
  const CameraCaptureResult({
    required this.photo,
    required this.detections,
    required this.vibe,
  });

  final File photo;
  final List<DetectionResult> detections;
  final VibeResult vibe;

  List<String> get relevantObjects =>
      InferenceService.filterRelevantObjects(detections);
}

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final InferenceService _inferenceService = InferenceService();

  File? _capturedPhoto;
  List<DetectionResult> _detections = [];
  VibeResult _vibe = const VibeResult(
    label: 'Siap Foto',
    description: 'Ambil foto dulu, nanti objeknya dianalisis setelah itu.',
  );

  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isProcessing = false;
  String? _errorMessage;
  int? _previewImageWidth;
  int? _previewImageHeight;

  static const _teal = Color(0xFF2EC4A9);
  static const _tealLight = Color(0xFFE0F7F4);

  bool get _isPreviewingPhoto => _capturedPhoto != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    await _inferenceService.initialize();
    await _cameraService.initialize();

    if (!_cameraService.isInitialized) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Tidak dapat mengakses kamera.';
          _isInitializing = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _captureAndDetect() async {
    if (_isCapturing || _isProcessing || !_cameraService.isInitialized) return;

    setState(() {
      _isCapturing = true;
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final photo = await _cameraService.capturePhoto();
      if (photo == null) {
        throw Exception('Foto gagal diambil.');
      }

      final bytes = await photo.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Foto tidak bisa dibaca.');
      }

      final results = await _inferenceService.runInferenceOnImage(decoded);
      final vibe = InferenceService.analyzeVibe(results);

      if (mounted) {
        setState(() {
          _capturedPhoto = photo;
          _detections = results;
          _vibe = vibe;
          _previewImageWidth = decoded.width;
          _previewImageHeight = decoded.height;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal memproses foto: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isProcessing = false;
        });
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedPhoto = null;
      _detections = [];
      _previewImageWidth = null;
      _previewImageHeight = null;
      _vibe = const VibeResult(
        label: 'Siap Foto',
        description: 'Ambil foto dulu, nanti objeknya dianalisis setelah itu.',
      );
      _errorMessage = null;
    });
  }

  void _usePhoto() {
    final photo = _capturedPhoto;
    if (photo == null) return;

    Navigator.of(context).pop(
      CameraCaptureResult(photo: photo, detections: _detections, vibe: _vibe),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed && !_isPreviewingPhoto) {
      _initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _inferenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isPreviewingPhoto) _buildPhotoPreview() else _buildCameraView(),
          _buildTopBar(),
          if (!_isInitializing && !_isPreviewingPhoto) _buildCameraControls(),
          if (!_isInitializing && _isPreviewingPhoto) _buildPreviewPanel(),
          if (_isInitializing)
            const Center(child: CircularProgressIndicator(color: _teal)),
          if (_isProcessing) _buildProcessingScrim(),
          if (_errorMessage != null) _buildError(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (_cameraService.controller == null || !_cameraService.isInitialized) {
      return const SizedBox.shrink();
    }

    return SizedBox.expand(child: CameraPreview(_cameraService.controller!));
  }

  Widget _buildPhotoPreview() {
    final photo = _capturedPhoto;
    final imageWidth = _previewImageWidth;
    final imageHeight = _previewImageHeight;
    if (photo == null || imageWidth == null || imageHeight == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: AspectRatio(
        aspectRatio: imageWidth / imageHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(photo, fit: BoxFit.contain),
            if (_detections.isNotEmpty)
              CustomPaint(
                painter: DetectionOverlayPainter(
                  detections: _detections,
                  imageWidth: imageWidth.toDouble(),
                  imageHeight: imageHeight.toDouble(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final title = _isPreviewingPhoto ? 'Preview Deteksi' : 'Camera View';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                if (_isPreviewingPhoto) {
                  _retakePhoto();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isPreviewingPhoto
                      ? Icons.arrow_back_ios_new
                      : Icons.close_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isPreviewingPhoto ? _teal : Colors.white70,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${_detections.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: GestureDetector(
            onTap: _captureAndDetect,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: _teal,
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final objects = InferenceService.filterRelevantObjects(_detections);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _teal.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _vibe.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '${_detections.length} objek',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _vibe.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (objects.isEmpty)
                  const Text(
                    'Belum ada objek logbook yang terdeteksi.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: objects
                        .map(
                          (label) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _tealLight.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _teal.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: _teal,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _retakePhoto,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Ulangi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _usePhoto,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Gunakan'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
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

  Widget _buildProcessingScrim() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _teal),
            SizedBox(height: 12),
            Text(
              'Menganalisis foto...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 42),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _isPreviewingPhoto ? _retakePhoto : _initialize,
                child: const Text('Coba Lagi', style: TextStyle(color: _teal)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
