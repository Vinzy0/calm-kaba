import 'dart:async';
import 'dart:math';

enum DetectionMode { instant, continuous }

class DetectionService {
  static const List<String> availableSymptoms = [
    'Hand Tremor',
    'Knee Tremor',
    'Heavy Breathing',
    'Fidgeting',
    'Avoidant Gaze',
    'Facial Tension',
    'Fear'
  ];

  static final DetectionService _instance = DetectionService._internal();
  factory DetectionService() => _instance;
  DetectionService._internal();

  final _random = Random();
  Timer? _timer;
  final _detectionController = StreamController<String>.broadcast();

  Stream<String> get detectionStream => _detectionController.stream;
  DetectionMode currentMode = DetectionMode.instant;

  void startDetection({DetectionMode mode = DetectionMode.instant}) {
    currentMode = mode;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      // Mocking a chance of detecting a symptom
      if (_random.nextBool()) {
        final randomSymptom = availableSymptoms[_random.nextInt(availableSymptoms.length)];
        _detectionController.add(randomSymptom);
      }
    });
  }

  void stopDetection() {
    _timer?.cancel();
  }
  
  void dispose() {
    _timer?.cancel();
    _detectionController.close();
  }
}
