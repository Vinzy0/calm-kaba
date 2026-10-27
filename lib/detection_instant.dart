import 'package:flutter/material.dart';
import 'theme/design_system.dart';

class DetectionInstantPage extends StatelessWidget {
  const DetectionInstantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    final details = argument is Map ? argument : const {};
    final symptom =
        details['symptom'] as String? ??
        (argument is String ? argument : 'Unavailable');
    final score = (details['score'] as num?)?.toDouble();

    return Scaffold(
      backgroundColor: Colors.white, // White background behind the custom shape
      body: Stack(
        children: [
          // Custom Background Shape (Cloud-like)
          Positioned.fill(
            child: ClipPath(
              clipper: _CloudBackgroundClipper(),
              child: Container(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor, // The bright green color or white in light mode
              ),
            ),
          ),

          // Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.primary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 120,
                  ), // Push down to center visually below the cloud humps
                  Text(
                    'Behavior detected',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    symptom,
                    style: AppTypography.displaySmall.copyWith(
                      color: AppColors.primary, // Pink text
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'The behavioral model flagged this four-second window.'
                    '${score == null ? '' : ' Model score: ${(score * 100).toStringAsFixed(1)}%.'}'
                    ' This score is not a diagnosis or a measure of anxiety severity.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),

                  // Bottom Buttons
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/info',
                            arguments: symptom,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                        ),
                        child: Text(
                          'More Info',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/copingTechniques',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.pinkCarnation, // Lighter pink
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Coping Techniques',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Clipper to create the cloud-like rounded background shown in the mockup
class _CloudBackgroundClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(0, size.height); // Start at bottom left
    path.lineTo(0, size.height * 0.35); // Go up left side

    // First small hump on the left
    path.quadraticBezierTo(
      size.width * 0.15,
      size.height * 0.25,
      size.width * 0.3,
      size.height * 0.3,
    );

    // Main large center hump
    path.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.05,
      size.width * 0.7,
      size.height * 0.25,
    );

    // Right hump
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.15,
      size.width,
      size.height * 0.35,
    );

    path.lineTo(size.width, size.height); // Go down right side
    path.close(); // Connect back to start
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
