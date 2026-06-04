import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName =
      'durjpvl3t';

  static const String uploadPreset =
      'vibenotes_img';

  Future<String?> uploadPhoto(
    File imageFile,
  ) async {
    try {
      final request =
          http.MultipartRequest(
            'POST',
            Uri.parse(
              'https://api.cloudinary.com/v1_1/durjpvl3t/image/upload',
            ),
          );

      request.fields['upload_preset'] =
          uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      final response =
          await request.send();

      if (response.statusCode == 200) {
        final responseData =
            await response.stream
                .bytesToString();

        final jsonData =
            jsonDecode(responseData);

        final imageUrl =
            jsonData['secure_url'];

        debugPrint(
          'UPLOAD SUCCESS: $imageUrl',
        );

        return imageUrl;
      }

      debugPrint(
        'UPLOAD FAILED: ${response.statusCode}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'Cloudinary upload error: $e',
      );

      return null;
    }
  }

  Future<List<String>> uploadPhotos(
    List<File> imageFiles,
  ) async {
    final List<String> urls = [];

    for (final file in imageFiles) {
      final url =
          await uploadPhoto(file);

      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }
}