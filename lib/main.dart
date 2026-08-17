import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'core/rest_notifications.dart';
import 'core/app_theme.dart';
import 'ui/app_shell.dart';
import 'ui/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RestNotifications.instance.initialize();
  runApp(const ProviderScope(child: ZenTrackrApp()));
}

class ZenTrackrApp extends ConsumerWidget {
  const ZenTrackrApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.valueOrNull;
    return MaterialApp(
      title: 'ZenTrackr',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.light(),
      home: settingsState.hasError
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not open local data:\n${settingsState.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : settings == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : settings.onboardingComplete
          ? const AppShell()
          : const OnboardingScreen(),
    );
  }
}
