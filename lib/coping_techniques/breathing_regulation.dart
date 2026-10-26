import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class BreathingRegulationPage extends StatefulWidget {
  const BreathingRegulationPage({super.key});

  @override
  State<BreathingRegulationPage> createState() => _BreathingRegulationPageState();
}

class _BreathingRegulationPageState extends State<BreathingRegulationPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  bool _isRunning = false;
  int _currentPhase = 0; // 0=Inhale, 1=Hold, 2=Exhale
  String _instructionText = "Ready?";
  String _subInstructionText = "Press start to begin";

  @override
  void initState() {
    super.initState();
    // 4s inhale, 7s hold, 8s exhale = 19 seconds total
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 19),
    );

    // Expansion (0.0 to 4.0 seconds) -> 4/19 = 0.2105
    // Hold (4.0 to 11.0 seconds) -> 11/19 = 0.5789
    // Contraction (11.0 to 19.0 seconds) -> 1.0
    _scaleAnimation = TweenSequence([
      // Reduced maximum scale from 2.2 to 1.8 to prevent visual clutter
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.8), weight: 4.0),
      TweenSequenceItem(tween: Tween<double>(begin: 1.8, end: 1.8), weight: 7.0),
      TweenSequenceItem(tween: Tween<double>(begin: 1.8, end: 1.0), weight: 8.0),
    ]).animate(_controller);

    _controller.addListener(_updatePhase);
  }

  void _updatePhase() {
    // Keep default instruction state if animation hasn't started yet
    if (!_isRunning && _controller.value == 0.0 && _instructionText == "Ready?") {
       return;
    }
    
    final t = _controller.value;
    int newPhase = 0;
    String newInst = "";
    String newSub = "";

    if (t < 0.2105) {
      newPhase = 0;
      newInst = "Inhale...";
      newSub = "Breathe in gently";
    } else if (t < 0.5789) {
      newPhase = 1;
      newInst = "Hold";
      newSub = "Hold your breath";
    } else {
      newPhase = 2;
      newInst = "Exhale...";
      newSub = "Release slowly";
    }
    
    if (newPhase != _currentPhase || newInst != _instructionText) {
      setState(() {
        _currentPhase = newPhase;
        _instructionText = newInst;
        _subInstructionText = newSub;
      });
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _controller.stop();
      setState(() => _isRunning = false);
    } else {
      _controller.repeat();
      setState(() {
        _isRunning = true;
        // Force immediate update to change "Ready?" text if it's the first run
        _updatePhase();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildImagePlaceholder() {
    // TODO: Swap this Container with Image.asset('assets/images/pufferfish_placeholder.png') when the asset is available.
    return Container(
      width: 100, // Reduced from 120 to fit better on screen
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 4),
      ),
      child: Center(
        child: Icon(Icons.image, size: 40, color: AppColors.primary.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildPhaseBox(String title, String duration, bool isActive, bool isLightMode) {
    return Expanded(
      flex: isActive ? 11 : 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        height: isActive ? 85 : 70, // Reduced from 110 / 90
        decoration: BoxDecoration(
          color: isActive 
              ? (isLightMode ? AppColors.elizabeth : AppColors.primary)
              : (isLightMode ? Theme.of(context).extension<AppColorsExtension>()!.cardBackground : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive 
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] 
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title, 
              style: AppTypography.labelSmall.copyWith( // Reduced from labelMedium
                color: isActive ? Colors.white : (isLightMode ? AppColors.textPrimary : AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              duration, 
              style: AppTypography.titleMedium.copyWith( // Reduced from titleLarge
                color: isActive ? (isLightMode ? AppColors.arden : AppColors.teaGreen) : (isLightMode ? AppColors.tertiary : AppColors.secondary),
                fontWeight: FontWeight.bold,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back Button
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0, bottom: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            
            // Header Texts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guided Breathing\nRegulation',
                    style: AppTypography.headlineMedium.copyWith( // Reduced from displaySmall
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4), // Reduced spacing
                  Text(
                    '4-7-8 Breathing',
                    style: AppTypography.titleSmall.copyWith(color: AppColors.arden), // Reduced from titleLarge
                  ),
                ],
              ),
            ),
            
            // Animated Placeholder Image
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: _buildImagePlaceholder(),
                    );
                  }
                ),
              ),
            ),
            
            // Instruction Texts (Centered perfectly)
            SizedBox(
              height: 70, // Slightly reduced
              width: double.infinity, // Forces exact horizontal centering
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey<String>(_instructionText),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _instructionText,
                      style: AppTypography.headlineSmall.copyWith( // Reduced from headlineMedium
                        color: AppColors.primary, 
                        fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subInstructionText,
                      style: AppTypography.titleSmall.copyWith( // Reduced from titleMedium
                        color: AppColors.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 3 Phase Containers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0), // Slightly more horizontal padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPhaseBox('Inhale', '4s', _currentPhase == 0, isLightMode),
                  _buildPhaseBox('Hold', '7s', _currentPhase == 1, isLightMode),
                  _buildPhaseBox('Exhale', '8s', _currentPhase == 2, isLightMode),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Start/Pause Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _toggleTimer,
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 24),
                label: Text(
                  _isRunning ? 'Pause' : 'Start',
                  style: AppTypography.titleMedium.copyWith(color: Colors.white), // Reduced from titleLarge
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), // Reduced padding
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
              ),
            ),
            
            const SizedBox(height: 32), // Reduced from 40
          ],
        ),
      ),
    );
  }
}
