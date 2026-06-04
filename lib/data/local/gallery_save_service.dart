import 'dart:io';

import 'package:gal/gal.dart';

class GallerySaveService {
  const GallerySaveService({this.albumName = 'VibeNotes'});

  final String albumName;

  Future<void> saveImage(File photo) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      await Gal.requestAccess(toAlbum: true);
    }

    await Gal.putImage(photo.path, album: albumName);
  }
}
