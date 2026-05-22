import 'package:mongo_dart/mongo_dart.dart';

class StudySession {
  const StudySession({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.photos,
    required this.detectedObjects,
    required this.vibe,
    required this.createdAt,
  });

  final ObjectId id;
  final String type;
  final String title;
  final String description;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final List<String> photos;
  final List<String> detectedObjects;
  final VibeAnalysis vibe;
  final DateTime createdAt;

  factory StudySession.fromMongoDocument(Map<String, dynamic> document) {
    return StudySession(
      id: document['_id'] as ObjectId,
      type: document['type'] as String? ?? 'Lainnya',
      title: document['title'] as String? ?? 'Tanpa judul',
      description: document['description'] as String? ?? '',
      date: DateTime.parse(document['date'] as String),
      startTime: document['start_time'] as String? ?? '--:--',
      endTime: document['end_time'] as String? ?? '--:--',
      durationMinutes: document['duration_minutes'] as int? ?? 0,
      photos: List<String>.from(document['photos'] as List? ?? const []),
      detectedObjects: List<String>.from(
        document['detected_objects'] as List? ?? const [],
      ),
      vibe: VibeAnalysis.fromJson(
        document['vibe'] as Map<String, dynamic>? ?? const {},
      ),
      createdAt: _readDateTime(document['created_at']),
    );
  }

  Map<String, dynamic> toMongoDocument() {
    return {
      '_id': id,
      'type': type,
      'title': title,
      'description': description,
      'date': isoDate,
      'start_time': startTime,
      'end_time': endTime,
      'duration_minutes': durationMinutes,
      'photos': photos,
      'detected_objects': detectedObjects,
      'vibe': vibe.toJson(),
      'created_at': createdAt,
    };
  }

  String get isoDate {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String get timeRange => '$startTime - $endTime';

  static DateTime _readDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }
}

class VibeAnalysis {
  const VibeAnalysis({required this.label, required this.description});

  final String label;
  final String description;

  factory VibeAnalysis.fromJson(Map<String, dynamic> json) {
    return VibeAnalysis(
      label: json['label'] as String? ?? 'Belum dianalisis',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'description': description};
  }
}
