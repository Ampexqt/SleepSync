import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/weekly_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'widgets/custom_bottom_nav.dart';
import 'services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SleepSyncApp());
}

class SleepSyncApp extends StatelessWidget {
  const SleepSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SleepSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.card,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          bodySmall: TextStyle(color: AppColors.textTertiary),
        ),
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final LocalStorageService _localStorage = LocalStorageService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Show splash screen for at least 2.5 seconds
    final initStart = DateTime.now();

    // Initialize storage
    await _localStorage.init();

    // Calculate elapsed time
    final elapsed = DateTime.now().difference(initStart);
    final minDelay = const Duration(seconds: 2, milliseconds: 500);

    // Wait for remaining time if initialization was too fast
    if (elapsed < minDelay) {
      await Future.delayed(minDelay - elapsed);
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SplashScreen();
    }

    return _Root(localStorage: _localStorage);
  }
}

class _Root extends StatefulWidget {
  final LocalStorageService localStorage;
  const _Root({required this.localStorage});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  int _index = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(localStorage: widget.localStorage),
      WeeklyScreen(localStorage: widget.localStorage),
      SettingsScreen(localStorage: widget.localStorage),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
      ),
    );
  }
}
