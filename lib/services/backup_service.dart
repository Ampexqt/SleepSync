import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/sleep_data.dart';
import '../models/user_settings.dart';
import 'local_storage_service.dart';

class BackupService {
  final LocalStorageService _localStorage;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  BackupService(this._localStorage);

  // Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generate user ID from email
  String _generateUserId(String email) {
    final bytes = utf8.encode(email.toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 28); // Use first 28 chars as userId
  }

  // Authenticate user with email and password
  Future<String> authenticate({
    required String email,
    required String password,
    bool createIfNotExists = false,
  }) async {
    final emailLower = email.toLowerCase().trim();
    final userId = _generateUserId(emailLower);
    final hashedPassword = _hashPassword(password);

    // Check if user exists
    final userDoc = await _db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      if (createIfNotExists) {
        // Create new user
        await _db.collection('users').doc(userId).set({
          'email': emailLower,
          'passwordHash': hashedPassword,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return userId;
      } else {
        throw Exception('No account found for that email.');
      }
    } else {
      // Verify password
      final userData = userDoc.data()!;
      final storedPasswordHash = userData['passwordHash'] as String?;

      if (storedPasswordHash == null || storedPasswordHash != hashedPassword) {
        throw Exception('Wrong password provided.');
      }

      return userId;
    }
  }

  CollectionReference<Map<String, dynamic>> _userCollection(
    String userId,
    String collection,
  ) {
    return _db.collection('users').doc(userId).collection(collection);
  }

  // Helper to convert SleepSession to Firestore format
  Map<String, dynamic> _sessionToFirestore(
    SleepSession session,
    DateTime? activeStart,
  ) {
    return {
      'date': session.dateKey,
      'firstBedtime': Timestamp.fromDate(session.bedtime),
      'lastWakeTime': session.wakeTime != session.bedtime
          ? Timestamp.fromDate(session.wakeTime)
          : null,
      'accumulatedMinutes': session.durationMinutes,
      'currentSleepStart': activeStart != null
          ? Timestamp.fromDate(activeStart)
          : null,
      'qualityPercent': session.qualityPercent,
    };
  }

  // Helper to convert Firestore data to SleepSession
  SleepSession? _firestoreToSession(Map<String, dynamic> data, String dateKey) {
    try {
      final firstBedtime = (data['firstBedtime'] as Timestamp).toDate();
      final lastWakeTime = data['lastWakeTime'] as Timestamp?;
      final accumulatedMinutes = (data['accumulatedMinutes'] ?? 0) as int;
      final qualityPercent = (data['qualityPercent'] ?? 80) as int;

      // Use lastWakeTime if available, otherwise use firstBedtime (for active sessions)
      final wakeTime = lastWakeTime?.toDate() ?? firstBedtime;

      return SleepSession(
        dateKey: dateKey,
        bedtime: firstBedtime,
        wakeTime: wakeTime,
        durationMinutes: accumulatedMinutes,
        qualityPercent: qualityPercent,
      );
    } catch (e) {
      return null;
    }
  }

  // BACKUP to Firestore with authentication
  Future<void> backup({required String email, required String password}) async {
    try {
      // Authenticate (create account if doesn't exist)
      final userId = await authenticate(
        email: email,
        password: password,
        createIfNotExists: true,
      );

      // Backup settings
      final settings = _localStorage.getSettings();
      await _userCollection(userId, 'settings').doc('default').set({
        'goalHours': settings.goalHours,
        'bedtimeReminderEnabled': settings.bedtimeReminderEnabled,
        'bedtime': {'h': settings.bedtimeHour, 'm': settings.bedtimeMinute},
        'wakeTime': {'h': settings.wakeTimeHour, 'm': settings.wakeTimeMinute},
      }, SetOptions(merge: true));

      // Backup all sessions
      final sessions = _localStorage.getAllSessions();
      if (sessions.isNotEmpty) {
        final batch = _db.batch();
        final now = DateTime.now();
        final todayString =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final todayActiveStart = _localStorage.getActiveStart();

        for (final session in sessions) {
          final sessionRef = _userCollection(
            userId,
            'daily_sleep_sessions',
          ).doc(session.dateKey);
          // Only include active start for today's session
          final activeStart = session.dateKey == todayString
              ? todayActiveStart
              : null;
          batch.set(sessionRef, _sessionToFirestore(session, activeStart));
        }

        await batch.commit();
      }
    } catch (e) {
      throw Exception('Backup failed: $e');
    }
  }

  // RESTORE from Firestore with authentication
  Future<void> restore({
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate (verify credentials)
      final userId = await authenticate(
        email: email,
        password: password,
        createIfNotExists: false,
      );

      // Restore settings
      final settingsDoc = await _userCollection(
        userId,
        'settings',
      ).doc('default').get();
      if (settingsDoc.exists) {
        final data = settingsDoc.data()!;
        final bedtimeMap = data['bedtime'] as Map<String, dynamic>?;
        final wakeTimeMap = data['wakeTime'] as Map<String, dynamic>?;

        if (bedtimeMap != null && wakeTimeMap != null) {
          final settings = UserSettings(
            goalHours: (data['goalHours'] ?? 8).toDouble(),
            bedtimeReminderEnabled: data['bedtimeReminderEnabled'] ?? false,
            bedtimeHour: bedtimeMap['h'] as int? ?? 23,
            bedtimeMinute: bedtimeMap['m'] as int? ?? 30,
            wakeTimeHour: wakeTimeMap['h'] as int? ?? 7,
            wakeTimeMinute: wakeTimeMap['m'] as int? ?? 0,
          );

          await _localStorage.saveSettings(settings);
        }
      }

      // Restore all sessions
      final sessionsSnapshot = await _userCollection(
        userId,
        'daily_sleep_sessions',
      ).get();
      final sessions = <SleepSession>[];
      DateTime? todayActiveStart;

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final session = _firestoreToSession(data, doc.id);
        if (session != null) {
          sessions.add(session);

          // If this is today's session, check for active sleep start
          final now = DateTime.now();
          final todayString =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          if (doc.id == todayString) {
            final currentSleepStart = data['currentSleepStart'] as Timestamp?;
            if (currentSleepStart != null) {
              todayActiveStart = currentSleepStart.toDate();
            }
          }
        }
      }

      // Clear existing sessions and restore
      await _localStorage.clearAllSessions();
      if (sessions.isNotEmpty) {
        await _localStorage.saveAllSessions(sessions);
      }

      // Restore active sleep start for today if exists
      if (todayActiveStart != null) {
        await _localStorage.setActiveStart(todayActiveStart);
      }
    } catch (e) {
      throw Exception('Restore failed: $e');
    }
  }

  // Check if backup exists (requires authentication)
  Future<bool> hasBackup({
    required String email,
    required String password,
  }) async {
    try {
      final userId = await authenticate(
        email: email,
        password: password,
        createIfNotExists: false,
      );

      final settingsDoc = await _userCollection(
        userId,
        'settings',
      ).doc('default').get();
      final sessionsSnapshot = await _userCollection(
        userId,
        'daily_sleep_sessions',
      ).limit(1).get();
      return settingsDoc.exists || sessionsSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
