import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/local/study_log_local_repository.dart';
import 'data/remote/study_log_repository.dart';
import 'view/dashboard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StudyLogLocalRepository().initialize();
  await dotenv.load(fileName: '.env');
  StudyLogRepository.startAutoSync();
  runApp(const VibeNotesApp());
}

class VibeNotesApp extends StatelessWidget {
  const VibeNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF11BFAE),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF8F8F8),
        useMaterial3: true,
      ),
      home: const DashboardView(),
    );
  }
}
