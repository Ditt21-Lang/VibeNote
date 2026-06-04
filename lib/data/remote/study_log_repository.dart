import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../local/offline_photo_storage.dart';
import '../local/study_log_local_repository.dart';
import '../models/study_session.dart';
import 'cloudinary_service.dart';
import 'study_log_remote_repository.dart';

class StudyLogRepository {
  StudyLogRepository({
    StudyLogLocalRepository? localRepository,
    StudyLogRemoteRepository? remoteRepository,
    CloudinaryService? cloudinaryService,
    OfflinePhotoStorage? photoStorage,
  }) : _local = localRepository ?? StudyLogLocalRepository(),
       _remote = remoteRepository ?? const StudyLogRemoteRepository(),
       _cloudinary = cloudinaryService ?? CloudinaryService(),
       _photoStorage = photoStorage ?? const OfflinePhotoStorage();

  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static bool _isSyncing = false;

  final StudyLogLocalRepository _local;
  final StudyLogRemoteRepository _remote;
  final CloudinaryService _cloudinary;
  final OfflinePhotoStorage _photoStorage;

  static void startAutoSync() {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasNetwork = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (hasNetwork) {
        unawaited(StudyLogRepository().syncPending());
      }
    });
  }

  Future<void> save(StudySession session) async {
    final localPhotos = await _photoStorage.persistPhotos(
      sessionId: session.id.oid,
      photos: session.photos,
    );
    await _local.savePending(session.copyWith(photos: localPhotos));
    unawaited(syncPending());
  }

  Future<void> delete(StudySession session) async {
    await _local.deletePending(session.id.oid);
    unawaited(syncPending());
  }

  Future<List<StudySession>> fetchStudyLogs() async {
    final hasNetwork = await _hasNetwork();
    if (!hasNetwork) {
      return _local.sessions();
    }

    await syncPending();

    try {
      final remoteSessions = await _remote.fetchStudyLogs();
      final deletedIds = await _local.deletedIds();
      for (final session in remoteSessions) {
        if (deletedIds.contains(session.id.oid)) continue;
        await _local.upsertSynced(session);
      }
    } catch (e) {
      debugPrint('StudyLogRepository fetch remote skipped: $e');
    }

    return _local.sessions();
  }

  Future<void> syncPending() async {
    if (_isSyncing) return;
    if (!await _hasNetwork()) return;

    _isSyncing = true;
    try {
      final pendingEntries = await _local.pendingEntries();
      for (final entry in pendingEntries) {
        try {
          final syncedSession = await _prepareForRemote(entry.session);
          await _remote.save(syncedSession);
          await _local.markSynced(syncedSession);
        } catch (e) {
          debugPrint(
            'StudyLogRepository sync skipped for ${entry.session.id.oid}: $e',
          );
        }
      }

      final deletedIds = await _local.deletedIds();
      for (final sessionId in deletedIds) {
        try {
          await _remote.delete(sessionId);
          await _local.clearDeleted(sessionId);
        } catch (e) {
          debugPrint('StudyLogRepository delete sync skipped $sessionId: $e');
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<StudySession> _prepareForRemote(StudySession session) async {
    final remotePhotos = <String>[];

    for (final photo in session.photos) {
      if (_isRemoteUrl(photo)) {
        remotePhotos.add(photo);
        continue;
      }

      final file = File(photo);
      if (!await file.exists()) {
        throw StateError('File foto offline tidak ditemukan: $photo');
      }

      final url = await _cloudinary.uploadPhoto(file);
      if (url == null) {
        throw StateError('Upload foto gagal: $photo');
      }

      remotePhotos.add(url);
    }

    return session.copyWith(photos: remotePhotos);
  }

  bool _isRemoteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<bool> _hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      debugPrint('StudyLogRepository connectivity check skipped: $e');
      return true;
    }
  }
}
