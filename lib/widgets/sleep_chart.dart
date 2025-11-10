import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/sleep_data.dart';

class SleepChart extends StatelessWidget {
  final List<SleepData?> sessions; // 7 items, null for days without data
  const SleepChart({super.key, required this.sessions});

  // Convert time to chart position (0.0 = 6 PM bottom, 1.0 = 6 AM top)
  // Chart represents 12 hours: 6 PM (18:00) to 6 AM next day (06:00)
  double _timeToPosition(DateTime time, {required bool isBedtime}) {
    final hour = time.hour;
    final minute = time.minute;
    final minutesOfDay = hour * 60 + minute;
    
    // 6 PM = 1080 minutes, 6 AM next = 360 minutes (next day)
    // Chart window: 1080 to 1440+360 (6 PM to 6 AM next)
    
    int minutesFrom6PM;
    if (hour >= 18) {
      // Evening: 6 PM to midnight (0 to 360 minutes from 6 PM)
      minutesFrom6PM = minutesOfDay - 1080;
    } else if (hour < 6) {
      // Early morning next day: midnight to 6 AM (360 to 720 minutes from 6 PM)
      minutesFrom6PM = (1440 - 1080) + minutesOfDay;
    } else {
      // Daytime (6 AM to 6 PM) - shouldn't happen for sleep, but handle it
      // Treat as if it's the next cycle
      minutesFrom6PM = (1440 - 1080) + minutesOfDay;
    }
    
    // Chart is 12 hours = 720 minutes
    // Position from bottom: 0.0 = 6 PM, 1.0 = 6 AM
    return (minutesFrom6PM / 720.0).clamp(0.0, 1.0);
  }

  // Get bar position and height for a sleep session
  Map<String, double> _getBarMetrics(SleepData? session) {
    if (session == null) {
      return {'bottom': 0.0, 'height': 0.0};
    }

    // Calculate bedtime position
    final bedtimePos = _timeToPosition(session.bedtime, isBedtime: true);
    
    // Calculate wake time position
    var wakePos = _timeToPosition(session.wakeTime, isBedtime: false);
    
    // If wake time appears before bedtime, it means wake is next day
    // In this case, wake should be after bedtime on the chart
    if (wakePos <= bedtimePos) {
      // Wake is next day - ensure it's positioned after bedtime
      // Use the actual duration to calculate height
      final durationHours = session.duration.inMinutes / 60.0;
      final heightFromDuration = (durationHours / 12.0).clamp(0.05, 1.0);
      
      // Calculate wake position based on bedtime + duration
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
    final maxBottom = 1.0 - height;
    final bottom = bedtimePos.clamp(0.0, maxBottom);
    
    return {
      'bottom': bottom,
      'height': height,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Y-axis labels (from top to bottom: 6 AM, 2 AM, 10 PM, 6 PM)
    // Positions: 6 AM (top, 1.0), 2 AM (0.667), 10 PM (0.333), 6 PM (bottom, 0.0)
    final yAxisLabels = ['6 AM', '2 AM', '10 PM', '6 PM'];
    final yAxisPositions = [1.0, 0.667, 0.333, 0.0]; // Chart positions (1.0 = top/6 AM, 0.0 = bottom/6 PM)

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
          // Chart area
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-axis with time labels
                SizedBox(
                  width: 50,
                  child: Stack(
                    children: yAxisLabels.asMap().entries.map((entry) {
                      final index = entry.key;
                      final label = entry.value;
                      final position = yAxisPositions[index];
                      // Position: 1.0 = top (6 AM), 0.0 = bottom (6 PM)
                      // Chart height is 220, so position 1.0 = top (y=0), position 0.0 = bottom (y=220)
                      final yPosition = (1.0 - position) * 220 - 8; // -8 for text height adjustment
                      return Positioned(
                        top: yPosition.clamp(0.0, 212.0),
                        left: 0,
                        child: SizedBox(
                          width: 50,
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                // Bars area
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(7, (index) {
                      final session = index < sessions.length ? sessions[index] : null;
                      final metrics = _getBarMetrics(session);
                      final isHighQuality = session != null && session.qualityPercent >= 70;
                      final dayLabel = _getDayLabel(index);
                      
                      return _Bar(
                        label: dayLabel,
                        bottom: metrics['bottom']!,
                        height: metrics['height']!,
                        hasData: session != null,
                        isHighQuality: isHighQuality,
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
  }

  String _getDayLabel(int index) {
    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month, now.day - (7 - index));
    final weekday = targetDate.weekday; // 1 = Monday, 7 = Sunday
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double bottom; // 0.0 to 1.0 (0.0 = 6 PM bottom, 1.0 = 6 AM top)
  final double height; // 0.0 to 1.0
  final bool hasData;
  final bool isHighQuality;

  const _Bar({
    required this.label,
    required this.bottom,
    required this.height,
    required this.hasData,
    required this.isHighQuality,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bars area
          Expanded(
            child: Stack(
              children: [
                if (hasData && height > 0.01)
                  Positioned(
                    // Position from bottom: bottom=0.0 means at chart bottom (6 PM), bottom=1.0 means at top (6 AM)
                    bottom: bottom * 220, // Distance from bottom of chart area
                    left: 4,
                    right: 4,
                    height: (height * 220).clamp(16.0, 220.0), // Min height for visibility
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: isHighQuality
                            ? AppGradients.bar
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
                            color: (isHighQuality ? AppColors.primary : AppColors.accent)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Show empty state with subtle indicator
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.ring.withOpacity(0.2),
                        width: 1,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Day label
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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
