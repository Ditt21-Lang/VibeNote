import 'dart:io';

import 'package:path_provider/path_provider.dart';

class OfflinePhotoStorage {
  const OfflinePhotoStorage();

  Future<List<String>> persistPhotos({
    required String sessionId,
    required List<String> photos,
  }) async {
    final directory = await _photosDirectory();
    final persisted = <String>[];

    for (var index = 0; index < photos.length; index++) {
      final photo = photos[index];
      if (_isRemoteUrl(photo)) {
        persisted.add(photo);
        continue;
      }

      final source = File(photo);
      if (!await source.exists()) {
        persisted.add(photo);
        continue;
      }

      if (source.path.startsWith(directory.path)) {
        persisted.add(source.path);
        continue;
      }

      final extension = _extensionFor(source.path);
      final destination = File(
        '${directory.path}/${sessionId}_$index$extension',
      );
      await source.copy(destination.path);
      persisted.add(destination.path);
    }

    return persisted;
  }

  Future<Directory> _photosDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/vibenotes_offline_photos');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _extensionFor(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return '.jpg';
    }
    return path.substring(dotIndex);
  }

  bool _isRemoteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
