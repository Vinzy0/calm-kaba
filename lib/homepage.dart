import 'package:flutter/material.dart';
import 'dart:async';
import 'theme/design_system.dart';
import 'services/detection_service.dart';
import 'services/log_service.dart';
import 'services/navigation_observer.dart';
import 'components/camera_preview.dart';
import 'components/diagnostics_panel.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatefulWidget {
  final bool active;
  const HomePage({super.key, this.active = true});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, RouteAware {
  final DetectionService _detectionService = DetectionService();
  final LogService _logService = LogService();
  StreamSubscription<BehaviorResult>? _detectionSubscription;
  StreamSubscription<Map<dynamic, dynamic>>? _updateSubscription;
  ModalRoute<void>? _route;
  bool _isDetecting = false;
  bool _cameraReady = false;
  bool _developerMode = false;
  bool _leadModels = false;
  bool _gpuDelegate = false;
  int _selectedTabIndex = 0;
  String _status =
      'Keep your face, shoulders, and hands visible. Move back for knees.';
  List<BehaviorResult> _results = [];
  double _progress = 0;
  double? _fps;
  Map<dynamic, dynamic> _tracking = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateSubscription = _detectionService.updates.listen((packet) {
      if (!mounted ||
          (!_isDetecting &&
              packet['type'] != 'stopped' &&
              packet['type'] != 'error')) {
        return;
      }
      setState(() {
        switch (packet['type']) {
          case 'status':
            _status = packet['message'] as String;
          case 'error':
          case 'stopped':
            _isDetecting = false;
            _status = packet['message'] as String;
            _results = [];
          case 'tracking':
            _tracking = packet['tracking'] as Map;
            _progress = (packet['progress'] as num).toDouble();
            if (packet['interrupted'] == true) {
              _results = [];
              _fps = null;
              _status = 'Tracking was interrupted. Collecting a fresh window.';
            }
          case 'prediction':
            _results = List.of(_detectionService.results);
            _fps = (packet['fps'] as num).toDouble();
            final count = _results.where((r) => r.detected).length;
            _status = count > 0
                ? '$count behavioral model detection${count == 1 ? '' : 's'} in this window'
                : _results.any((r) => r.score != null)
                ? 'No above-threshold behavioral detections in this window'
                : 'Tracking unavailable. Adjust your position using the guidance below.';
        }
      });
    });
    _detectionSubscription = _detectionService.detectionStream.listen((
      result,
    ) async {
      if (!mounted || !_isDetecting) return;
      if (_detectionService.currentMode == DetectionMode.instant) {
        _stopDetection();
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/detectionInstant',
            arguments: {
              'symptom': result.label,
              'score': result.score,
              'threshold': result.threshold,
            },
          );
        }
      } else {
        try {
          await _logService.addLog(
            result.label,
            score: result.score,
            threshold: result.threshold,
          );
        } catch (error) {
          if (mounted) {
            setState(
              () => _status =
                  'Detection worked, but history could not be saved. $error',
            );
          }
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) detectionRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) detectionRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _stopDetection();
  }

  @override
  void didPushNext() => _stopDetection();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopDetection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    detectionRouteObserver.unsubscribe(this);
    unawaited(_detectionSubscription?.cancel());
    unawaited(_updateSubscription?.cancel());
    unawaited(_detectionService.dispose());
    super.dispose();
  }

  void _startDetection(DetectionMode mode) {
    if (_isDetecting || !_cameraReady) return;
    setState(() {
      _isDetecting = true;
      _results = [];
      _fps = null;
      _tracking = {};
      _progress = 0;
      _status = 'Starting camera and landmark tracking';
    });
    unawaited(_detectionService.startDetection(mode: mode));
  }

  void _stopDetection() {
    if (_isDetecting && mounted) {
      setState(() {
        _isDetecting = false;
        _results = [];
        _tracking = {};
        _fps = null;
        _progress = 0;
        _status = 'Scan stopped. Tap Scan Now to begin a fresh window.';
      });
    }
    unawaited(_detectionService.stopDetection());
  }

  Widget _buildTabButton(String title, int index) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
          _stopDetection();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              color: isSelected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCamera() {
    final mode = _selectedTabIndex == 0
        ? DetectionMode.instant
        : DetectionMode.continuous;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.elizabeth,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _isDetecting
                      ? _stopDetection
                      : _cameraReady
                      ? () => _startDetection(mode)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(_isDetecting ? 'Stop' : 'Scan Now'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.help_outline,
                    color: AppColors.textPrimary,
                  ),
                  tooltip: 'Disclaimer',
                  onPressed: () => Navigator.pushNamed(context, '/disclaimer'),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                BehaviorCameraPreview(
                  onReady: () {
                    if (mounted) setState(() => _cameraReady = true);
                  },
                ),
                if (!_isDetecting)
                  ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: SvgPicture.asset(
                                'assets/images/finalFish.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tap Scan Now to open the camera',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode == DetectionMode.instant
                      ? 'Instant Scan'
                      : 'Continuous Scan',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  semanticsLabel: 'Scan status. $_status',
                ),
                if (_isDetecting) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _progress,
                    color: AppColors.textPrimary,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Face: ${_tracking['face'] == true ? 'tracked' : 'unavailable'}  '
                    'Body: ${_tracking['body'] == true ? 'tracked' : 'unavailable'}'
                    '${_fps == null ? '' : '  ${_fps!.toStringAsFixed(1)} FPS'}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Latest four-second window',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ..._results.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        r.score == null
                            ? '${r.label}: unavailable. ${r.reason}'
                            : '${r.label}: ${r.detected ? 'detected' : 'below threshold'} '
                                  '${(r.score! * 100).toStringAsFixed(1)}%'
                                  '${r.warning.isEmpty ? '' : '. ${r.warning}'}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Behavioral model scores are not a diagnosis. Video is not saved.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Developer diagnostics',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _developerMode,
                      onChanged: (value) {
                        setState(() => _developerMode = value);
                        unawaited(_detectionService.setDiagnostics(value));
                      },
                    ),
                  ],
                ),
                if (_developerMode)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'All-landmark models (lead v6, symptom vs control; next scan)',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: _leadModels,
                        onChanged: _isDetecting
                            ? null
                            : (value) {
                                setState(() => _leadModels = value);
                                unawaited(
                                  _detectionService.setModels(
                                    value ? 'v6' : 'v4',
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                if (_developerMode)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'GPU delegate (experimental, applies on next scan)',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: _gpuDelegate,
                        onChanged: _isDetecting
                            ? null
                            : (value) {
                                setState(() => _gpuDelegate = value);
                                unawaited(_detectionService.setDelegate(value));
                              },
                      ),
                    ],
                  ),
                if (_developerMode)
                  DiagnosticsPanel(source: _detectionService.diagnostics),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String subtitle, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    softWrap: true,
                    style: AppTypography.titleLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    softWrap: true,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopingCard(
    String title,
    String subtitle,
    String route,
    double cardWidth,
  ) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLightMode ? AppColors.pastelPetal : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: isLightMode ? AppColors.primary : AppColors.secondary,
              ),
              softWrap: true,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: isLightMode ? AppColors.primary : AppColors.secondary,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLightMode
                      ? AppColors.pinkCarnation
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header Text & Theme Toggle Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are safe here.',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take a slow breath. We\'ll gently check in on your posture, breathing rhythm, and micro-tension.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Switch to Simple Mode',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: isLightMode,
                          activeTrackColor: AppColors.primary.withValues(
                            alpha: 0.5,
                          ),
                          activeThumbColor: AppColors.primary,
                          inactiveThumbColor: AppColors.primary,
                          onChanged: (value) {
                            AppTheme.themeModeNotifier.value = value
                                ? ThemeMode.light
                                : ThemeMode.dark;
                          },
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isLightMode ? Icons.light_mode : Icons.dark_mode,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Custom Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).extension<AppColorsExtension>()!.cardBackground,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton('Instant Scan', 0),
                      _buildTabButton('Continuous Scan', 1),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _buildCamera(),
              const SizedBox(height: 32),

              // Insights Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Insights',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.arden,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildInsightCard(
                'Symptoms Info',
                'Get more detailed info of the symptoms you can detect through this app.',
                '/symptomList',
              ),
              _buildInsightCard(
                'Your Log',
                'This is where you find your detection history.',
                '/detectionLog',
              ),

              const SizedBox(height: 32),

              // Coping Techniques Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Coping Techniques',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.arden,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/copingTechniques'),
                      child: Text(
                        'See all',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Horizontal Scrollable Coping Techniques
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final cardWidth = (constraints.maxWidth * 0.42).clamp(
                    145.0,
                    220.0,
                  );
                  final cardHeight = (screenHeight * 0.20).clamp(200.0, 260.0);

                  return SizedBox(
                    height: cardHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildCopingCard(
                          'Grounding Technique',
                          'Put your mind elsewhere by activating your five senses.',
                          '/groundingTechnique',
                          cardWidth,
                        ),
                        _buildCopingCard(
                          '4-7-8 Breathing',
                          'Longer exhales to drop your spiked heart rate. Do NOT use when hyperventilating.',
                          '/breathingRegulation',
                          cardWidth,
                        ),
                        _buildCopingCard(
                          'Box Breathing',
                          'Guides you through an even breathing practice.',
                          '/boxBreathing',
                          cardWidth,
                        ),
                        _buildCopingCard(
                          'Cognitive Reframing',
                          'Write down negative thoughts and challenge them against the facts.',
                          '/cognitiveReframing',
                          cardWidth,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
