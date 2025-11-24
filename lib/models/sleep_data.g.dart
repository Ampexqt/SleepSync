// Manually written Hive adapter for SleepSession

part of 'sleep_data.dart';

class SleepSessionAdapter extends TypeAdapter<SleepSession> {
  @override
  final int typeId = 0;

  @override
  SleepSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SleepSession(
      dateKey: fields[0] as String,
      bedtime: fields[1] as DateTime,
      wakeTime: fields[2] as DateTime,
      durationMinutes: fields[3] as int,
      qualityPercent: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SleepSession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.bedtime)
      ..writeByte(2)
      ..write(obj.wakeTime)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.qualityPercent);
  }
}
