import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/local_storage_service.dart';
import '../services/backup_service.dart';
import '../widgets/premium_toast.dart';
import '../widgets/auth_dialog.dart';
import '../models/user_settings.dart';

class SettingsScreen extends StatefulWidget {
  final LocalStorageService localStorage;
  const SettingsScreen({super.key, required this.localStorage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final LocalStorageService _service;
  late final BackupService _backupService;
  UserSettings? state;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _service = widget.localStorage;
    _backupService = BackupService(_service);
    _load();
  }

  Future<void> _load() async {
    final s = _service.getSettings();
    setState(() => state = s);
  }

  Future<void> _save() async {
    if (state != null) await _service.saveSettings(state!);
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

  Future<void> _handleBackup() async {
    // Show auth dialog
    final credentials = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AuthDialog(
        title: 'Backup to Cloud',
        message:
            'Enter your email and password to backup your data. If the account doesn\'t exist, it will be created.',
        showSignUpOption: true,
      ),
    );

    if (credentials == null || !mounted) return;

    final email = credentials['email'];
    final password = credentials['password'];

    if (email == null || password == null) return;

    setState(() => _isBackingUp = true);
    try {
      await _backupService.backup(email: email, password: password);
      if (!mounted) return;
      showPremiumToast(
        context,
        message: 'Backup completed successfully',
        type: ToastType.success,
        icon: Icons.cloud_done_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      showPremiumToast(
        context,
        message:
            'Backup failed: ${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    // Show auth dialog first
    final credentials = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AuthDialog(
        title: 'Restore from Cloud',
        message: 'Enter your email and password to restore your backup data.',
        showSignUpOption: false,
      ),
    );

    if (credentials == null || !mounted) return;

    final email = credentials['email'];
    final password = credentials['password'];

    if (email == null || password == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Restore from Backup',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will replace all your current data with the backup. Are you sure?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Restore',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    try {
      await _backupService.restore(email: email, password: password);
      await _load(); // Reload settings after restore
      if (!mounted) return;
      showPremiumToast(
        context,
        message: 'Restore completed successfully',
        type: ToastType.success,
        icon: Icons.cloud_download_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      showPremiumToast(
        context,
        message:
            'Restore failed: ${e.toString().replaceFirst('Exception: ', '')}',
        type: ToastType.error,
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: s.goalHours,
                    min: 5,
                    max: 12,
                    divisions: 7,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => state = s.copyWith(goalHours: v)),
                    onChangeEnd: (_) => _save(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        '5h',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      Text(
                        '8h',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      Text(
                        '12h',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current goal',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      Text(
                        '${s.goalHours.toStringAsFixed(0)} hours',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
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
                  _sectionTitle(Icons.cloud_upload_rounded, 'Backup & Restore'),
                  const SizedBox(height: 6),
                  const Text(
                    'Backup your data to cloud or restore from backup.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isBackingUp ? null : _handleBackup,
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _isBackingUp ? 'Backing up...' : 'Backup',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isRestoring ? null : _handleRestore,
                          icon: _isRestoring
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_download_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _isRestoring ? 'Restoring...' : 'Restore',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.card,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.ring),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
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
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
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
}
