import 'package:flutter/material.dart';
import 'theme/design_system.dart';

class CopingTechniquesPage extends StatelessWidget {
  final bool isBottomNav;

  const CopingTechniquesPage({super.key, this.isBottomNav = false});

  Widget _buildTechniqueCard(BuildContext context, String title, String description, String route) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        height: 180, // Fixed height for a consistent grid look
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLightMode ? Theme.of(context).extension<AppColorsExtension>()!.cardBackground : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(color: isLightMode ? AppColors.primary : AppColors.secondary, fontWeight: FontWeight.bold, height: 1.1),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                description,
                style: AppTypography.bodySmall.copyWith(color: isLightMode ? AppColors.primary : AppColors.secondary, height: 1.2),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.pinkCarnation,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isBottomNav)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              Text(
                'Coping Techniques',
                style: AppTypography.headlineMedium.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildTechniqueCard(
                      context,
                      'Grounding Technique',
                      'Put your mind elsewhere by activating your five senses.',
                      '/groundingTechnique',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTechniqueCard(
                      context,
                      '4-7-8 Breathing',
                      'Longer exhales to drop your spiked heart rate. Do NOT use when hyperventilating.',
                      '/breathingRegulation',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTechniqueCard(
                      context,
                      'Cognitive Reframing',
                      'Write down anxious thoughts and test them against real facts.',
                      '/cognitiveReframing',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTechniqueCard(
                      context,
                      'Box Breathing',
                      'Guides you through an even breathing practice.',
                      '/boxBreathing',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
