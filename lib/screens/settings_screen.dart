import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/helpers.dart';
import '../widgets/premium_toast.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onSignOut;
  const SettingsScreen({
    super.key,
    required this.authService,
    required this.onSignOut,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final FirestoreService _service;
  UserSettingsState? state;

  @override
  void initState() {
    super.initState();
    _service = FirestoreService(widget.authService);
    _load();
  }

  Future<void> _load() async {
    final s = await _service.fetchSettings();
    setState(() => state = s ?? UserSettingsState(
      goalHours: 8,
      bedtimeReminderEnabled: false,
      bedtime: const TimeOfDay(hour: 23, minute: 30),
      wakeTime: const TimeOfDay(hour: 7, minute: 0),
    ));
  }

  Future<void> _save() async {
    if (state != null) await _service.updateSettings(state!);
  }

  Future<void> _saveWithSnack() async {
    await _save();
    if (!mounted) return;
    showPremiumToast(
      context,
      message: 'Settings saved',
      type: ToastType.success,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: Gaps.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                _pillButton(
                  icon: Icons.save,
                  label: 'Save',
                  onPressed: _saveWithSnack,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Customize your sleep tracking',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.nightlight_round, 'Sleep Goal'),
                  const SizedBox(height: 6),
                  const Text(
                    'Set how long you aim to sleep each night.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: s.goalHours,
                    min: 5,
                    max: 12,
                    divisions: 7,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => state = s.copyWith(goalHours: v)),
                    onChangeEnd: (_) => _save(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('5h', style: TextStyle(color: AppColors.textTertiary)),
                      Text('8h', style: TextStyle(color: AppColors.textTertiary)),
                      Text('12h', style: TextStyle(color: AppColors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current goal', style: TextStyle(color: AppColors.textTertiary)),
                      Text('${s.goalHours.toStringAsFixed(0)} hours', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.notifications_none, 'Bedtime Reminder'),
                  const SizedBox(height: 6),
                  const Text(
                    'Get nudged when it’s time to wind down.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable reminder', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Send a bedtime notification', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    value: s.bedtimeReminderEnabled,
                    onChanged: (v) {
                      setState(() => state = s.copyWith(bedtimeReminderEnabled: v));
                      _save();
                    },
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  const Text('Remind me at', style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 8),
                  _timeDropdown(
                    value: s.bedtime,
                    onChanged: (t) {
                      setState(() => state = s.copyWith(bedtime: t));
                      _save();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.wb_sunny_outlined, 'Wake Up Time'),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose the morning window you’d like to hit.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _timeDropdown(
                    value: s.wakeTime,
                    onChanged: (t) {
                      setState(() => state = s.copyWith(wakeTime: t));
                      _save();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Sign out button
            _card(
              child: Column(
                children: [
                  _sectionTitle(Icons.logout, 'Account'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await widget.authService.signOut();
                        // Notify parent to update auth state
                        widget.onSignOut();
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: AppColors.primary, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.ring),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _timeDropdown({required TimeOfDay value, required ValueChanged<TimeOfDay> onChanged}) {
    final times = List.generate(24 * 2, (i) {
      final hour = i ~/ 2;
      final minute = (i % 2) * 30;
      return TimeOfDay(hour: hour, minute: minute);
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ring),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<TimeOfDay>(
        isExpanded: true,
        underline: const SizedBox.shrink(),
        value: value,
        iconEnabledColor: AppColors.textSecondary,
        dropdownColor: AppColors.background,
        items: times
            .map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(formatTimeOfDay(t), style: const TextStyle(color: AppColors.textPrimary)),
                ))
            .toList(),
        onChanged: (t) {
          if (t != null) onChanged(t);
        },
      ),
    );
  }
}
