import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:vibe_notes/data/models/study_session.dart';
import 'package:vibe_notes/view/dashboard_view.dart';

void main() {
  testWidgets('shows VibeNote dashboard content', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const ui.Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardView(
          loadSessions: () async => [
            StudySession(
              id: ObjectId(),
              type: 'Kuliah',
              title: 'Review Proyek PCD',
              description: 'Sesi review progres Pengolahan Citra Digital',
              date: today,
              startTime: '13:00',
              endTime: '14:40',
              durationMinutes: 100,
              photos: const ['https://example.com/session1_1.jpg'],
              detectedObjects: const ['Laptop', 'Buku', 'Kopi'],
              vibe: const VibeAnalysis(
                label: 'Fokus',
                description: 'Suasana kegiatan terlihat fokus.',
              ),
              createdAt: DateTime.utc(2026, 5, 20),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VibeNote'), findsOneWidget);
    expect(find.text('Mulai Sesi'), findsOneWidget);
    expect(find.text('Waktu beraktivitas'), findsOneWidget);
    expect(find.text('1h 40m'), findsOneWidget);
    expect(find.text('Review Proyek PCD'), findsOneWidget);
    expect(find.text('Kuliah'), findsOneWidget);
    expect(find.text('Fokus'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Weekly Trend'), findsOneWidget);
    expect(find.text('Top Detected Objects'), findsOneWidget);
    expect(find.text('Vibe Breakdown'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review Proyek PCD'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Sesi'), findsOneWidget);
    expect(find.text('Foto Sesi'), findsOneWidget);
    expect(find.text('Insight sesi'), findsOneWidget);
    expect(find.textContaining('Vibe: Fokus'), findsOneWidget);
  });
}
