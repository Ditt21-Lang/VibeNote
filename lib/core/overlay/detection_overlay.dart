import 'package:flutter/material.dart';
import '../inference/inference_service.dart';

class DetectionOverlayPainter extends CustomPainter {
  DetectionOverlayPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<DetectionResult> detections;
  final double imageWidth;
  final double imageHeight;

  // Warna per label
  static const _labelColors = {
    'laptop': Color(0xFF2EC4A9),
    'book': Color(0xFF3B82F6),
    'cup': Color(0xFFF59E0B),
    'cell phone': Color(0xFFEF4444),
    'keyboard': Color(0xFF8B5CF6),
    'mouse': Color(0xFF10B981),
    'person': Color(0xFFEC4899),
    'bottle': Color(0xFF06B6D4),
  };

  static const _defaultColor = Color(0xFF94A3B8);

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      final color =
          _labelColors[detection.label.toLowerCase()] ?? _defaultColor;

      // Convert normalized rect ke pixel
      final top = detection.top * size.height;
      final left = detection.left * size.width;
      final bottom = detection.bottom * size.height;
      final right = detection.right * size.width;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      // Draw bounding box
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        boxPaint,
      );

      // Corner accents
      _drawCorners(canvas, rect, color);

      // Label background
      final label =
          '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelBgRect = Rect.fromLTWH(
        left,
        top - 22,
        textPainter.width + 10,
        20,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelBgRect, const Radius.circular(4)),
        Paint()..color = color,
      );

      textPainter.paint(canvas, Offset(left + 5, top - 20));
    }
  }

  void _drawCorners(Canvas canvas, Rect rect, Color color) {
    const cornerLength = 12.0;
    const cornerWidth = 3.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerWidth
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerLength, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLength), paint);

    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLength, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLength), paint);

    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerLength, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerLength), paint);
  }

  @override
  bool shouldRepaint(DetectionOverlayPainter oldDelegate) =>
      oldDelegate.detections != detections;
}