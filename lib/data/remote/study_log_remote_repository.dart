import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../models/study_session.dart';

class StudyLogRemoteRepository {
  const StudyLogRemoteRepository({this.collectionName = 'study_logs'});

  final String collectionName;

  Future<void> save(StudySession session) async {
    final db = await _openDb();

    try {
      await db
          .collection(collectionName)
          .replaceOne(
            where.id(session.id),
            session.toMongoDocument(),
            upsert: true,
          );
    } finally {
      await db.close();
    }
  }

  Future<void> delete(String sessionId) async {
    final db = await _openDb();

    try {
      await db.collection(collectionName).deleteOne({
        '_id': ObjectId.fromHexString(sessionId),
      });
    } finally {
      await db.close();
    }
  }

  Future<List<StudySession>> fetchStudyLogs() async {
    final db = await _openDb();

    try {
      final documents = await db
          .collection(collectionName)
          .find(where.sortBy('created_at', descending: true))
          .toList();

      return documents.map(StudySession.fromMongoDocument).toList();
    } finally {
      await db.close();
    }
  }

  Future<Db> _openDb() async {
    final uri = dotenv.env['MONGO_URI'];
    if (uri == null || uri.trim().isEmpty) {
      throw StateError('MONGO_URI belum tersedia di file .env');
    }

    final db = await Db.create(uri);
    await db.open();
    return db;
  }
}
