import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/sleep_data.dart';
import '../models/user_settings.dart';

class LocalStorageService {
  static const _sessionsBoxName = 'sessions_box';
  static const _settingsBoxName = 'settings_box';
  static const _activeSleepBoxName = 'active_sleep_box';

  late final Box<SleepSession> _sessionsBox;
  late final Box<UserSettings> _settingsBox;
  late final Box _activeSleepBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SleepSessionAdapter());
    Hive.registerAdapter(UserSettingsAdapter());

    _sessionsBox = await Hive.openBox<SleepSession>(_sessionsBoxName);
    _settingsBox = await Hive.openBox<UserSettings>(_settingsBoxName);
    _activeSleepBox = await Hive.openBox(_activeSleepBoxName);
  }

  // Helper to get date string (YYYY-MM-DD)
  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String get _todayString => _getDateString(DateTime.now());

  // Calculate quality percent based on accumulated minutes and goal hours
  int _calculateQualityPercent(int accumulatedMinutes, double goalHours) {
    if (goalHours <= 0) return 0;
    final goalMinutes = (goalHours * 60).round();
    if (goalMinutes <= 0) return 0;
    final percent = (accumulatedMinutes / goalMinutes * 100).round();
    return percent.clamp(0, 100);
  }

  // SETTINGS
  UserSettings getSettings() {
    return _settingsBox.get(
      'user_settings',
      defaultValue: UserSettings.fromTimeOfDay(
        goalHours: 8,
        bedtimeReminderEnabled: false,
        bedtime: const TimeOfDay(hour: 23, minute: 30),
        wakeTime: const TimeOfDay(hour: 7, minute: 0),
      ),
    )!;
  }

  Future<void> saveSettings(UserSettings settings) async {
    await _settingsBox.put('user_settings', settings);
  }

  Stream<UserSettings> streamSettings() {
    return _settingsBox
        .watch(key: 'user_settings')
        .map((event) => event.value as UserSettings? ?? getSettings());
  }

  // ACTIVE SLEEP SESSION (for today)
  Stream<DateTime?> streamActiveStart() {
    // Start with current value, then listen for changes
    final initialValue = getActiveStart();
    final changesStream = _activeSleepBox
        .watch(key: _todayString)
        .map((event) => event.value as DateTime?);

    // Combine initial value with changes
    return Stream<DateTime?>.value(
      initialValue,
    ).asyncExpand((_) => changesStream);
  }

  DateTime? getActiveStart() {
    final timestamp = _activeSleepBox.get(_todayString);
    if (timestamp == null) return null;
    // Handle both DateTime and Timestamp (if stored from Firestore)
    if (timestamp is DateTime) {
      return timestamp;
    }
    return null;
  }

  Future<void> setActiveStart(DateTime start) async {
    await _activeSleepBox.put(_todayString, start);
  }

  Future<void> clearActiveStart() async {
    await _activeSleepBox.delete(_todayString);
  }

  // Get accumulated sleep time for today (in minutes)
  Future<int> getAccumulatedSleepMinutes() async {
    final session = _sessionsBox.get(_todayString);
    return session?.durationMinutes ?? 0;
  }

  // START SLEEP
  Future<void> startSleep(DateTime start) async {
    final existingSession = _sessionsBox.get(_todayString);

    if (existingSession != null) {
      // Session exists for today - preserve accumulated time and update active start
      // Important: Don't overwrite the session, just set the active start
      // This preserves the accumulated minutes from previous sleep periods
      await setActiveStart(start);

      // If session has accumulated time but bedtime equals wakeTime (paused session),
      // we should keep the original bedtime, not update it
      // The session is already correct, just activate it
    } else {
      // New session for today
      final settings = getSettings();
      final initialQuality = _calculateQualityPercent(0, settings.goalHours);

      final newSession = SleepSession(
        dateKey: _todayString,
        bedtime: start,
        wakeTime: start, // Will be updated when sleep stops
        durationMinutes: 0,
        qualityPercent: initialQuality,
      );

      await _sessionsBox.put(_todayString, newSession);
      await setActiveStart(start);
    }
  }

  // STOP SLEEP
  Future<SleepData?> stopSleep(DateTime stop) async {
    final session = _sessionsBox.get(_todayString);
    if (session == null) return null;

    final activeStart = getActiveStart();
    if (activeStart == null) return null;

    // Calculate elapsed time for this sleep period
    final elapsedDuration = stop.difference(activeStart);
    final elapsedSeconds = elapsedDuration.inSeconds;

    // Minimum duration: at least 30 seconds to count as a sleep period
    // This prevents accidental quick pauses from adding time
    if (elapsedSeconds < 30) {
      await clearActiveStart();
      return null;
    }

    // Round to nearest minute (not ceil) to avoid overcounting
    // If 30-89 seconds, count as 1 minute; 90-149 seconds, count as 2 minutes, etc.
    final elapsedMinutes = (elapsedSeconds / 60).round();

    if (elapsedMinutes <= 0) {
      await clearActiveStart();
      return null;
    }

    // Get existing accumulated time
    final existingAccumulatedMinutes = session.durationMinutes;
    final newAccumulatedMinutes = existingAccumulatedMinutes + elapsedMinutes;

    // Get settings and calculate quality
    final settings = getSettings();
    final qualityPercent = _calculateQualityPercent(
      newAccumulatedMinutes,
      settings.goalHours,
    );

    // Update session
    final updatedSession = SleepSession(
      dateKey: _todayString,
      bedtime: session.bedtime, // Keep original bedtime
      wakeTime: stop,
      durationMinutes: newAccumulatedMinutes,
      qualityPercent: qualityPercent,
    );

    await _sessionsBox.put(_todayString, updatedSession);
    await clearActiveStart();

    return SleepData(
      duration: Duration(minutes: newAccumulatedMinutes),
      qualityPercent: qualityPercent,
      bedtime: session.bedtime,
      wakeTime: stop,
    );
  }

  // FETCH LAST NIGHT
  Future<SleepData?> fetchLastNight() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayString = _getDateString(yesterday);

    final session = _sessionsBox.get(yesterdayString);
    if (session != null && session.wakeTime != session.bedtime) {
      return SleepData(
        duration: session.duration,
        qualityPercent: session.qualityPercent,
        bedtime: session.bedtime,
        wakeTime: session.wakeTime,
      );
    }

    // Fallback: Check recent dates (up to 30 days back)
    for (int i = 2; i <= 30; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dateString = _getDateString(date);
      final s = _sessionsBox.get(dateString);

      if (s != null && s.wakeTime != s.bedtime) {
        return SleepData(
          duration: s.duration,
          qualityPercent: s.qualityPercent,
          bedtime: s.bedtime,
          wakeTime: s.wakeTime,
        );
      }
    }

    return null;
  }

  // FETCH LAST 7 SESSIONS
  Future<List<SleepData?>> fetchLast7Sessions() async {
    final now = DateTime.now();
    final sessions = <SleepData?>[];

    // Get sessions for the last 7 days (excluding today), from oldest to newest
    for (int i = 7; i >= 1; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dateString = _getDateString(date);
      final session = _sessionsBox.get(dateString);

      if (session != null && session.wakeTime != session.bedtime) {
        sessions.add(
          SleepData(
            duration: session.duration,
            qualityPercent: session.qualityPercent,
            bedtime: session.bedtime,
            wakeTime: session.wakeTime,
          ),
        );
      } else {
        sessions.add(null);
      }
    }

    return sessions;
  }

  // SESSIONS (for backup/restore)
  List<SleepSession> getAllSessions() {
    return _sessionsBox.values.toList();
  }

  Future<void> saveSession(SleepSession session) async {
    await _sessionsBox.put(session.dateKey, session);
  }

  Future<void> saveAllSessions(List<SleepSession> sessions) async {
    for (final session in sessions) {
      await _sessionsBox.put(session.dateKey, session);
    }
  }

  Future<void> clearAllSessions() async {
    await _sessionsBox.clear();
  }
}
