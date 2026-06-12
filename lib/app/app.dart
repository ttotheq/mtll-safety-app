import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/onboarding/onboarding_wizard_screen.dart';
import '../presentation/shell/home_shell.dart';
import '../presentation/unlock/unlock_screen.dart';
import 'providers.dart';

class MtllApp extends StatelessWidget {
  const MtllApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTLL Safety Clearance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A5632)),
        useMaterial3: true,
      ),
      home: const RootGate(),
    );
  }
}

/// First-run routing (W1 trigger): no league on this device → onboarding
/// wizard; league present but no open database → unlock; otherwise the
/// navigation shell.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    if (db != null) {
      return const HomeShell();
    }

    final catalog = ref.watch(leagueCatalogProvider);
    return catalog.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Failed to read league catalog: $error')),
      ),
      data: (entries) => entries.isEmpty
          ? const OnboardingWizardScreen()
          : UnlockScreen(entry: entries.first),
    );
  }
}
