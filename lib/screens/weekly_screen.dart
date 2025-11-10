import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/sleep_chart.dart';
import '../models/sleep_data.dart';

class WeeklyScreen extends StatelessWidget {
  final AuthService authService;
  const WeeklyScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService(authService);

    return SafeArea(
      child: SingleChildScrollView(
        padding: Gaps.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Weekly Sleep',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your sleep patterns for the past 7 days',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            // Chart and stats
            FutureBuilder<List<SleepData?>>(
              future: service.fetchLast7Sessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final sessions = snapshot.data ?? List.filled(7, null);
                
                // Calculate statistics from sessions with data
                final sessionsWithData = sessions.where((s) => s != null).cast<SleepData>().toList();
                
                // Always show chart, even if no data
                return Column(
                  children: [
                    SleepChart(sessions: sessions),
                    const SizedBox(height: 24),
                    // Statistics card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: sessionsWithData.isEmpty
                          ? _buildEmptyStats()
                          : _buildStats(sessionsWithData),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(List<SleepData> sessions) {
    // Calculate average duration
    final totalMinutes = sessions
        .map((s) => s.duration.inMinutes)
        .fold<int>(0, (a, b) => a + b);
    final avgMinutes = totalMinutes / sessions.length;
    final avgDuration = '${(avgMinutes ~/ 60).round()}h ${(avgMinutes % 60).round()}m';

    // Calculate average bedtime (median for better representation)
    final bedtimes = sessions.map((s) => s.bedtime).toList();
    bedtimes.sort();
    final medianBedtime = bedtimes[bedtimes.length ~/ 2];
    final avgBedtime = _formatTime(medianBedtime);

    // Calculate average quality
    final totalQuality = sessions
        .map((s) => s.qualityPercent)
        .fold<int>(0, (a, b) => a + b);
    final avgQuality = (totalQuality / sessions.length).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatTile(title: 'Avg. Duration', value: avgDuration),
        _StatTile(title: 'Avg. Bedtime', value: avgBedtime),
        _StatTile(title: 'Avg. Quality', value: '$avgQuality%'),
      ],
    );
  }

  Widget _buildEmptyStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatTile(title: 'Avg. Duration', value: '--'),
        _StatTile(title: 'Avg. Bedtime', value: '--'),
        _StatTile(title: 'Avg. Quality', value: '--'),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  const _StatTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
