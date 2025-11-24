import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'user_settings.g.dart';

@HiveType(typeId: 1)
class UserSettings extends HiveObject {
  @HiveField(0)
  final double goalHours;

  @HiveField(1)
  final bool bedtimeReminderEnabled;

  @HiveField(2)
  final int bedtimeHour;

  @HiveField(3)
  final int bedtimeMinute;

  @HiveField(4)
  final int wakeTimeHour;

  @HiveField(5)
  final int wakeTimeMinute;

  UserSettings({
    required this.goalHours,
    required this.bedtimeReminderEnabled,
    required int bedtimeHour,
    required int bedtimeMinute,
    required int wakeTimeHour,
    required int wakeTimeMinute,
  }) : bedtimeHour = bedtimeHour,
       bedtimeMinute = bedtimeMinute,
       wakeTimeHour = wakeTimeHour,
       wakeTimeMinute = wakeTimeMinute;

  // Helper getters for TimeOfDay
  TimeOfDay get bedtime => TimeOfDay(hour: bedtimeHour, minute: bedtimeMinute);
  TimeOfDay get wakeTime =>
      TimeOfDay(hour: wakeTimeHour, minute: wakeTimeMinute);

  // Factory constructor from TimeOfDay
  factory UserSettings.fromTimeOfDay({
    required double goalHours,
    required bool bedtimeReminderEnabled,
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
  }) {
    return UserSettings(
      goalHours: goalHours,
      bedtimeReminderEnabled: bedtimeReminderEnabled,
      bedtimeHour: bedtime.hour,
      bedtimeMinute: bedtime.minute,
      wakeTimeHour: wakeTime.hour,
      wakeTimeMinute: wakeTime.minute,
    );
  }

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
      bedtimeHour: bedtime?.hour ?? this.bedtimeHour,
      bedtimeMinute: bedtime?.minute ?? this.bedtimeMinute,
      wakeTimeHour: wakeTime?.hour ?? this.wakeTimeHour,
      wakeTimeMinute: wakeTime?.minute ?? this.wakeTimeMinute,
    );
  }
}
