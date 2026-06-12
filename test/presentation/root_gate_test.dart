import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/app/app.dart';
import 'package:mtll_safety_app/app/database_gateway.dart';
import 'package:mtll_safety_app/app/providers.dart';
import 'package:mtll_safety_app/presentation/onboarding/onboarding_wizard_screen.dart';
import 'package:mtll_safety_app/presentation/unlock/unlock_screen.dart';

Widget _app(DatabaseGateway gateway) => ProviderScope(
  overrides: [databaseGatewayProvider.overrideWithValue(gateway)],
  child: const MtllApp(),
);

void main() {
  testWidgets('first run (no league) routes to the onboarding wizard', (
    tester,
  ) async {
    await tester.pumpWidget(_app(InMemoryDatabaseGateway()));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingWizardScreen), findsOneWidget);
  });

  testWidgets('existing league routes to the unlock screen', (tester) async {
    final gateway = InMemoryDatabaseGateway();
    await gateway.createLeagueDatabase(
      stem: 'existing',
      leagueName: 'Existing League',
      pin: '111111',
      shortName: 'MTLL',
    );

    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(find.text('Existing League'), findsOneWidget);
  });
}
