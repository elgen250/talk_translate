import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'data/app_database.dart';
import 'features/navigation/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase.instance.init();
  runApp(const TalkTranslateApp());
}

class TalkTranslateApp extends StatelessWidget {
  const TalkTranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talk & Translate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: Colors.white,
        ),
      ),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: child!,
          ),
        );
      },
      home: const MainNavigationScreen(),
    );
  }
}
