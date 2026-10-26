import 'package:flutter/material.dart';
import 'theme/design_system.dart';
import 'services/detection_service.dart';

class SymptomListPage extends StatefulWidget {
  final bool isBottomNav;

  const SymptomListPage({super.key, this.isBottomNav = false});

  @override
  State<SymptomListPage> createState() => _SymptomListPageState();
}

class _SymptomListPageState extends State<SymptomListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredSymptoms = [];

  // Data structure mapping symptom names to their brief descriptions
  final List<Map<String, String>> _symptomData = [
    {'name': 'Hand Tremor', 'desc': 'Shaking of hands caused by tensed muscles'},
    {'name': 'Knee Tremor', 'desc': 'Knee rocking when sitting down'},
    {'name': 'Heavy Breathing', 'desc': 'Rapid breaths caused by spiked heartrate'},
    {'name': 'Fidgeting', 'desc': 'Acts of unease (ex. fiddling with fingers)'},
    {'name': 'Avoidant Gaze', 'desc': 'Inability to maintain eye contact.'},
    {'name': 'Facial Tension', 'desc': 'Contractions and tightness along the facial features due to muscle tension.'},
    {'name': 'Fear', 'desc': 'Overwhelming emotional response to perceived danger.'},
  ];

  @override
  void initState() {
    super.initState();
    _filteredSymptoms = List.from(_symptomData);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSymptoms = _symptomData
          .where((symptom) => symptom['name']!.toLowerCase().contains(query))
          .toList();
    });
  }

  Widget _buildSymptomCard(String title, String description, bool isLightMode) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/info',
          arguments: title,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isLightMode ? AppColors.primary : Colors.white,
          borderRadius: isLightMode ? BorderRadius.circular(12) : BorderRadius.circular(24),
          border: isLightMode ? null : Border.all(color: AppColors.elizabeth, width: 4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(color: isLightMode ? Colors.white : AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTypography.bodySmall.copyWith(color: isLightMode ? Colors.white : AppColors.primary.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isLightMode ? Colors.white : AppColors.elizabeth,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right, color: isLightMode ? AppColors.arden : Colors.white, size: 24),
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isBottomNav)
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
                'Symptoms List',
                style: AppTypography.headlineMedium.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: isLightMode ? Theme.of(context).extension<AppColorsExtension>()!.cardBackground : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.primary.withValues(alpha: 0.5)),
                    suffixIcon: Icon(Icons.search, color: AppColors.primary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                  style: AppTypography.bodyMedium.copyWith(color: isLightMode ? AppColors.textPrimary : AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              // Symptoms List
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredSymptoms.length,
                  itemBuilder: (context, index) {
                    final symptom = _filteredSymptoms[index];
                    return _buildSymptomCard(
                      symptom['name']!,
                      symptom['desc']!,
                      isLightMode,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
