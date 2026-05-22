import 'dart:io';
import 'package:flutter/foundation.dart';

/// Placeholder untuk Cloudinary upload service.
/// Ganti implementasi di dalam [uploadPhoto] saat Cloudinary sudah dikonfigurasi.
class CloudinaryService {
  /// Upload foto ke Cloudinary dan return URL-nya.
  /// Saat ini return dummy URL sebagai placeholder.
  Future<String?> uploadPhoto(File imageFile) async {
    try {
      // TODO: Uncomment dan implementasi saat Cloudinary sudah siap
      //
      // final request = http.MultipartRequest(
      //   'POST',
      //   Uri.parse('https://api.cloudinary.com/v1_1/YOUR_CLOUD_NAME/image/upload'),
      // );
      // request.fields['upload_preset'] = 'YOUR_UPLOAD_PRESET';
      // request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      //
      // final response = await request.send();
      // if (response.statusCode == 200) {
      //   final responseData = await response.stream.bytesToString();
      //   final json = jsonDecode(responseData);
      //   return json['secure_url'] as String;
      // }
      // return null;

      // PLACEHOLDER: Simulasi delay upload dan return dummy URL
      debugPrint(
        'CloudinaryService: [PLACEHOLDER] Uploading ${imageFile.path}',
      );
      await Future.delayed(const Duration(milliseconds: 800));
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'https://placeholder.cloudinary.com/vibenotes/photo_$timestamp.jpg';
    } catch (e) {
      debugPrint('CloudinaryService upload error: $e');
      return null;
    }
  }

  /// Upload multiple foto sekaligus, return list URL
  Future<List<String>> uploadPhotos(List<File> imageFiles) async {
    final List<String> urls = [];
    for (final file in imageFiles) {
      final url = await uploadPhoto(file);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
