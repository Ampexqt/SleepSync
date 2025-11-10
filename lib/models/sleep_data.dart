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
