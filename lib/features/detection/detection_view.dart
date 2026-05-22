import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../core/camera/camera_service.dart';
import '../../core/inference/inference_service.dart';
import '../../core/overlay/detection_overlay.dart';

class DetectionView extends StatefulWidget {
  const DetectionView({super.key});

  @override
  State<DetectionView> createState() => _DetectionViewState();
}

class _DetectionViewState extends State<DetectionView>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final InferenceService _inferenceService = InferenceService();

  List<DetectionResult> _detections = [];
  VibeResult _vibe = const VibeResult(
    label: 'Memulai...',
    description: 'Menginisialisasi kamera dan model.',
  );

  bool _isInitializing = true;
  bool _isProcessing = false;
  String? _errorMessage;

  DateTime _lastInference = DateTime.now();
  static const _inferenceInterval = Duration(milliseconds: 800);

  static const _teal = Color(0xFF2EC4A9);
  static const _tealLight = Color(0xFFE0F7F4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isInitializing = true);
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

    _cameraService.controller?.startImageStream(_onCameraFrame);
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _onCameraFrame(CameraImage cameraImage) async {
    final now = DateTime.now();
    if (now.difference(_lastInference) < _inferenceInterval) return;
    if (_isProcessing) return;
    _lastInference = now;
    _isProcessing = true;

    if (_detections.isEmpty) {
      debugPrint('=== planes: ${cameraImage.planes.length}');
      debugPrint('=== format: ${cameraImage.format.raw}');
    }
    try {
      final image = _convertYUV420toRGB(cameraImage);
      if (image == null) return;

      final results = await _inferenceService.runInferenceOnImage(image);
      final vibe = InferenceService.analyzeVibe(results);

      if (mounted) {
        setState(() {
          _detections = results;
          _vibe = vibe;
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  // ── Fix konversi YUV420 → RGB ─────────────────────────────────────────────
  img.Image? _convertYUV420toRGB(CameraImage cameraImage) {
    try {

      if (cameraImage.format.raw == 256) {
        final bytes = cameraImage.planes[0].bytes;
        final decoded = img.decodeJpg(bytes);
        return decoded;
      }
      
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      final image = img.Image(width: width, height: height);

      final yBytes = cameraImage.planes[0].bytes;
      final yRowStride = cameraImage.planes[0].bytesPerRow;

      // NV21: hanya 1 plane UV (interleaved V, U, V, U, ...)
      // NV12: hanya 1 plane UV (interleaved U, V, U, V, ...)
      // Cek jumlah planes
      final bool isNV = cameraImage.planes.length == 2;
      final uvBytes = isNV
          ? cameraImage.planes[1].bytes
          : null;
      final uBytes = !isNV ? cameraImage.planes[1].bytes : null;
      final vBytes = !isNV ? cameraImage.planes[2].bytes : null;
      final uvRowStride = cameraImage.planes[1].bytesPerRow;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yRowStride + x;
          if (yIndex >= yBytes.length) continue;

          final int yVal = yBytes[yIndex] & 0xFF;
          int uVal, vVal;

          if (isNV) {
            // NV21: V dulu baru U, NV12: U dulu baru V
            // Tecno biasanya NV21
            final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * 2;
            if (uvIndex + 1 >= uvBytes!.length) continue;
            vVal = (uvBytes[uvIndex] & 0xFF) - 128;     // NV21: V dulu
            uVal = (uvBytes[uvIndex + 1] & 0xFF) - 128; // NV21: U belakang
          } else {
            final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2);
            if (uvIndex >= uBytes!.length || uvIndex >= vBytes!.length) continue;
            uVal = (uBytes[uvIndex] & 0xFF) - 128;
            vVal = (vBytes[uvIndex] & 0xFF) - 128;
          }

          final r = (yVal + 1.370705 * vVal).clamp(0, 255).toInt();
          final g = (yVal - 0.698001 * vVal - 0.337633 * uVal).clamp(0, 255).toInt();
          final b = (yVal + 1.732446 * uVal).clamp(0, 255).toInt();

          image.setPixelRgb(x, y, r, g, b);
        }
      }
      return image;
    } catch (e) {
      debugPrint('YUV conversion error: $e');
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.controller?.stopImageStream();
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.controller?.stopImageStream();
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
          _buildCameraPreview(),
          if (!_isInitializing && _detections.isNotEmpty) _buildOverlay(),
          _buildTopBar(),
          if (!_isInitializing) _buildVibeCard(),
          if (_isInitializing)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF2EC4A9)),
            ),
          if (_errorMessage != null) _buildError(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraService.controller == null || !_cameraService.isInitialized) {
      return const SizedBox.shrink();
    }
    return SizedBox.expand(
      child: CameraPreview(_cameraService.controller!),
    );
  }

  Widget _buildOverlay() {
    // Ambil preview size dari controller
    final previewSize = _cameraService.controller?.value.previewSize;
    if (previewSize == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // previewSize: width = sensor width, height = sensor height
        // Di Flutter, preview biasanya rotasi 90° jadi width/height dibalik
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: DetectionOverlayPainter(
            detections: _detections,
            // Perhatikan: previewSize.width = tinggi sensor, previewSize.height = lebar sensor
            imageWidth: previewSize.height,
            imageHeight: previewSize.width,
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFF2EC4A9),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Deteksi Real-time',
                    style: TextStyle(
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
                color: Colors.black38,
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

  Widget _buildVibeCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _teal.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _vibe.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_isProcessing)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Color(0xFF2EC4A9), strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _vibe.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_detections.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: InferenceService.filterRelevantObjects(_detections)
                        .map(
                          (label) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _tealLight.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: _teal.withOpacity(0.4)),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xFF2EC4A9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _initialize,
              child: const Text('Coba Lagi',
                  style: TextStyle(color: Color(0xFF2EC4A9))),
            ),
          ],
        ),
      ),
    );
  }
}