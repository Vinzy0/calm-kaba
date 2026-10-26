import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class GroundingTechniquePage extends StatefulWidget {
  const GroundingTechniquePage({super.key});

  @override
  State<GroundingTechniquePage> createState() => _GroundingTechniquePageState();
}

class _GroundingTechniquePageState extends State<GroundingTechniquePage> {
  int _currentStep = 0;
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> _steps = [
    {'count': 5, 'prompt': 'Things You See', 'answers': <String>[]},
    {'count': 4, 'prompt': 'Things You Can Feel', 'answers': <String>[]},
    {'count': 3, 'prompt': 'Things You Can Hear', 'answers': <String>[]},
    {'count': 2, 'prompt': 'Things You Can Smell', 'answers': <String>[]},
    {'count': 1, 'prompt': 'Thing You Can Taste', 'answers': <String>[]},
  ];

  void _submitAnswer() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _steps[_currentStep]['answers'].add(_controller.text.trim());
      _controller.clear();

      if (_steps[_currentStep]['answers'].length >= _steps[_currentStep]['count']) {
        if (_currentStep < _steps.length - 1) {
          _currentStep++;
        } else {
          _currentStep++; // Indicates completion
        }
      }
    });
  }

  Widget _buildCompletedState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.elizabeth, width: 4),
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
              child: const Icon(Icons.check_circle, size: 80, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('Great Job!', style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
            const SizedBox(height: 16),
            Text(
              'You\'ve completed the 5-4-3-2-1 grounding exercise. Hopefully you feel a bit more present.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Finish', style: AppTypography.titleMedium.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCompleted = _currentStep >= _steps.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Floating Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 16),
              isCompleted
                  ? Expanded(child: _buildCompletedState())
                  : Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.elizabeth, width: 4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step ${_currentStep + 1} of 5',
                              style: AppTypography.titleMedium.copyWith(color: AppColors.pinkCarnation),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Name ${_steps[_currentStep]['count']} ${_steps[_currentStep]['prompt']}',
                              style: AppTypography.headlineSmall.copyWith(color: AppColors.primary),
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _steps[_currentStep]['answers'].length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.frostedMint,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          _steps[_currentStep]['answers'][index],
                                          style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_steps[_currentStep]['answers'].length} / ${_steps[_currentStep]['count']} complete',
                                style: AppTypography.titleSmall.copyWith(color: AppColors.arden),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Type here...',
                          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.primary.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                              ),
                              onPressed: _submitAnswer,
                            ),
                          ),
                        ),
                        style: AppTypography.bodyLarge.copyWith(color: AppColors.primary),
                        onSubmitted: (_) => _submitAnswer(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
