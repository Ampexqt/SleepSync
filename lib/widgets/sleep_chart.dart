import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/sleep_data.dart';

class SleepChart extends StatelessWidget {
  final List<SleepData?> sessions; // 7 items, null for days without data
  const SleepChart({super.key, required this.sessions});

  // Convert time to chart position (0.0 = 6 PM left, 1.0 = 6 AM right)
  // Chart represents 12 hours: 6 PM (18:00) to 6 AM next day (06:00)
  // For vertical chart: left = 6 PM, right = 6 AM next day
  double _timeToPosition(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final totalMinutes = hour * 60 + minute;

    // Calculate minutes from 6 PM (18:00 = 1080 minutes)
    int minutesFrom6PM;
    if (hour >= 18) {
      // Evening: 6 PM to midnight (0 to 360 minutes from 6 PM)
      minutesFrom6PM = totalMinutes - 1080;
    } else if (hour < 6) {
      // Early morning next day: midnight to 6 AM (360 to 720 minutes from 6 PM)
      minutesFrom6PM =
          360 + totalMinutes; // 360 (midnight-6PM) + minutes from midnight
    } else {
      // Daytime (6 AM to 6 PM) - for sleep tracking, this means wake time after 6 AM
      // Calculate actual position: 6 AM = 720 minutes, so 7 AM = 780 minutes, etc.
      // This allows accurate positioning even if wake time is after 6 AM
      minutesFrom6PM =
          360 +
          (6 * 60) +
          (totalMinutes -
              (6 * 60)); // 360 (midnight-6PM) + 360 (6PM-6AM) + extra
      // Simplified: 720 + (totalMinutes - 360) = 360 + totalMinutes
      minutesFrom6PM = 360 + totalMinutes;
    }

    // Chart is 12 hours = 720 minutes
    // Position from left: 0.0 = 6 PM, 1.0 = 6 AM next day
    // Clamp to 1.0 max to keep within chart bounds
    return (minutesFrom6PM / 720.0).clamp(0.0, 1.0);
  }

  // Get bar position and height for a sleep session (for vertical bars)
  Map<String, double> _getBarMetrics(SleepData? session) {
    if (session == null) {
      return {'top': 0.0, 'height': 0.0};
    }

    // Calculate bedtime position (top edge of bar)
    // For vertical bars: 0.0 = top (6 PM), 1.0 = bottom (6 AM)
    final bedtimePos = _timeToPosition(session.bedtime);

    // Calculate wake time position (bottom edge of bar)
    var wakePos = _timeToPosition(session.wakeTime);

    // Handle case where wake time is next day (wakePos might be less than bedtimePos)
    // If wake time appears before bedtime, it means wake is next day
    if (wakePos < bedtimePos) {
      // Wake is next day - calculate based on duration
      final durationHours = session.duration.inMinutes / 60.0;
      final heightFromDuration = (durationHours / 12.0).clamp(0.05, 1.0);
      wakePos = (bedtimePos + heightFromDuration).clamp(0.0, 1.0);
    }

    // Calculate height from positions
    double height = wakePos - bedtimePos;

    // Ensure minimum height for visibility
    if (height < 0.05 && session.duration.inMinutes > 30) {
      // Use duration-based height if position-based is too small
      final durationHours = session.duration.inMinutes / 60.0;
      height = (durationHours / 12.0).clamp(0.05, 1.0);
    }

    // Clamp height
    height = height.clamp(0.05, 1.0);

    // Ensure bar doesn't go beyond chart
    final maxTop = 1.0 - height;
    final top = bedtimePos.clamp(0.0, maxTop);

    return {'top': top, 'height': height};
  }

  // Format time for display
  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  // Show details dialog when bar is tapped
  void _showSleepDetails(
    BuildContext context,
    SleepData session,
    String dayLabel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          dayLabel,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              icon: Icons.bedtime,
              label: 'Bedtime',
              value: _formatTime(session.bedtime),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.wb_sunny,
              label: 'Wake Time',
              value: _formatTime(session.wakeTime),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.access_time,
              label: 'Duration',
              value: _formatDuration(session.duration),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.star,
              label: 'Quality',
              value: '${session.qualityPercent}%',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // Reorder sessions so Monday is first
  List<SleepData?> _reorderSessionsForMondayFirst() {
    if (sessions.isEmpty) return List.filled(7, null);

    // Find the weekday of the first (oldest) session
    final now = DateTime.now();
    final firstDayDate = DateTime(now.year, now.month, now.day - 7);
    final firstDayWeekday = firstDayDate.weekday; // 1 = Monday, 7 = Sunday

    // Calculate how many positions to rotate (to make Monday index 0)
    // If firstDayWeekday is 1 (Monday), rotation is 0
    // If firstDayWeekday is 2 (Tuesday), rotation is 6 (move to end)
    // If firstDayWeekday is 7 (Sunday), rotation is 1 (move to end)
    final rotation = (1 - firstDayWeekday) % 7;

    // Create reordered list
    final reordered = List<SleepData?>.filled(7, null);
    for (int i = 0; i < 7; i++) {
      final newIndex = (i + rotation) % 7;
      reordered[newIndex] = sessions[i];
    }

    return reordered;
  }

  @override
  Widget build(BuildContext context) {
    // Reorder sessions so Monday is first
    final reorderedSessions = _reorderSessionsForMondayFirst();

    // Y-axis labels (from top to bottom: 6 PM, 10 PM, 2 AM, 6 AM)
    // Positions: 6 PM (top, 0.0), 10 PM (0.333), 2 AM (0.667), 6 AM (bottom, 1.0)
    final yAxisLabels = ['6 PM', '10 PM', '2 AM', '6 AM'];
    final yAxisPositions = [0.0, 0.333, 0.667, 1.0];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and legend
          Row(
            children: [
              const Text(
                'Sleep Schedule',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              _Legend(color: AppColors.primary, label: 'High Quality'),
              const SizedBox(width: 12),
              _Legend(color: AppColors.accent, label: 'Low Quality'),
            ],
          ),
          const SizedBox(height: 20),
          // Chart area - horizontal layout with vertical bars
          LayoutBuilder(
            builder: (context, constraints) {
              final chartHeight = 280.0; // Height for vertical bars
              return SizedBox(
                height: chartHeight + 50, // Add space for day labels at bottom
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Time labels column (Y-axis) on the left
                    SizedBox(
                      width: 50,
                      child: Stack(
                        children: yAxisLabels.asMap().entries.map((entry) {
                          final index = entry.key;
                          final label = entry.value;
                          final position = yAxisPositions[index];
                          // Position: 0.0 = top (6 PM), 1.0 = bottom (6 AM)
                          final yPosition =
                              (1.0 - position) * chartHeight -
                              8; // -8 for text height adjustment
                          return Positioned(
                            top: yPosition.clamp(0.0, chartHeight - 16),
                            left: 0,
                            child: SizedBox(
                              width: 50,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bars area with day labels
                    Expanded(
                      child: Column(
                        children: [
                          // Bars area
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final session = index < reorderedSessions.length
                                    ? reorderedSessions[index]
                                    : null;
                                final metrics = _getBarMetrics(session);
                                final isHighQuality =
                                    session != null &&
                                    session.qualityPercent >= 70;
                                final dayLabel = _getDayLabel(index);

                                return Expanded(
                                  child: _Bar(
                                    top: metrics['top']!,
                                    height: metrics['height']!,
                                    hasData: session != null,
                                    isHighQuality: isHighQuality,
                                    chartHeight: chartHeight,
                                    onTap: session != null
                                        ? () => _showSleepDetails(
                                            context,
                                            session,
                                            dayLabel,
                                          )
                                        : null,
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Day labels at bottom
                          SizedBox(
                            height: 30,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (index) {
                                final dayLabel = _getDayLabel(index);
                                return Expanded(
                                  child: Text(
                                    dayLabel,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getDayLabel(int index) {
    // Always return Monday-Sunday in order (index 0 = Monday, index 6 = Sunday)
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[index];
  }
}

class _Bar extends StatelessWidget {
  final double top; // 0.0 to 1.0 (0.0 = top/6 PM, 1.0 = bottom/6 AM)
  final double height; // 0.0 to 1.0
  final bool hasData;
  final bool isHighQuality;
  final double chartHeight;
  final VoidCallback? onTap;

  const _Bar({
    required this.top,
    required this.height,
    required this.hasData,
    required this.isHighQuality,
    required this.chartHeight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        children: [
          // Empty state background
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.ring.withOpacity(0.2),
                width: 1,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // Sleep bar
          if (hasData && height > 0.01)
            Positioned(
              // Position from top: top=0.0 means at chart top (6 PM), top=1.0 means at bottom (6 AM)
              top: top * chartHeight,
              left: 4,
              right: 4,
              height: (height * chartHeight).clamp(
                24.0,
                chartHeight,
              ), // Min height for visibility
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: isHighQuality
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppColors.primary, AppColors.accent],
                          )
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.accent.withOpacity(0.7),
                              AppColors.accent.withOpacity(0.5),
                            ],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isHighQuality
                                    ? AppColors.primary
                                    : AppColors.accent)
                                .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
