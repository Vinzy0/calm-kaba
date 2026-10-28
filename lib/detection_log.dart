import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'theme/design_system.dart';
import 'services/log_service.dart';

class DetectionLogPage extends StatefulWidget {
  const DetectionLogPage({super.key});

  @override
  State<DetectionLogPage> createState() => _DetectionLogPageState();
}

class _DetectionLogPageState extends State<DetectionLogPage> {
  final LogService _logService = LogService();
  List<LogEntry> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _logService.getLogs();
    // Sort descending by time
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _exportLogs() async {
    try {
      final file = await _logService.exportLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logs exported to: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting logs: $e')),
        );
      }
    }
  }

  Widget _buildTopBanner() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elizabeth,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.arden, width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Pufferfish SVG
            Container(
              alignment: Alignment.center,
              width: 120, // Increased size to fill space better
              height: 120,
              child: SvgPicture.asset(
                'assets/images/pufferfishFinal.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12), // Reduced gap to push text towards center slightly
            // Text & Button Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feeling uneasy?',
                    style: AppTypography.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter here to see activities that can calm you down.',
                    style: AppTypography.bodySmall.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/copingTechniques'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pinkCarnation,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Go',
                      style: AppTypography.titleMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Log',
          style: AppTypography.titleMedium.copyWith(color: AppColors.arden),
        ),
        GestureDetector(
          onTap: _exportLogs,
          child: Text(
            'Download',
            style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(LogEntry log) {
    // Standardizing to just time to match mockup ("10:31 PM")
    // If you need dates too, consider DateFormat('MMM d, h:mm a')
    final dateStr = DateFormat('h:mm a').format(log.timestamp.toLocal());
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Vertical Green Line
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          // Log Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.symptom,
                  style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 16),
              _buildTopBanner(),
              const SizedBox(height: 24),
              _buildHeaderRow(),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _logs.isEmpty
                        ? Center(
                            child: Text(
                              'No detection logs found.',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.primary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return _buildLogItem(_logs[index]);
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
