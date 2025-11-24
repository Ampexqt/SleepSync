import 'package:hive/hive.dart';

part 'sleep_data.g.dart';

@HiveType(typeId: 0)
class SleepSession {
  @HiveField(0)
  final String dateKey; // YYYY-MM-DD

  @HiveField(1)
  final DateTime bedtime;

  @HiveField(2)
  final DateTime wakeTime;

  @HiveField(3)
  final int durationMinutes;

  @HiveField(4)
  final int qualityPercent; // 0-100

  SleepSession({
    required this.dateKey,
    required this.bedtime,
    required this.wakeTime,
    required this.durationMinutes,
    required this.qualityPercent,
  });

  Duration get duration => Duration(minutes: durationMinutes);
}

class SleepData {
  final Duration duration;
  final int qualityPercent; // 0-100
  final DateTime bedtime;
  final DateTime wakeTime;

  const SleepData({
    required this.duration,
    required this.qualityPercent,
    required this.bedtime,
    required this.wakeTime,
  });
}

class WeeklyBar {
  final String label; // Mon, Tue, ...
  final double hours;
  final bool highQuality;

  const WeeklyBar({
    required this.label,
    required this.hours,
    required this.highQuality,
  });
}
