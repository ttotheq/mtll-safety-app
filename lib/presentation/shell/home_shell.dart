import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../dashboard/dashboard_screen.dart';
import 'placeholder_screen.dart';

/// §5.0.1 global navigation: persistent rail on desktop (>=600dp), bottom
/// navigation bar on mobile (<600dp). Active Season surfaced in the top bar.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  /// §5.0.1 responsive breakpoint between rail and bottom navigation.
  static const railBreakpointDp = 600.0;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _Destination {
  const _Destination(this.label, this.icon, this.body);

  final String label;
  final IconData icon;
  final Widget body;
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selected = 0;

  static const _destinations = [
    _Destination('Dashboard', Icons.dashboard_outlined, DashboardScreen()),
    _Destination(
      'Volunteers',
      Icons.people_outlined,
      PlaceholderScreen(
        title: 'Volunteers',
        detail: 'Volunteer List (5.2) arrives in Sprint S4.',
      ),
    ),
    _Destination(
      'Teams',
      Icons.groups_outlined,
      PlaceholderScreen(
        title: 'Teams',
        detail: 'Team Detail (5.4) arrives in Sprint S3+.',
      ),
    ),
    _Destination(
      'Clearances',
      Icons.verified_outlined,
      PlaceholderScreen(
        title: 'Clearances',
        detail: 'Clearance-by-Type (5.5) arrives in Sprint S5.',
      ),
    ),
    _Destination(
      'Matrix',
      Icons.grid_on_outlined,
      PlaceholderScreen(
        title: 'Matrix',
        detail: 'Requirements Matrix Editor (5.6) arrives in Sprint S3.',
      ),
    ),
    _Destination(
      'Settings',
      Icons.settings_outlined,
      PlaceholderScreen(
        title: 'Settings',
        detail: 'Admin Configuration Portal (5.9) arrives in Sprint S7.',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final league = ref.watch(activeLeagueProvider).value;
    final body = _destinations[_selected].body;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= HomeShell.railBreakpointDp;

        void volunteerComingSoon() =>
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Volunteer intake (W3) arrives in Sprint S4.'),
              ),
            );

        final appBar = AppBar(
          title: Text(league?.name ?? 'MTLL Safety Clearance'),
          actions: [
            _SeasonSelector(compact: !useRail),
            const SizedBox(width: 8),
            if (useRail)
              FilledButton.tonalIcon(
                onPressed: volunteerComingSoon,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Volunteer'),
              )
            else
              IconButton(
                onPressed: volunteerComingSoon,
                tooltip: 'Add volunteer',
                icon: const Icon(Icons.person_add_alt),
              ),
            const SizedBox(width: 16),
          ],
        );

        if (useRail) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selected,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) =>
                      setState(() => _selected = index),
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selected,
            onDestinationSelected: (index) => setState(() => _selected = index),
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  label: destination.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// §5.0.1 top-bar Season selector. Empty until W2 (Sprint S3) creates the
/// first season; offers the "Set up a season" call-to-action meanwhile.
class _SeasonSelector extends ConsumerWidget {
  const _SeasonSelector({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = ref.watch(seasonsProvider).value ?? const [];

    if (seasons.isEmpty) {
      void seasonComingSoon() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Season setup (W2) arrives in Sprint S3.'),
        ),
      );

      if (compact) {
        return IconButton(
          onPressed: seasonComingSoon,
          tooltip: 'No season — set up',
          icon: const Icon(Icons.calendar_today_outlined),
        );
      }
      return TextButton.icon(
        onPressed: seasonComingSoon,
        icon: const Icon(Icons.calendar_today_outlined),
        label: const Text('No season — set up'),
      );
    }

    return DropdownButton<String>(
      value: seasons.first.id,
      onChanged: (_) {},
      items: [
        for (final season in seasons)
          DropdownMenuItem(value: season.id, child: Text(season.name)),
      ],
    );
  }
}
