import 'package:flutter/material.dart';
import 'theme/design_system.dart';
import 'services/symptom_data.dart';
import 'package:url_launcher/url_launcher.dart';

class SymptomListPage extends StatefulWidget {
  final bool isBottomNav;

  const SymptomListPage({super.key, this.isBottomNav = false});

  @override
  State<SymptomListPage> createState() => _SymptomListPageState();
}

class _SymptomListPageState extends State<SymptomListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredSymptomKeys = [];

  @override
  void initState() {
    super.initState();
    _filteredSymptomKeys = SymptomData.data.keys.toList();
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
      _filteredSymptomKeys = SymptomData.data.keys
          .where((key) => key.toLowerCase().contains(query))
          .toList();
    });
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link $urlString')),
        );
      }
    }
  }

  Widget _buildExpandableSymptomCard(String title, Map<String, dynamic> data, bool isLightMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isLightMode ? Theme.of(context).extension<AppColorsExtension>()!.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.primary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          title: Text(
            title,
            style: AppTypography.titleLarge.copyWith(
              color: isLightMode ? AppColors.textPrimary : AppColors.primary,
            ),
          ),
          subtitle: Text(
            data['desc'],
            style: AppTypography.bodySmall.copyWith(
              color: isLightMode ? AppColors.textPrimary : AppColors.primary.withValues(alpha: 0.8),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Universal Preface Note
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.teaGreen.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.elizabeth),
                    ),
                    child: Text(
                      'Individuals suffering from anxiety are stuck at a constant state of perceiving events, sensations, perceptions, thoughts, and even the unknown, at a higher baseline for threat than normal. One of the roles of amygdala, a part of our brain, is perception of threats. When threat is perceived, the amygdala triggers physiological stress responses (anxiety, fear, increased heart rate), before the realness of the threat is even evaluated. The prefrontal cortex is meant to provide emotional regulation when the amygdala fires up, and allows you to employ coping techniques. In people suffering from clinical anxiety, the functional connection between these two parts of the brain are significantly weaker. The prefrontal cortex for such individuals are unable to effectively regulate the threats perceived by the amygdala. This results in anxiety, as normal situations begin to feel threatening without the regulation of the prefrontal cortex.',
                      style: AppTypography.bodySmall.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),

                  // Overview Section
                  Text(
                    'Overview',
                    style: AppTypography.titleLarge.copyWith(color: AppColors.pinkCarnation),
                  ),
                  const SizedBox(height: 12),
                  ...(data['overview'] as List<String>).map((paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(paragraph, style: AppTypography.bodyMedium),
                  )),
                  const SizedBox(height: 12),
                  
                  // Visible Signs Section
                  Text(
                    'Visible Signs',
                    style: AppTypography.titleLarge.copyWith(color: AppColors.pinkCarnation),
                  ),
                  const SizedBox(height: 8),
                  ...(data['signs'] as List<String>).map((sign) => _buildBulletPoint(sign)),
                  
                  // Treatments Section (if applicable)
                  if (data.containsKey('treatments')) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Common Treatments',
                      style: AppTypography.titleLarge.copyWith(color: AppColors.pinkCarnation),
                    ),
                    const SizedBox(height: 8),
                    ...(data['treatments'] as List<String>).map((treatment) => _buildBulletPoint(treatment)),
                  ],

                  // Links Section
                  const SizedBox(height: 24),
                  Text(
                    'Resources',
                    style: AppTypography.titleLarge.copyWith(color: AppColors.pinkCarnation),
                  ),
                  const SizedBox(height: 8),
                  ...(data['links'] as List<String>).map((link) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onTap: () => _launchUrl(link),
                      child: Text(
                        link,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  )),
                ],
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
                    hintStyle: AppTypography.bodyMedium.copyWith(color: isLightMode ? AppColors.textPrimary.withValues(alpha: 0.5) : AppColors.primary.withValues(alpha: 0.5)),
                    suffixIcon: Icon(Icons.search, color: isLightMode ? AppColors.textPrimary : AppColors.primary),
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
                  itemCount: _filteredSymptomKeys.length,
                  itemBuilder: (context, index) {
                    final key = _filteredSymptomKeys[index];
                    final data = SymptomData.data[key]!;
                    return _buildExpandableSymptomCard(key, data, isLightMode);
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
