import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../models/study_session.dart';

class StudyLogRepository {
  const StudyLogRepository({this.collectionName = 'study_logs'});

  final String collectionName;

  Future<List<StudySession>> fetchStudyLogs() async {
    final uri = dotenv.env['MONGO_URI'];
    if (uri == null || uri.trim().isEmpty) {
      throw StateError('MONGO_URI belum tersedia di file .env');
    }

    final db = await Db.create(uri);
    await db.open();

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
}
