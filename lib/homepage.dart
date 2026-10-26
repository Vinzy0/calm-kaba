import 'package:flutter/material.dart';
import 'dart:async';
import 'theme/design_system.dart';
import 'services/detection_service.dart';
import 'services/log_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(initialPage: 0);
  final DetectionService _detectionService = DetectionService();
  final LogService _logService = LogService();

  StreamSubscription? _detectionSubscription;
  bool _isDetecting = false;
  int _selectedTabIndex = 0; // 0 for Instant, 1 for Continuous

  @override
  void dispose() {
    _pageController.dispose();
    _stopDetection();
    super.dispose();
  }

  void _startDetection(DetectionMode mode) {
    if (_isDetecting) return;
    setState(() => _isDetecting = true);

    _detectionService.startDetection(mode: mode);
    _detectionSubscription = _detectionService.detectionStream.listen((symptom) async {
      if (mode == DetectionMode.instant) {
        // Stop on first detection and navigate
        _stopDetection();
        if (mounted) {
          Navigator.pushNamed(
              context,
              '/detectionInstant',
              arguments: symptom
          );
        }
      } else {
        // Continuous mode: log it
        await _logService.addLog(symptom);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Detected & Logged: $symptom')),
          );
        }
      }
    });
  }

  void _stopDetection() {
    setState(() => _isDetecting = false);
    _detectionService.stopDetection();
    _detectionSubscription?.cancel();
    _detectionSubscription = null;
  }

  Widget _buildTabButton(String title, int index) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
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

  Widget _buildCameraPlaceholder(String title, String subtitle, DetectionMode mode) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.elizabeth,
        borderRadius: BorderRadius.circular(24),
        border: isLightMode ? Border.all(color: AppColors.elizabeth, width: 6) : Border.all(color: AppColors.arden, width: 6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize =
          (constraints.maxWidth * 0.42).clamp(90.0, 150.0);

          return Stack(
            children: [
              // Text and button content
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  imageSize * 0.70,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            if (_isDetecting) {
                              _stopDetection();
                            } else {
                              _startDetection(mode);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDetecting
                                ? Colors.red
                                : AppColors.tertiary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            _isDetecting ? 'Stop' : 'Scan Now',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.help_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pushNamed(context, '/disclaimer'),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          tooltip: 'Disclaimer',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Placeholder image
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(20),
                      topLeft: Radius.circular(20),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.image,
                      size: 50,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
                    style: AppTypography.titleLarge.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    softWrap: true,
                    style: AppTypography.bodySmall.copyWith(color: Colors.white),
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
                  color: isLightMode ? AppColors.pinkCarnation : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
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
                      style: AppTypography.headlineMedium.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take a slow breath. We\'ll gently check in on your posture, breathing rhythm, and micro-tension.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Switch to Simple Mode',
                          style: AppTypography.titleSmall.copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: isLightMode,
                          activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                          activeThumbColor: AppColors.primary,
                          inactiveThumbColor: AppColors.primary,
                          onChanged: (value) {
                            AppTheme.themeModeNotifier.value = value ? ThemeMode.light : ThemeMode.dark;
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
                    color: Theme.of(context).extension<AppColorsExtension>()!.cardBackground,
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

              // PageView for Camera modes
              SizedBox(
                height: 220,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                    _stopDetection();
                  },
                  children: [
                    _buildCameraPlaceholder(
                        'Instant Scan',
                        'Displays the first detected symptom',
                        DetectionMode.instant
                    ),
                    _buildCameraPlaceholder(
                        'Continuous Scan',
                        'Logs all detections in the background',
                        DetectionMode.continuous
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Insights Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Insights',
                  style: AppTypography.titleMedium.copyWith(color: AppColors.arden),
                ),
              ),
              const SizedBox(height: 8),
              _buildInsightCard(
                  'Symptoms Info',
                  'Get more detailed info of the symptoms you can detect through this app.',
                  '/symptomList'
              ),
              _buildInsightCard(
                  'Your Log',
                  'This is where you find your detection history.',
                  '/detectionLog'
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
                        style: AppTypography.titleMedium.copyWith(color: AppColors.arden),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/copingTechniques'),
                      child: Text(
                        'See all',
                        style: AppTypography.titleSmall.copyWith(color: AppColors.primary),
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
                  final cardWidth = (constraints.maxWidth * 0.42).clamp(145.0, 220.0);
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
                          'Breathing Regulation',
                          'Coaches you through inhales and exhales to assist with labored breaths.',
                          '/breathingRegulation',
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