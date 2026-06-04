import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );

      await _controller!.initialize();
      await _configureCamera();
      _isInitialized = true;
    } catch (e) {
      debugPrint('CameraService init error: $e');
      _isInitialized = false;
    }
  }

  Future<File?> capturePhoto() async {
    if (_controller == null || !_isInitialized) return null;

    try {
      final XFile file = await _controller!.takePicture();
      return File(file.path);
    } catch (e) {
      debugPrint('CameraService capture error: $e');
      return null;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    final currentLensDirection = _controller?.description.lensDirection;
    final newCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection != currentLensDirection,
      orElse: () => _cameras.first,
    );

    await _controller?.dispose();
    _controller = CameraController(
      newCamera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    await _controller!.initialize();
    await _configureCamera();
  }

  Future<void> _configureCamera() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('CameraService config warning: $e');
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  Future<void> startImageStream(Function(CameraImage image) onImage) async {
    if (_controller == null) return;

    if (_controller!.value.isStreamingImages) return;

    await _controller!.startImageStream(onImage);
  }

  Future<void> stopImageStream() async {
    if (_controller == null) return;

    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }
}
