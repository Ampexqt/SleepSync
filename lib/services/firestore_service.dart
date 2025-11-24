import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/sleep_data.dart';

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Use a fixed user document so the app does not depend on login
  String get _userId => 'default_user';

  // Get user-specific collection reference
  CollectionReference<Map<String, dynamic>> _userCollection(String collection) {
    return _db.collection('users').doc(_userId).collection(collection);
  }

  // Helper to get date string (YYYY-MM-DD)
  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Get today's date string
  String get _todayString => _getDateString(DateTime.now());

  // Get reference to today's daily session
  DocumentReference<Map<String, dynamic>> _todaySessionDoc() {
    return _userCollection('daily_sleep_sessions').doc(_todayString);
  }

  // Get reference to a specific date's session
  DocumentReference<Map<String, dynamic>> _sessionDocForDate(
    String dateString,
  ) {
    return _userCollection('daily_sleep_sessions').doc(dateString);
  }

  // Stream the current sleep start time (if actively sleeping today)
  Stream<DateTime?> streamActiveStart() {
    return _todaySessionDoc().snapshots().map((doc) {
      if (!doc.exists) return null;
      final ts = doc.data()?['currentSleepStart'] as Timestamp?;
      return ts?.toDate();
    });
  }

  // Get the current sleep start time (if actively sleeping today)
  Future<DateTime?> getActiveStart() async {
    final doc = await _todaySessionDoc().get();
    if (!doc.exists) return null;
    final ts = doc.data()?['currentSleepStart'] as Timestamp?;
    return ts?.toDate();
  }

  // Get accumulated sleep time for today (in minutes)
  Future<int> getAccumulatedSleepMinutes() async {
    final doc = await _todaySessionDoc().get();
    if (!doc.exists) return 0;
    return (doc.data()?['accumulatedMinutes'] ?? 0) as int;
  }

  // Calculate quality percent based on accumulated minutes and goal hours
  // Returns a value between 0-100, where 100 means goal was achieved or exceeded
  int _calculateQualityPercent(int accumulatedMinutes, double goalHours) {
    if (goalHours <= 0) return 0;

    final goalMinutes = (goalHours * 60).round();
    if (goalMinutes <= 0) return 0;

    // Calculate percentage: (accumulated / goal) * 100
    // Cap at 100% if goal is exceeded
    final percent = (accumulatedMinutes / goalMinutes * 100).round();
    return percent.clamp(0, 100);
  }

  // Start sleep - resume today's session or create a new one
  Future<void> startSleep(DateTime start) async {
    final todayDoc = _todaySessionDoc();
    final doc = await todayDoc.get();

    if (doc.exists) {
      // Session exists for today - resume it
      // IMPORTANT: Only update currentSleepStart, DO NOT touch accumulatedMinutes
      // This ensures all previous sleep periods are preserved and added together
      await todayDoc.update({
        'currentSleepStart': Timestamp.fromDate(start),
        // Note: We don't clear lastWakeTime here - it's fine to keep it
        // It will be updated when we stop sleep again
      });
    } else {
      // New session for today - initialize with zero accumulated time
      // Get current goal to calculate initial quality percent
      final settings = await fetchSettings();
      final goalHours = settings?.goalHours ?? 8.0;
      final initialQuality = _calculateQualityPercent(0, goalHours);

      await todayDoc.set({
        'date': _todayString,
        'firstBedtime': Timestamp.fromDate(start),
        'currentSleepStart': Timestamp.fromDate(start),
        'accumulatedMinutes': 0, // Start with 0, will accumulate as user sleeps
        'lastWakeTime': null,
        'qualityPercent':
            initialQuality, // Start with 0% since no sleep accumulated yet
      });
    }
  }

  // Stop/pause sleep - accumulate time but keep session open for the day
  //
  // CRITICAL ACCUMULATION LOGIC:
  // - Each time sleep is stopped/paused, the elapsed time is ADDED to accumulatedMinutes
  // - accumulatedMinutes is NEVER reset or replaced during the same day
  // - Multiple naps in the same day will have their durations added together
  // - Session only resets when a new day starts (new date = new document)
  // - Uses FieldValue.increment() for atomic addition to prevent race conditions
  // - Quality percent is calculated and updated based on accumulated minutes vs goal hours
  Future<SleepData?> stopSleep(DateTime stop) async {
    final todayDoc = _todaySessionDoc();
    final doc = await todayDoc.get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    final currentSleepStart = data['currentSleepStart'] as Timestamp?;

    if (currentSleepStart == null) {
      // Not currently sleeping, nothing to stop
      return null;
    }

    // Calculate elapsed time for this sleep period
    final sleepStart = currentSleepStart.toDate();
    final elapsedDuration = stop.difference(sleepStart);
    // Calculate total seconds and convert to minutes (round up to nearest minute)
    // This ensures even short naps (less than 1 minute) are counted as at least 1 minute
    final elapsedSeconds = elapsedDuration.inSeconds;
    final elapsedMinutes = elapsedSeconds > 0
        ? (elapsedSeconds / 60)
              .ceil() // Round up to nearest minute
        : 0;

    if (elapsedMinutes <= 0) {
      // No time elapsed, just clear the current sleep start
      await todayDoc.update({'currentSleepStart': null});
      return null;
    }

    // Get existing accumulated time BEFORE updating (for return value calculation)
    final existingAccumulatedMinutes = (data['accumulatedMinutes'] ?? 0) as int;

    // Calculate the new total after increment (for quality percent calculation)
    final newAccumulatedMinutes = existingAccumulatedMinutes + elapsedMinutes;

    // Get current goal hours to calculate accurate quality percent
    final settings = await fetchSettings();
    final goalHours = settings?.goalHours ?? 8.0;

    // Calculate quality percent based on accumulated minutes vs goal
    final qualityPercent = _calculateQualityPercent(
      newAccumulatedMinutes,
      goalHours,
    );

    // CRITICAL: Use FieldValue.increment() for atomic addition
    // This ensures that accumulatedMinutes is ADDED to, not replaced
    // Even if multiple stop operations happen quickly, they will all be accumulated correctly
    // Also update quality percent to reflect the new accumulated total
    await todayDoc.update({
      'accumulatedMinutes': FieldValue.increment(
        elapsedMinutes,
      ), // ADD to existing value
      'currentSleepStart': null, // Clear active sleep so user can resume later
      'lastWakeTime': Timestamp.fromDate(stop),
      'qualityPercent':
          qualityPercent, // Update quality based on goal achievement
    });

    // Return the session data for today with updated accumulated time and quality
    final firstBedtime = (data['firstBedtime'] as Timestamp).toDate();
    return SleepData(
      duration: Duration(minutes: newAccumulatedMinutes),
      qualityPercent: qualityPercent,
      bedtime: firstBedtime,
      wakeTime: stop,
    );
  }

  // Get yesterday's session or the most recent completed session
  Future<SleepData?> fetchLastNight() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayString = _getDateString(yesterday);

    // Get current goal hours to calculate accurate quality percent
    final settings = await fetchSettings();
    final goalHours = settings?.goalHours ?? 8.0;

    // Try to get yesterday's session
    final yesterdayDoc = await _sessionDocForDate(yesterdayString).get();
    if (yesterdayDoc.exists) {
      final data = yesterdayDoc.data()!;
      final firstBedtime = (data['firstBedtime'] as Timestamp).toDate();
      final lastWakeTime = data['lastWakeTime'] as Timestamp?;
      final accumulatedMinutes = (data['accumulatedMinutes'] ?? 0) as int;

      // If there's no lastWakeTime but there's accumulated time, use firstBedtime + accumulated
      final wakeTime =
          lastWakeTime?.toDate() ??
          firstBedtime.add(Duration(minutes: accumulatedMinutes));

      // Calculate quality percent based on accumulated minutes vs goal
      // Always recalculate to ensure accuracy - this reflects whether the goal was achieved
      final qualityPercent = _calculateQualityPercent(
        accumulatedMinutes,
        goalHours,
      );

      return SleepData(
        duration: Duration(minutes: accumulatedMinutes),
        qualityPercent: qualityPercent,
        bedtime: firstBedtime,
        wakeTime: wakeTime,
      );
    }

    // Fallback: Check recent dates manually (up to 30 days back)
    for (int i = 2; i <= 30; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dateString = _getDateString(date);
      final doc = await _sessionDocForDate(dateString).get();

      if (doc.exists) {
        final data = doc.data()!;
        final lastWakeTime = data['lastWakeTime'] as Timestamp?;

        // Only return sessions that have been completed (have a lastWakeTime)
        if (lastWakeTime != null) {
          final firstBedtime = (data['firstBedtime'] as Timestamp).toDate();
          final accumulatedMinutes = (data['accumulatedMinutes'] ?? 0) as int;

          // Calculate quality percent based on accumulated minutes vs goal
          // Always recalculate to ensure accuracy
          final qualityPercent = _calculateQualityPercent(
            accumulatedMinutes,
            goalHours,
          );

          return SleepData(
            duration: Duration(minutes: accumulatedMinutes),
            qualityPercent: qualityPercent,
            bedtime: firstBedtime,
            wakeTime: lastWakeTime.toDate(),
          );
        }
      }
    }

    return null;
  }

  // Get last 7 days of sessions - always returns 7 items (null for days without data)
  // Returns list ordered from oldest to newest day (Mon-Sun)
  Future<List<SleepData?>> fetchLast7Sessions() async {
    final now = DateTime.now();
    final sessions = <SleepData?>[];

    // Get current goal hours to calculate accurate quality percent
    final settings = await fetchSettings();
    final goalHours = settings?.goalHours ?? 8.0;

    // Get sessions for the last 7 days (excluding today), from oldest to newest
    for (int i = 7; i >= 1; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dateString = _getDateString(date);
      final doc = await _sessionDocForDate(dateString).get();

      if (doc.exists) {
        final data = doc.data()!;
        final lastWakeTime = data['lastWakeTime'] as Timestamp?;

        // Only include completed sessions (have lastWakeTime)
        if (lastWakeTime != null) {
          final firstBedtime = (data['firstBedtime'] as Timestamp).toDate();
          final accumulatedMinutes = (data['accumulatedMinutes'] ?? 0) as int;

          // Calculate quality percent based on accumulated minutes vs goal
          // Always recalculate to ensure accuracy
          final qualityPercent = _calculateQualityPercent(
            accumulatedMinutes,
            goalHours,
          );

          sessions.add(
            SleepData(
              duration: Duration(minutes: accumulatedMinutes),
              qualityPercent: qualityPercent,
              bedtime: firstBedtime,
              wakeTime: lastWakeTime.toDate(),
            ),
          );
          continue;
        }
      }
      // No data for this day
      sessions.add(null);
    }

    return sessions;
  }

  Stream<UserSettingsState> streamSettings() {
    return _userCollection('settings').doc('default').snapshots().map((doc) {
      if (!doc.exists) {
        return UserSettingsState(
          goalHours: 8,
          bedtimeReminderEnabled: false,
          bedtime: const TimeOfDay(hour: 23, minute: 30),
          wakeTime: const TimeOfDay(hour: 7, minute: 0),
        );
      }
      final data = doc.data()!;
      return UserSettingsState(
        goalHours: (data['goalHours'] ?? 8).toDouble(),
        bedtimeReminderEnabled: data['bedtimeReminderEnabled'] ?? false,
        bedtime: _toTimeOfDay(data['bedtime'] as Map<String, dynamic>?),
        wakeTime: _toTimeOfDay(data['wakeTime'] as Map<String, dynamic>?),
      );
    });
  }

  Future<UserSettingsState?> fetchSettings() async {
    final doc = await _userCollection('settings').doc('default').get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return UserSettingsState(
      goalHours: (data['goalHours'] ?? 8).toDouble(),
      bedtimeReminderEnabled: data['bedtimeReminderEnabled'] ?? false,
      bedtime: _toTimeOfDay(data['bedtime'] as Map<String, dynamic>?),
      wakeTime: _toTimeOfDay(data['wakeTime'] as Map<String, dynamic>?),
    );
  }

  Future<void> updateSettings(UserSettingsState s) async {
    await _userCollection('settings').doc('default').set({
      'goalHours': s.goalHours,
      'bedtimeReminderEnabled': s.bedtimeReminderEnabled,
      'bedtime': {'h': s.bedtime.hour, 'm': s.bedtime.minute},
      'wakeTime': {'h': s.wakeTime.hour, 'm': s.wakeTime.minute},
    }, SetOptions(merge: true));
  }

  Future<void> createSampleLastNight() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayString = _getDateString(yesterday);
    final bedtime = DateTime(now.year, now.month, now.day - 1, 23, 30);
    final wake = DateTime(now.year, now.month, now.day, 6, 45);

    // Get current goal to calculate accurate quality percent
    final settings = await fetchSettings();
    final goalHours = settings?.goalHours ?? 8.0;
    final accumulatedMinutes = 7 * 60 + 15; // 7 hours 15 minutes
    final qualityPercent = _calculateQualityPercent(
      accumulatedMinutes,
      goalHours,
    );

    // Create a sample session for yesterday
    await _sessionDocForDate(yesterdayString).set({
      'date': yesterdayString,
      'firstBedtime': Timestamp.fromDate(bedtime),
      'lastWakeTime': Timestamp.fromDate(wake),
      'accumulatedMinutes': accumulatedMinutes,
      'currentSleepStart': null,
      'qualityPercent': qualityPercent,
    });
  }

  // Helpers
  TimeOfDay _toTimeOfDay(Map<String, dynamic>? map) {
    final h = (map?['h'] ?? 23) as int;
    final m = (map?['m'] ?? 30) as int;
    return TimeOfDay(hour: h, minute: m);
  }
}

class UserSettingsState {
  final double goalHours;
  final bool bedtimeReminderEnabled;
  final TimeOfDay bedtime;
  final TimeOfDay wakeTime;
  const UserSettingsState({
    required this.goalHours,
    required this.bedtimeReminderEnabled,
    required this.bedtime,
    required this.wakeTime,
  });

  UserSettingsState copyWith({
    double? goalHours,
    bool? bedtimeReminderEnabled,
    TimeOfDay? bedtime,
    TimeOfDay? wakeTime,
  }) {
    return UserSettingsState(
      goalHours: goalHours ?? this.goalHours,
      bedtimeReminderEnabled:
          bedtimeReminderEnabled ?? this.bedtimeReminderEnabled,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
    );
  }
}
