import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/design_system.dart';
import 'main_screen.dart';
import 'homepage.dart';
import 'coping_techniques.dart';
import 'symptom_list.dart';
import 'info.dart';
import 'detection_instant.dart';
import 'detection_log.dart';
import 'coping_techniques/grounding_technique.dart';
import 'coping_techniques/breathing_regulation.dart';
import 'coping_techniques/cognitive_reframing.dart';
import 'disclaimer.dart';
import 'services/navigation_observer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
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
          navigatorObservers: [detectionRouteObserver],
          initialRoute: '/',
          routes: {
            '/': (context) => const MainScreen(),
            '/home': (context) => const HomePage(),
            '/copingTechniques': (context) =>
                const CopingTechniquesPage(isBottomNav: false),
            '/symptomList': (context) =>
                const SymptomListPage(isBottomNav: false),
            '/info': (context) => const InfoPage(),
            '/detectionInstant': (context) => const DetectionInstantPage(),
            '/detectionLog': (context) => const DetectionLogPage(),
            '/groundingTechnique': (context) => const GroundingTechniquePage(),
            '/breathingRegulation': (context) =>
                const BreathingRegulationPage(),
            '/cognitiveReframing': (context) => const CognitiveReframingPage(),
            '/disclaimer': (context) => const DisclaimerPage(),
          },
        );
      },
    );
  }
}
