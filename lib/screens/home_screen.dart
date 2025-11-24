import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/goal_tracker.dart';
import '../widgets/sleep_card.dart';
import '../services/local_storage_service.dart';
import '../widgets/premium_toast.dart';
import '../models/user_settings.dart';

class HomeScreen extends StatefulWidget {
  final LocalStorageService localStorage;
  const HomeScreen({super.key, required this.localStorage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LocalStorageService service;
  late Future _future;
  DateTime? _activeStart;
  int _accumulatedMinutes =
      0; // Accumulated sleep time from previous periods today
  StreamSubscription<DateTime?>? _activeSub;
  StreamSubscription<UserSettings>? _settingsSub;
  Timer? _ticker;
  String _elapsedLabel = '';
  double _goalHours = 8;

  @override
  void initState() {
    super.initState();
    service = widget.localStorage;
    _future = service.fetchLastNight();
    _loadInitialSettings();
    _loadAccumulatedTime();
    _loadActiveStart();
    _activeSub = service.streamActiveStart().listen((start) {
      if (!mounted) return;
      setState(() => _activeStart = start);
      // Reload accumulated time when sleep state changes
      _loadAccumulatedTime();
      _updateTicker();
    });
    _settingsSub = service.streamSettings().listen((settings) {
      if (!mounted) return;
      setState(() => _goalHours = settings.goalHours);
    });
  }

  void _loadActiveStart() {
    final activeStart = service.getActiveStart();
    if (mounted) {
      setState(() => _activeStart = activeStart);
      _updateTicker();
    }
  }

  Future<void> _loadInitialSettings() async {
    final settings = service.getSettings();
    if (mounted) {
      setState(() => _goalHours = settings.goalHours);
    }
  }

  Future<void> _loadAccumulatedTime() async {
    final accumulated = await service.getAccumulatedSleepMinutes();
    if (mounted) {
      setState(() => _accumulatedMinutes = accumulated);
      _updateTicker(); // Update display with new accumulated time
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _activeSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }

  void _updateTicker() {
    _ticker?.cancel();
    if (_activeStart == null) {
      // Not sleeping, clear elapsed label
      if (mounted) {
        setState(() => _elapsedLabel = '');
      }
      return;
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Calculate current sleep period duration in seconds for accuracy
      final currentPeriodDiff = DateTime.now().difference(_activeStart!);
      final currentPeriodSeconds = currentPeriodDiff.inSeconds;
      // Convert to minutes (round up to match calculation)
      final currentPeriodMinutes = currentPeriodSeconds > 0
          ? (currentPeriodSeconds / 60).ceil()
          : 0;

      // Total sleep time = accumulated (from previous periods) + current period
      // This ensures all sleep periods in the day are added together
      final totalMinutes = _accumulatedMinutes + currentPeriodMinutes;
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;

      setState(() => _elapsedLabel = '${h}h ${m}m');
    });
  }

  Future<void> _toggle() async {
    if (_activeStart == null) {
      // Starting sleep - resume today's session
      // IMPORTANT: Reload accumulated time FIRST to ensure we have the latest total
      // This ensures that if the user paused and is resuming, we have the correct accumulated time
      await _loadAccumulatedTime();

      final optimisticStart = DateTime.now();
      if (mounted) setState(() => _activeStart = optimisticStart);
      _updateTicker();
      try {
        await service.startSleep(optimisticStart);
        // Reload again after starting to sync
        await _loadAccumulatedTime();
        if (!mounted) return;
        final totalMinutes = _accumulatedMinutes;
        showPremiumToast(
          context,
          message:
              'Sleep started. Total today: ${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
          type: ToastType.success,
          icon: Icons.nightlight_round,
          duration: const Duration(seconds: 2),
        );
      } catch (e) {
        if (mounted) setState(() => _activeStart = null);
        _updateTicker();
        if (!mounted) return;
        showPremiumToast(
          context,
          message: 'Failed to start: $e',
          type: ToastType.error,
          icon: Icons.error_outline_rounded,
        );
      }
    } else {
      // Stopping/pausing sleep - accumulate time but keep session open
      final optimisticStop = DateTime.now();
      final prev = _activeStart;
      final prevAccumulated =
          _accumulatedMinutes; // Store previous accumulated time
      if (mounted) setState(() => _activeStart = null);
      _updateTicker();
      try {
        await service.stopSleep(optimisticStop);
        // CRITICAL: Reload accumulated time after stopping
        // This ensures we have the latest accumulated total that includes this sleep period
        await _loadAccumulatedTime();
        if (mounted) {
          setState(() {
            _future = service.fetchLastNight();
          });
          // Show accumulated time in toast for user feedback
          final currentAccumulated = _accumulatedMinutes;
          final addedMinutes = currentAccumulated - prevAccumulated;
          showPremiumToast(
            context,
            message:
                'Sleep paused. Total today: ${currentAccumulated ~/ 60}h ${currentAccumulated % 60}m (+${addedMinutes}m)',
            type: ToastType.info,
            icon: Icons.pause_circle_outline_rounded,
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _activeStart = prev;
            _accumulatedMinutes =
                prevAccumulated; // Restore previous accumulated time
          });
        }
        _updateTicker();
        if (!mounted) return;
        showPremiumToast(
          context,
          message: 'Failed to stop: $e',
          type: ToastType.error,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _activeStart != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: Gaps.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with moon logo and star
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.nightlight_round,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      Positioned(
                        top: 6,
                        right: 8,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'SleepSync',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Track your sleep patterns',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Center circular display and button
            Center(
              child: GoalTracker(
                goalHours: _goalHours,
                isRunning: isRunning,
                elapsedLabel: isRunning ? _elapsedLabel : null,
                onPrimary: _toggle,
              ),
            ),
            const SizedBox(height: 16),
            // Status label
            Center(
              child: Text(
                isRunning ? 'Currently Sleeping' : 'Currently Awake',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Last Night's Sleep section
            const Text(
              "Last Night's Sleep",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data;
                if (data == null) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No data yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return SleepCard(data: data);
              },
            ),
          ],
        ),
      ),
    );
  }
}
