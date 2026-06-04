import 'package:hive_flutter/hive_flutter.dart';

import '../models/study_session.dart';

class LocalStudyLogEntry {
  const LocalStudyLogEntry({
    required this.session,
    required this.isSynced,
    required this.updatedAt,
  });

  final StudySession session;
  final bool isSynced;
  final DateTime updatedAt;

  factory LocalStudyLogEntry.fromJson(Map<String, dynamic> json) {
    return LocalStudyLogEntry(
      session: StudySession.fromLocalJson(
        Map<String, dynamic>.from(json['session'] as Map? ?? const {}),
      ),
      isSynced: json['is_synced'] as bool? ?? false,
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session': session.toLocalJson(),
      'is_synced': isSynced,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LocalStudyLogEntry copyWith({
    StudySession? session,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return LocalStudyLogEntry(
      session: session ?? this.session,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _readDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

class StudyLogLocalRepository {
  StudyLogLocalRepository({
    this.boxName = 'study_logs',
    this.deletedBoxName = 'deleted_study_logs',
  });

  final String boxName;
  final String deletedBoxName;

  Future<void> initialize() async {
    await _box();
    await _deletedBox();
  }

  Future<void> savePending(StudySession session) async {
    final box = await _box();
    final key = session.id.oid;

    await box.put(
      key,
      LocalStudyLogEntry(
        session: session,
        isSynced: false,
        updatedAt: DateTime.now(),
      ).toJson(),
    );
  }

  Future<void> upsertSynced(StudySession session) async {
    final box = await _box();
    await box.put(
      session.id.oid,
      LocalStudyLogEntry(
        session: session,
        isSynced: true,
        updatedAt: DateTime.now(),
      ).toJson(),
    );
  }

  Future<void> markSynced(StudySession session) async {
    final box = await _box();
    await box.put(
      session.id.oid,
      LocalStudyLogEntry(
        session: session,
        isSynced: true,
        updatedAt: DateTime.now(),
      ).toJson(),
    );
  }

  Future<List<LocalStudyLogEntry>> pendingEntries() async {
    final entries = await entriesList();
    return entries.where((entry) => !entry.isSynced).toList();
  }

  Future<void> deletePending(String sessionId) async {
    final box = await _box();
    await box.delete(sessionId);

    final deletedBox = await _deletedBox();
    await deletedBox.put(sessionId, DateTime.now().toIso8601String());
  }

  Future<void> clearDeleted(String sessionId) async {
    final deletedBox = await _deletedBox();
    await deletedBox.delete(sessionId);
  }

  Future<Set<String>> deletedIds() async {
    final deletedBox = await _deletedBox();
    return deletedBox.keys.map((key) => key.toString()).toSet();
  }

  Future<List<StudySession>> sessions() async {
    final entries = await entriesList();
    return entries.map((entry) => entry.session).toList();
  }

  Future<List<LocalStudyLogEntry>> entriesList() async {
    final box = await _box();
    final entries = box.values
        .map(_readEntry)
        .whereType<LocalStudyLogEntry>()
        .toList();

    entries.sort((a, b) => b.session.createdAt.compareTo(a.session.createdAt));
    return entries;
  }

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName);
    }
    return Hive.openBox<dynamic>(boxName);
  }

  Future<Box<dynamic>> _deletedBox() async {
    if (Hive.isBoxOpen(deletedBoxName)) {
      return Hive.box<dynamic>(deletedBoxName);
    }
    return Hive.openBox<dynamic>(deletedBoxName);
  }

  LocalStudyLogEntry? _readEntry(Object? value) {
    if (value is Map) {
      return LocalStudyLogEntry.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }
}
