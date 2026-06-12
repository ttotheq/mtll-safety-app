import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// §5.1 Dashboard — S2 ships the W1 empty state: league name plus
/// calls-to-action ("Add a volunteer", "Import from spreadsheet/CSV",
/// "Set up a season"). KPI tiles and rollups arrive with W9/W10 in S6.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(activeLeagueProvider).value;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_baseball_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              league?.name ?? 'Your league',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text('No volunteers yet — get started below.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _comingSoon(
                context,
                'Volunteer intake (W3) arrives in Sprint S4.',
              ),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add a volunteer'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _comingSoon(
                context,
                'CSV import (W4) arrives in a later sprint.',
              ),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import from spreadsheet/CSV'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _comingSoon(
                context,
                'Season setup (W2) arrives in Sprint S3.',
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Set up a season'),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
