import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/app/app.dart';
import 'package:mtll_safety_app/app/database_gateway.dart';
import 'package:mtll_safety_app/app/providers.dart';
import 'package:mtll_safety_app/presentation/onboarding/onboarding_wizard_screen.dart';
import 'package:mtll_safety_app/security/kdf_params.dart';
import 'package:mtll_safety_app/security/passcode_hasher.dart';

// Tiny Argon2id params keep widget tests fast; production defaults apply
// outside tests.
final _testHasher = PasscodeHasher(
  params: const KdfParams(memoryKiB: 64, iterations: 1, parallelism: 1),
);

Widget _app(InMemoryDatabaseGateway gateway) => ProviderScope(
  overrides: [
    databaseGatewayProvider.overrideWithValue(gateway),
    passcodeHasherProvider.overrideWithValue(_testHasher),
  ],
  child: const MtllApp(),
);

Future<void> _completeProfileStep(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('league-name')),
    'Mission Trails Little League',
  );
  await tester.ensureVisible(find.byKey(const Key('wizard-continue-0')));
  await tester.tap(find.byKey(const Key('wizard-continue-0')));
  await tester.pumpAndSettle();
}

Future<void> _completeDivisionsStep(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(CheckboxListTile, 'Majors'));
  await tester.tap(find.widgetWithText(CheckboxListTile, 'Majors'));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('wizard-continue-1')));
  await tester.tap(find.byKey(const Key('wizard-continue-1')));
  await tester.pumpAndSettle();
}

Future<void> _completeOwnerStep(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('owner-name')), 'Ty Quan');
  await tester.enterText(
    find.byKey(const Key('owner-email')),
    'safety@mtll.org',
  );
  await tester.enterText(find.byKey(const Key('owner-pin')), '482913');
  await tester.enterText(find.byKey(const Key('owner-pin-confirm')), '482913');
  await tester.ensureVisible(find.byKey(const Key('wizard-continue-2')));
  await tester.tap(find.byKey(const Key('wizard-continue-2')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    'W1 happy path lands on the empty Dashboard with league name and CTAs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final gateway = InMemoryDatabaseGateway();
      await tester.pumpWidget(_app(gateway));
      await tester.pumpAndSettle();

      expect(find.text('Welcome — set up your league'), findsOneWidget);

      await _completeProfileStep(tester);
      await _completeDivisionsStep(tester);
      await _completeOwnerStep(tester);

      // W1 step 8 — season-or-dashboard prompt.
      expect(find.text('League created'), findsOneWidget);
      await tester.tap(find.text('Skip to Dashboard'));
      await tester.pumpAndSettle();

      // W1 AC-1 — Dashboard shows the league name and empty-state CTAs.
      expect(find.text('Mission Trails Little League'), findsWidgets);
      expect(find.text('Add a volunteer'), findsOneWidget);
      expect(find.text('Import from spreadsheet/CSV'), findsOneWidget);

      // Postconditions — 9 roles with correct flags, AuditLog CREATE for
      // the League row.
      final element = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(element, listen: false);
      final db = container.read(appDatabaseProvider)!;

      final roles = await db.select(db.roles).get();
      expect(roles, hasLength(9));
      final juniorUmpire = roles.singleWhere(
        (role) => role.name == 'Junior Umpire',
      );
      expect(juniorUmpire.permitsMinor, isTrue);
      expect(juniorUmpire.isOnField, isTrue);
      final manager = roles.singleWhere((role) => role.name == 'Manager');
      expect(manager.permitsMinor, isFalse);

      final leagueAudits = await (db.select(
        db.auditLogs,
      )..where((audit) => audit.entity.equals('League'))).get();
      expect(leagueAudits, hasLength(1));
      expect(leagueAudits.single.action, 'CREATE');
    },
  );

  testWidgets('AF-3: zero divisions blocks submission with an error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(InMemoryDatabaseGateway()));
    await tester.pumpAndSettle();

    await _completeProfileStep(tester);

    // Continue without selecting any division.
    await tester.ensureVisible(find.byKey(const Key('wizard-continue-1')));
    await tester.tap(find.byKey(const Key('wizard-continue-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('Select at least one division to continue.'),
      findsOneWidget,
    );
    // Still on the divisions step — owner fields not reachable yet.
    expect(find.text('League created'), findsNothing);
  });

  testWidgets('AF-4: missing league name blocks step 1 inline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(InMemoryDatabaseGateway()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('wizard-continue-0')));
    await tester.tap(find.byKey(const Key('wizard-continue-0')));
    await tester.pumpAndSettle();

    expect(find.text('League name is required'), findsOneWidget);
  });

  testWidgets('AF-1: duplicate short name warns and does not proceed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final gateway = InMemoryDatabaseGateway();
    await gateway.createLeagueDatabase(
      stem: 'existing',
      leagueName: 'Existing League',
      pin: '111111',
      shortName: 'MTLL',
    );

    // Drive the wizard directly — through RootGate an existing league
    // routes to unlock; AF-1 covers creating a second league tenant.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseGatewayProvider.overrideWithValue(gateway),
          passcodeHasherProvider.overrideWithValue(_testHasher),
        ],
        child: const MaterialApp(home: OnboardingWizardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('league-name')),
      'Second League',
    );
    await tester.enterText(find.byKey(const Key('short-name')), 'MTLL');
    await tester.ensureVisible(find.byKey(const Key('wizard-continue-0')));
    await tester.tap(find.byKey(const Key('wizard-continue-0')));
    await tester.pumpAndSettle();

    await _completeDivisionsStep(tester);
    await _completeOwnerStep(tester);

    expect(find.text('Short name already in use'), findsOneWidget);
    expect(find.text('League created'), findsNothing);
    // Only the pre-existing league is in the catalog — no duplicate row.
    expect(await gateway.listLeagues(), hasLength(1));
  });
}
