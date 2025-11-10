import 'package:flutter/material.dart';

class UserSettings {
  final double goalHours;
  final bool bedtimeReminderEnabled;
  final TimeOfDay bedtime;
  final TimeOfDay wakeTime;

  const UserSettings({
    required this.goalHours,
    required this.bedtimeReminderEnabled,
    required this.bedtime,
    required this.wakeTime,
  });

  UserSettings copyWith({
    double? goalHours,
    bool? bedtimeReminderEnabled,
    TimeOfDay? bedtime,
    TimeOfDay? wakeTime,
  }) {
    return UserSettings(
      goalHours: goalHours ?? this.goalHours,
      bedtimeReminderEnabled:
          bedtimeReminderEnabled ?? this.bedtimeReminderEnabled,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
    );
  }
}
