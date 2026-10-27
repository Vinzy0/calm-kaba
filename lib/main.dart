import 'package:flutter/material.dart';
import 'theme/design_system.dart';
import 'main_screen.dart';
import 'homepage.dart';
import 'coping_techniques.dart';
import 'symptom_list.dart';
import 'detection_instant.dart';
import 'detection_log.dart';
import 'coping_techniques/grounding_technique.dart';
import 'coping_techniques/breathing_regulation.dart';
import 'coping_techniques/box_breathing.dart';
import 'coping_techniques/cognitive_reframing.dart';
import 'disclaimer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Thesis Anxiety App',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const MainScreen(),
            '/home': (context) => const HomePage(),
            '/copingTechniques': (context) => const CopingTechniquesPage(isBottomNav: false),
            '/symptomList': (context) => const SymptomListPage(isBottomNav: false),
            '/detectionInstant': (context) => const DetectionInstantPage(),
            '/detectionLog': (context) => const DetectionLogPage(),
            '/groundingTechnique': (context) => const GroundingTechniquePage(),
            '/breathingRegulation': (context) => const BreathingRegulationPage(),
            '/boxBreathing': (context) => const BoxBreathingPage(),
            '/cognitiveReframing': (context) => const CognitiveReframingPage(),
            '/disclaimer': (context) => const DisclaimerPage(),
          },
        );
      },
    );
  }
}
