// Manually written Hive adapter for UserSettings

part of 'user_settings.dart';

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 1;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      goalHours: (fields[0] ?? 8.0) as double,
      bedtimeReminderEnabled: (fields[1] ?? false) as bool,
      bedtimeHour: (fields[2] ?? 23) as int,
      bedtimeMinute: (fields[3] ?? 30) as int,
      wakeTimeHour: (fields[4] ?? 7) as int,
      wakeTimeMinute: (fields[5] ?? 0) as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.goalHours)
      ..writeByte(1)
      ..write(obj.bedtimeReminderEnabled)
      ..writeByte(2)
      ..write(obj.bedtimeHour)
      ..writeByte(3)
      ..write(obj.bedtimeMinute)
      ..writeByte(4)
      ..write(obj.wakeTimeHour)
      ..writeByte(5)
      ..write(obj.wakeTimeMinute);
  }
}
