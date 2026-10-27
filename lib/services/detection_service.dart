import 'dart:async';
import 'package:flutter/services.dart';

enum DetectionMode { instant, continuous }

const symptomLabels = <String, String>{
  'fidgeting': 'Fidgeting',
  'hand_tremor': 'Hand Tremor',
  'knee_tremor': 'Knee Tremor',
  'avoidant_gaze': 'Avoidant Gaze',
  'facial_tension': 'Facial Tension',
  'heavy_breathing': 'Heavy Breathing',
  'fear': 'Fear',
};

class BehaviorResult {
  final String symptom;
  final double? score;
  final double threshold;
  final String reason;
  final String warning;
  final String? modelRun;
  BehaviorResult.fromMap(Map<dynamic, dynamic> map)
    : symptom = map['symptom'] as String,
      score = (map['score'] as num?)?.toDouble(),
      threshold = (map['threshold'] as num).toDouble(),
      reason = map['reason'] as String? ?? '',
      warning = map['warning'] as String? ?? '',
      modelRun = map['modelRun'] as String?;
  String get label => symptomLabels[symptom] ?? symptom;
  bool get detected => score != null && score!.isFinite && score! >= threshold;
}

/// One history event per sustained detection. Rearm after two valid negative
/// windows AND 30 seconds since the previous event. Missing tracking does not
/// count as a negative and cannot manufacture a new event.
class DetectionEventRule {
  final Map<String, double> _lastEvent = {};
  final Map<String, int> _negatives = {};
  void reset() {
    _lastEvent.clear();
    _negatives.clear();
  }

  bool accept(BehaviorResult result, double elapsed) {
    if (result.score == null) {
      _negatives[result.symptom] = 0;
      return false;
    }
    if (!result.detected) {
      _negatives[result.symptom] = (_negatives[result.symptom] ?? 0) + 1;
      return false;
    }
    final previous = _lastEvent[result.symptom];
    final accepted =
        previous == null ||
        (elapsed - previous >= 30 && (_negatives[result.symptom] ?? 0) >= 2);
    if (accepted) _lastEvent[result.symptom] = elapsed;
    _negatives[result.symptom] = 0;
    return accepted;
  }
}

class DetectionService {
  static final List<String> availableSymptoms = symptomLabels.values.toList(
    growable: false,
  );
  static const _methods = MethodChannel('calm/detection');
  static const _events = EventChannel('calm/detection/events');
  final _updates = StreamController<Map<dynamic, dynamic>>.broadcast();
  final _detections = StreamController<BehaviorResult>.broadcast();
  final _eventRule = DetectionEventRule();
  StreamSubscription<dynamic>? _subscription;
  bool _running = false;
  bool _disposed = false;
  DetectionMode currentMode = DetectionMode.instant;
  List<BehaviorResult> results = [];
  Stream<Map<dynamic, dynamic>> get updates => _updates.stream;
  Stream<BehaviorResult> get detectionStream => _detections.stream;

  Future<void> startDetection({
    DetectionMode mode = DetectionMode.instant,
  }) async {
    if (_running || _disposed) return;
    currentMode = mode;
    results = [];
    _eventRule.reset();
    _subscription ??= _events.receiveBroadcastStream().listen(
      (dynamic value) {
        if (_disposed) return;
        final packet = value as Map<dynamic, dynamic>;
        if (!_running &&
            packet['type'] != 'stopped' &&
            packet['type'] != 'error') {
          return;
        }
        if (packet['type'] == 'stopped' || packet['type'] == 'error') {
          _running = false;
        }
        if (packet['type'] == 'prediction') {
          results = (packet['results'] as List)
              .map((e) => BehaviorResult.fromMap(e as Map))
              .toList();
          final time = (packet['end'] as num).toDouble();
          if (currentMode == DetectionMode.instant) {
            final detected = results.where((r) => r.detected).toList()
              ..sort((a, b) => b.score!.compareTo(a.score!));
            if (detected.isNotEmpty) {
              _running = false;
              unawaited(_methods.invokeMethod<void>('stop'));
              _detections.add(detected.first);
            }
          } else {
            for (final result in results) {
              if (_eventRule.accept(result, time)) {
                _detections.add(result);
              }
            }
          }
        }
        _updates.add(packet);
      },
      onError: (Object error) {
        _running = false;
        if (!_disposed) {
          _updates.add({
            'type': 'error',
            'message': 'Detection unavailable: $error',
          });
        }
        unawaited(_methods.invokeMethod<void>('stop'));
      },
    );
    _running = true;
    try {
      await _methods.invokeMethod<void>('start');
    } catch (error) {
      _running = false;
      if (!_disposed) {
        _updates.add({
          'type': 'error',
          'message': 'Camera could not start: $error',
        });
      }
    }
  }

  Future<void> stopDetection() async {
    _running = false;
    results = [];
    try {
      await _methods.invokeMethod<void>('stop');
    } on MissingPluginException {
      /* Non-Android widget tests have no camera. */
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopDetection();
    await _subscription?.cancel();
    await _updates.close();
    await _detections.close();
  }
}
