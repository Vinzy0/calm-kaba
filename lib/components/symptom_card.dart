import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class SymptomCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  const SymptomCard({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).extension<AppColorsExtension>()!.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleLarge),
            const SizedBox(height: 8),
            Text(description, style: AppTypography.bodyMedium),
          ],
        ),
      ),
    );
  }
}
