
import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class CognitiveReframingPage extends StatefulWidget {
  const CognitiveReframingPage({super.key});

  @override
  State<CognitiveReframingPage> createState() =>
      _CognitiveReframingPageState();
}

class _CognitiveReframingPageState
    extends State<CognitiveReframingPage> {
  bool _isSubmitted = false;

  Widget _buildJournalField(
      String title,
      String hint,
      bool isLightMode,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          isLightMode ? 12 : 24,
        ),
        border: isLightMode
            ? null
            : Border.all(
          color: AppColors.elizabeth,
          width: 4,
        ),
        boxShadow: isLightMode
            ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            maxLines: 4,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: isLightMode
                  ? const Color(0xFFF0F0F0)
                  : AppColors.pastelPetal,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(bool isLightMode) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              isLightMode ? 12 : 24,
            ),
            border: isLightMode
                ? null
                : Border.all(
              color: AppColors.elizabeth,
              width: 4,
            ),
            boxShadow: isLightMode
                ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.teaGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.self_improvement,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Well Done',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'You took a great step in challenging negative '
                    'thoughts. Your journal entry was cleared to '
                    'protect your privacy.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, child) {
        final bool isLightMode = themeMode == ThemeMode.light;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: _isSubmitted
                ? _buildCompletionScreen(isLightMode)
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new),
                      color: AppColors.primary,
                      tooltip: 'Back',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reframing Journal',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Work through your thoughts by filling out '
                        'the journal prompts below.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildJournalField(
                    '1. Identify the negative thought',
                    'What is bothering you right now?',
                    isLightMode,
                  ),
                  _buildJournalField(
                    '2. Examine the evidence',
                    'What facts support or contradict this thought?',
                    isLightMode,
                  ),
                  _buildJournalField(
                    '3. Spot Cognitive distortions',
                    'Are you mind-reading, catastrophizing, or '
                        'using "all-or-nothing" thinking?',
                    isLightMode,
                  ),
                  _buildJournalField(
                    '4. Replace with a balanced alternative',
                    'What is a more realistic, compassionate '
                        'way to look at this?',
                    isLightMode,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isSubmitted = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                      ),
                      child: Text(
                        'Reflect & Clear',
                        style: AppTypography.titleLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
