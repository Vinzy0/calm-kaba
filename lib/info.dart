import 'package:flutter/material.dart';
import 'theme/design_system.dart';
import 'services/detection_service.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  String? _selectedSymptom;
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as String?;
    _selectedSymptom ??= args ?? DetectionService.availableSymptoms.first;
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherSymptoms = DetectionService.availableSymptoms
        .where((s) => s != _selectedSymptom)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // The bright green background
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floating Back Button
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0, bottom: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            
            Expanded(
              child: _selectedSymptom == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main initially expanded symptom container
                          ExpandableSymptomCard(
                            symptom: _selectedSymptom!,
                            initiallyExpanded: true,
                          ),
                          const SizedBox(height: 8),
                          
                          // Other Symptoms Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              'Other Symptoms',
                              style: AppTypography.titleLarge.copyWith(color: AppColors.arden),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // The list of other symptoms styled as expandable containers
                          ...otherSymptoms.map((symptom) => ExpandableSymptomCard(symptom: symptom)),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpandableSymptomCard extends StatefulWidget {
  final String symptom;
  final bool initiallyExpanded;

  const ExpandableSymptomCard({
    super.key,
    required this.symptom,
    this.initiallyExpanded = false,
  });

  @override
  State<ExpandableSymptomCard> createState() => _ExpandableSymptomCardState();
}

class _ExpandableSymptomCardState extends State<ExpandableSymptomCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        // Removing the default divider lines from ExpansionTile
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.primary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              height: 1.2,
              // Dynamic font size: 32 when expanded, 20 when collapsed
              fontSize: _isExpanded ? 32 : 20, 
            ),
            child: Text(widget.symptom),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Section
                  Text(
                    'Overview',
                    style: AppTypography.titleLarge.copyWith(color: AppColors.pinkCarnation),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Lorem ipsum dolor sit amet consectetur adipiscing elit soluta exercitation praesentium nulla aute cum ad libero nulla culpa est qui animi laborum quas culpa et aliqua optio iusto nisi quos et rerum quis at non commodo do quidem qui aut est est aliqua omnis dolorem et magna in cillum in eligendi blanditii',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'laborum aliquip eu possimus maxime quod accusamus optio fugiat nihil tempore mollit officia nulla id assumenda magna eiusmod aute qui in iusto ullamco irure praesentium est in est optio dolore maxime aliquip minus dolor quidem velit et nulla temporibus est excepturi nobis rerum amet deleniti adipiscing ducimus in aute voluptate cupiditate distinctio pariatur et',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'vel illum deserunt placeat sunt odio dolorem eum dignissimos excepteur dolore culpa id iusto ex at pariatur amet dignissimos illum voluptate dolore nulla placeat quidem quo est expedita sunt ex qui adipiscing magna accusamus culpa et est at harum fugiat nulla at et laborum qui voluptate vero minim nihil et distinctio qui est quo anim mollit fugiat deserunt cupidatat ea dolor animi voluptas proident ea id sit consectetur aut harum aut et dolorum minim et proident eiusmod tempore et possimus praesentium ut deleniti pariatur vel omnis autem laborum voluptas est temporibus mollit est sed qui animi facere deleniti omnis',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  
                  // Visible Signs Section
                  Text(
                    'Visible Signs',
                    style: AppTypography.titleLarge.copyWith(color: AppColors.pinkCarnation),
                  ),
                  const SizedBox(height: 8),
                  _buildBulletPoint('lorem ipsum dolor sit amet'),
                  _buildBulletPoint('lorem ipsum dolor sit amet'),
                  _buildBulletPoint('lorem ipsum dolor sit amet'),
                  _buildBulletPoint('lorem ipsum dolor sit amet'),
                  _buildBulletPoint('lorem ipsum dolor sit amet'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
