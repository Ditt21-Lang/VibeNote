import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// ── Detection result ──────────────────────────────────────────────────────────
class DetectionResult {
  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.rect,
  });

  final String label;
  final double confidence;
  final List<double> rect; // [top, left, bottom, right] normalized 0..1

  double get top => rect[0];
  double get left => rect[1];
  double get bottom => rect[2];
  double get right => rect[3];

  @override
  String toString() =>
      'DetectionResult(label: $label, confidence: ${confidence.toStringAsFixed(2)})';
}

// ── Vibe result ───────────────────────────────────────────────────────────────
class VibeResult {
  const VibeResult({required this.label, required this.description});
  final String label;
  final String description;
}

// ── Main service ──────────────────────────────────────────────────────────────
class InferenceService {
  static const String _modelPath = 'assets/detect.tflite';
  static const String _labelsPath = 'assets/labelmap.txt';
  static const int _inputSize = 300;
  static const double _confidenceThreshold = 0.5;
  static const int _maxResults = 10;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  bool _isRunning = false;

  bool get isInitialized => _isInitialized;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: InterpreterOptions()..threads = 2,
      );

      // PENTING: load SEMUA baris termasuk '???' supaya index match dengan model
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .toList(); // JANGAN filter di sini

      _isInitialized = true;
      debugPrint('InferenceService: initialized, labels=${_labels.length}');
      debugPrint(
        'InferenceService: label[0]=${_labels.isNotEmpty ? _labels[0] : "empty"}',
      );
    } catch (e) {
      debugPrint('InferenceService init error: $e');
      _isInitialized = false;
    }
  }

  // ── Run inference on img.Image ────────────────────────────────────────────
  Future<List<DetectionResult>> runInferenceOnImage(img.Image image) async {
    if (!_isInitialized || _interpreter == null) return [];
    if (_isRunning) return [];

    _isRunning = true;
    try {
      return _detectObjects(image);
    } catch (e) {
      debugPrint('InferenceService runInference error: $e');
      return [];
    } finally {
      _isRunning = false;
    }
  }

  // ── Core detection ────────────────────────────────────────────────────────
  List<DetectionResult> _detectObjects(img.Image image) {
    // Resize ke 300x300
    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Input tensor [1, 300, 300, 3] — Uint8
    final input = [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        }),
      ),
    ];

    // Output tensors MobileNet SSD
    final outputLocations = List.generate(
      1,
      (_) => List.generate(_maxResults, (_) => List.filled(4, 0.0)),
    );
    final outputClasses = List.generate(
      1,
      (_) => List.filled(_maxResults, 0.0),
    );
    final outputScores = List.generate(1, (_) => List.filled(_maxResults, 0.0));
    final numDetections = List.filled(1, 0.0);

    final outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };

    _interpreter!.runForMultipleInputs([input], outputs);

    final count = numDetections[0].toInt().clamp(0, _maxResults);
    debugPrint('InferenceService: raw count=$count');

    final List<DetectionResult> results = [];

    for (int i = 0; i < count; i++) {
      final score = outputScores[0][i];
      final classIndex = outputClasses[0][i].toInt();
      final labelIndex = classIndex + 1;

      debugPrint(
        'InferenceService: [$i] classIndex=$classIndex labelIndex=$labelIndex score=${score.toStringAsFixed(3)}',
      );

      if (score < _confidenceThreshold) continue;
      if (labelIndex < 0 || labelIndex >= _labels.length) continue;

      final label = _labels[labelIndex];

      // Skip label kosong atau '???'
      if (label.isEmpty || label == '???') continue;

      results.add(
        DetectionResult(
          label: label,
          confidence: score,
          rect: List<double>.from(outputLocations[0][i]),
        ),
      );
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    debugPrint('InferenceService: filtered results=${results.length}');
    for (final r in results) {
      debugPrint(
        '  → ${r.label} (${(r.confidence * 100).toStringAsFixed(1)}%)',
      );
    }

    return results;
  }

  // ── Vibe analysis ─────────────────────────────────────────────────────────
  static VibeResult analyzeVibe(List<DetectionResult> detections) {
    final labels = detections.map((d) => d.label.toLowerCase()).toSet();

    final hasLaptop = labels.contains('laptop');
    final hasBook = labels.contains('book');
    final hasCup = labels.contains('cup');
    final hasPhone = labels.contains('cell phone');
    final hasKeyboard = labels.contains('keyboard');
    final hasMouse = labels.contains('mouse');

    int focusScore = 0;
    int distractionScore = 0;

    if (hasLaptop) focusScore += 2;
    if (hasBook) focusScore += 3;
    if (hasKeyboard) focusScore += 2;
    if (hasMouse) focusScore += 1;
    if (hasCup) focusScore += 1;
    if (hasPhone) distractionScore += 3;

    if (focusScore >= 5) {
      return const VibeResult(
        label: 'Deep Focus 🎯',
        description:
            'Meja belajarmu lengkap! Kondisi sangat mendukung untuk belajar intensif.',
      );
    } else if (focusScore >= 3) {
      return const VibeResult(
        label: 'Fokus Belajar 📚',
        description: 'Suasana belajar yang baik. Tetap semangat!',
      );
    } else if (focusScore >= 1 && hasCup) {
      return const VibeResult(
        label: 'Santai Produktif ☕',
        description: 'Belajar sambil ngopi. Nikmati prosesnya!',
      );
    } else if (distractionScore >= 3) {
      return const VibeResult(
        label: 'Distraksi ⚠️',
        description: 'Jauhkan HP dulu, yuk fokus belajar!',
      );
    } else if (detections.isEmpty) {
      return const VibeResult(
        label: 'Belum Terdeteksi 🔍',
        description: 'Arahkan kamera ke meja belajarmu.',
      );
    } else {
      return const VibeResult(
        label: 'Siap Belajar 💡',
        description: 'Mulai sesi belajarmu sekarang!',
      );
    }
  }

  // ── Objek terdeteksi untuk logbook ───────────────────────────────────────
  static List<String> filterRelevantObjects(List<DetectionResult> detections) {
    return detections.map((d) => d.label).toSet().toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
