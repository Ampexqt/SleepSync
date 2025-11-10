import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum ToastType { success, info, error }

class PremiumToast extends StatelessWidget {
  final String message;
  final ToastType type;
  final IconData? icon;

  const PremiumToast({
    super.key,
    required this.message,
    this.type = ToastType.info,
    this.icon,
  });

  IconData get _defaultIcon {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  Color get _iconColor {
    switch (type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
        return const Color(0xFFFF6B6B);
      case ToastType.info:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: _iconColor.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _iconColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.card.withOpacity(0.98),
                  AppColors.card,
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _iconColor.withOpacity(0.25),
                        _iconColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _iconColor.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon ?? _defaultIcon,
                    color: _iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToastHelper {
  static OverlayEntry? _overlayEntry;
  static OverlayState? _overlayState;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Hide any existing toast
    hide();

    try {
      _overlayState = Overlay.of(context, rootOverlay: true);
      if (_overlayState == null) return;

      _overlayEntry = OverlayEntry(
        builder: (context) => _ToastOverlay(
          message: message,
          type: type,
          icon: icon,
          duration: duration,
        ),
        maintainState: false,
      );

      _overlayState!.insert(_overlayEntry!);

      // Auto hide after duration
      _timer = Timer(duration + const Duration(milliseconds: 300), () {
        hide();
      });
    } catch (e) {
      // If overlay is not available, fallback silently
      debugPrint('ToastHelper: Failed to show toast - $e');
    }
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    try {
      _overlayEntry?.remove();
    } catch (e) {
      // Entry might already be removed
      debugPrint('ToastHelper: Error hiding toast - $e');
    }
    _overlayEntry = null;
    _overlayState = null;
  }
}

class _ToastOverlay extends StatefulWidget {
  final String message;
  final ToastType type;
  final IconData? icon;
  final Duration duration;

  const _ToastOverlay({
    required this.message,
    required this.type,
    this.icon,
    required this.duration,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Start hide animation near the end
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          ToastHelper.hide();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: PremiumToast(
                message: widget.message,
                type: widget.type,
                icon: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function for easy access
void showPremiumToast(
  BuildContext context, {
  required String message,
  ToastType type = ToastType.info,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  ToastHelper.show(
    context,
    message: message,
    type: type,
    icon: icon,
    duration: duration,
  );
}

