import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thesis_anxiety/homepage.dart';
import 'package:thesis_anxiety/detection_instant.dart';
import 'package:thesis_anxiety/services/detection_service.dart';
import 'package:thesis_anxiety/services/log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thesis_anxiety/theme/design_system.dart';

BehaviorResult result(double? score) => BehaviorResult.fromMap({
  'symptom': 'fidgeting',
  'score': score,
  'threshold': .5,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'sustained detection logs once and missing tracking cannot rearm it',
    () {
      final rule = DetectionEventRule();
      expect(rule.accept(result(.8), 5), isTrue);
      for (var t = 7; t < 100; t += 2) {
        expect(rule.accept(result(.8), t.toDouble()), isFalse);
      }
      expect(rule.accept(result(null), 101), isFalse);
      expect(rule.accept(result(null), 103), isFalse);
      expect(rule.accept(result(.9), 105), isFalse);
      expect(rule.accept(result(.1), 107), isFalse);
      expect(rule.accept(result(.2), 109), isFalse);
      expect(rule.accept(result(.9), 111), isTrue);
      expect(rule.accept(result(.1), 113), isFalse);
      expect(rule.accept(result(.1), 115), isFalse);
      expect(rule.accept(result(.9), 117), isFalse);
    },
  );
  test('simultaneous detections persist without overwriting each other', () async {
    SharedPreferences.setMockInitialValues({});
    final logs = LogService();
    await Future.wait([
      logs.addLog(
        'Fidgeting',
        score: .8,
        threshold: .5,
        modelRun:
            '2026-10-27_51participants_full_vs_restricted/restricted/vs_control',
      ),
      logs.addLog(
        'Hand Tremor',
        score: .6,
        threshold: .5,
        modelRun:
            '2026-10-27_51participants_full_vs_restricted/restricted/vs_control',
      ),
    ]);
    final saved = await logs.getLogs();
    expect(saved.map((e) => e.symptom), ['Fidgeting', 'Hand Tremor']);
    expect(saved.first.score, .8);
    expect(saved.first.modelRun, contains('/restricted/vs_control'));
    expect(
      LogEntry.fromMap({
        'symptom': 'Old log',
        'timestamp': '2025-01-01T00:00:00',
      }).score,
      isNull,
    );
  });
  test(
    'instant waits for a valid threshold crossing and ignores later packets',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var stopCalls = 0;
      messenger.setMockMethodCallHandler(
        const MethodChannel('calm/detection'),
        (call) async {
          if (call.method == 'stop') stopCalls++;
          return null;
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('calm/detection/events'),
        (_) async => null,
      );
      final service = DetectionService();
      final detected = <BehaviorResult>[];
      final subscription = service.detectionStream.listen(detected.add);
      Future<void> packet(double? score) async {
        await messenger.handlePlatformMessage(
          'calm/detection/events',
          const StandardMethodCodec().encodeSuccessEnvelope({
            'type': 'prediction',
            'end': 5.0,
            'results': [
              {'symptom': 'fidgeting', 'score': score, 'threshold': .5},
            ],
          }),
          (_) {},
        );
        await Future<void>.delayed(Duration.zero);
      }

      await service.startDetection();
      await packet(null);
      await packet(.49);
      expect(detected, isEmpty);
      await packet(.5);
      expect(detected.single.label, 'Fidgeting');
      expect(stopCalls, 1);
      await packet(.9);
      expect(detected.length, 1);
      await subscription.cancel();
      await service.dispose();
      messenger.setMockMethodCallHandler(
        const MethodChannel('calm/detection'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('calm/detection/events'),
        null,
      );
    },
  );
  testWidgets('instant result fits a small phone with model details', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(
            arguments: {
              'symptom': 'Heavy Breathing',
              'score': .7,
              'threshold': .5,
            },
          ),
          builder: (_) => const DetectionInstantPage(),
        ),
      ),
    );
    expect(find.text('Heavy Breathing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('home has real camera status and scan mode controls', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HomePage()),
    );
    expect(find.text('Camera detection requires Android'), findsOneWidget);
    expect(find.text('Scan Now'), findsOneWidget);
    expect(find.textContaining('Video is not saved.'), findsOneWidget);
    await tester.tap(find.text('Continuous Scan').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.binding.setSurfaceSize(null);
    debugDefaultTargetPlatformOverride = null;
  });
}
