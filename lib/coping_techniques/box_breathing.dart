import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/design_system.dart';

class BoxBreathingPage extends StatefulWidget {
  const BoxBreathingPage({super.key});

  @override
  State<BoxBreathingPage> createState() => _BoxBreathingPageState();
}

class _BoxBreathingPageState extends State<BoxBreathingPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  bool _isRunning = false;
  int _currentPhase = 0; // 0=Inhale, 1=Hold, 2=Exhale, 3=Hold
  String _instructionText = "Ready?";
  String _subInstructionText = "Press start to begin";

  int _completedCycles = 0;
  int _targetCycles = 0;

  @override
  void initState() {
    super.initState();
    // 4s inhale, 4s hold, 4s exhale, 4s hold = 16 seconds total
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );

    // Expansion (0.0 to 0.25)
    // Hold (0.25 to 0.50)
    // Contraction (0.50 to 0.75)
    // Hold (0.75 to 1.0)
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.8), weight: 25.0),
      TweenSequenceItem(tween: Tween<double>(begin: 1.8, end: 1.8), weight: 25.0),
      TweenSequenceItem(tween: Tween<double>(begin: 1.8, end: 1.0), weight: 25.0),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 25.0),
    ]).animate(_controller);

    _controller.addListener(_updatePhase);
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _completedCycles++;
      if (_completedCycles >= _targetCycles) {
        // We finished the session
        setState(() {
          _isRunning = false;
          _instructionText = "Session Complete";
          _subInstructionText = "Great job finding your center.";
          _controller.reset();
          _completedCycles = 0;
        });
      } else {
        // Loop again
        _controller.forward(from: 0.0);
      }
    }
  }

  void _updatePhase() {
    if (!_isRunning && _controller.value == 0.0 && (_instructionText == "Ready?" || _instructionText == "Session Complete")) {
       return;
    }
    
    final t = _controller.value;
    int newPhase = 0;
    String newInst = "";
    String newSub = "";

    if (t < 0.25) {
      newPhase = 0;
      newInst = "Inhale...";
      newSub = "Breathe in gently";
    } else if (t < 0.50) {
      newPhase = 1;
      newInst = "Hold";
      newSub = "Hold your breath";
    } else if (t < 0.75) {
      newPhase = 2;
      newInst = "Exhale...";
      newSub = "Release slowly";
    } else {
      newPhase = 3;
      newInst = "Hold";
      newSub = "Keep lungs empty";
    }
    
    if (newPhase != _currentPhase || newInst != _instructionText) {
      setState(() {
        _currentPhase = newPhase;
        _instructionText = newInst;
        _subInstructionText = newSub;
      });
    }
  }

  void _startSession(int cycles) {
    Navigator.pop(context); // Close dialog
    setState(() {
      _targetCycles = cycles;
      _completedCycles = 0;
      _isRunning = true;
    });
    _controller.forward(from: 0.0);
    _updatePhase();
  }

  void _showModeSelector() {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isLightMode ? Theme.of(context).extension<AppColorsExtension>()!.secondaryBackground : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Select Duration', 
            style: AppTypography.titleLarge.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'How long would you like to practice box breathing?',
            style: AppTypography.bodyMedium.copyWith(color: isLightMode ? AppColors.textPrimary : AppColors.secondary),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startSession(4), // 4 loops
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('4 Cycles (~1 min)', style: AppTypography.titleMedium.copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startSession(19), // 5 mins = 300s. 300/16 = 18.75 (round up to 19 loops)
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pinkCarnation,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('5 Minutes', style: AppTypography.titleMedium.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        );
      }
    );
  }

  void _toggleTimer() {
    if (_isRunning) {
      _controller.stop();
      setState(() => _isRunning = false);
    } else {
      if (_controller.value == 0.0 && _completedCycles == 0) {
        _showModeSelector();
      } else {
        // Resume
        _controller.forward(from: _controller.value);
        setState(() => _isRunning = true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildImagePlaceholder() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Center(
        child: SvgPicture.asset(
          'assets/images/pufferfishFinal.svg',
          width: 140,
          height: 140,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }

  Widget _buildPhaseBox(String title, String duration, bool isActive, bool isLightMode) {
    return Expanded(
      flex: isActive ? 11 : 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: isActive ? 85 : 70,
        decoration: BoxDecoration(
          color: isActive 
              ? AppColors.primary 
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
              style: AppTypography.labelSmall.copyWith(
                color: isActive ? Colors.white : (isLightMode ? AppColors.textPrimary : AppColors.textSecondary),
                fontSize: 11, // Slightly smaller to fit 4 boxes
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              duration, 
              style: AppTypography.titleMedium.copyWith(
                color: isActive ? AppColors.teaGreen : AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
                    'Box Breathing',
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stabilizes your breathing by balancing your air levels. Keeps you calm but alert',
                    style: AppTypography.titleSmall.copyWith(color: AppColors.arden),
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
              height: 70,
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey<String>(_instructionText),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _instructionText,
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.primary, 
                        fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subInstructionText,
                      style: AppTypography.titleSmall.copyWith(
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
            
            // 4 Phase Containers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPhaseBox('Inhale', '4s', _currentPhase == 0, isLightMode),
                  _buildPhaseBox('Hold', '4s', _currentPhase == 1, isLightMode),
                  _buildPhaseBox('Exhale', '4s', _currentPhase == 2, isLightMode),
                  _buildPhaseBox('Hold', '4s', _currentPhase == 3, isLightMode),
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
                  style: AppTypography.titleMedium.copyWith(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
