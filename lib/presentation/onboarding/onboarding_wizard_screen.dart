import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../data/database/seeds/division_seed_data.dart';
import '../../data/repositories/league_onboarding_repository.dart';
import '../../data/repositories/session_context.dart';
import '../shell/home_shell.dart';

/// W1 — League Onboarding wizard (EXECUTION-PLAN W1 main flow steps 1–8).
/// Three steps: league profile, divisions, owner account + PIN.
class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _ownerFormKey = GlobalKey<FormState>();

  final _leagueName = TextEditingController();
  final _shortName = TextEditingController();
  final _district = TextEditingController();
  final _charterNumber = TextEditingController();
  final _timezone = TextEditingController(text: 'America/Los_Angeles');
  final _contactName = TextEditingController();
  final _contactEmail = TextEditingController();
  final _contactPhone = TextEditingController();
  final _primaryColorHex = TextEditingController();
  final _customDivision = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  String? _divisionError;

  // Preset divisions (W1 step 3) keyed by name; custom rows appended.
  late final Map<String, bool> _selectedDivisions = {
    for (final seed in defaultDivisionSeeds) seed.name: false,
  };
  final List<String> _customDivisions = [];

  @override
  void dispose() {
    for (final controller in [
      _leagueName,
      _shortName,
      _district,
      _charterNumber,
      _timezone,
      _contactName,
      _contactEmail,
      _contactPhone,
      _primaryColorHex,
      _customDivision,
      _ownerName,
      _ownerEmail,
      _pin,
      _pinConfirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome — set up your league')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: _submitting ? null : _onContinue,
        onStepCancel: _step == 0 || _submitting
            ? null
            : () => setState(() => _step -= 1),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              FilledButton(
                key: Key('wizard-continue-${details.stepIndex}'),
                onPressed: details.onStepContinue,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_step == 2 ? 'Create league' : 'Continue'),
              ),
              const SizedBox(width: 12),
              if (_step > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('League profile'),
            isActive: _step >= 0,
            content: _profileStep(),
          ),
          Step(
            title: const Text('Divisions'),
            isActive: _step >= 1,
            content: _divisionsStep(),
          ),
          Step(
            title: const Text('Owner account'),
            isActive: _step >= 2,
            content: _ownerStep(),
          ),
        ],
      ),
    );
  }

  Widget _profileStep() {
    return Form(
      key: _profileFormKey,
      child: Column(
        children: [
          TextFormField(
            key: const Key('league-name'),
            controller: _leagueName,
            decoration: const InputDecoration(labelText: 'League name *'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'League name is required'
                : null,
          ),
          TextFormField(
            key: const Key('short-name'),
            controller: _shortName,
            decoration: const InputDecoration(
              labelText: 'Short name',
              helperText: 'Used to identify this league on this device',
            ),
          ),
          TextFormField(
            controller: _district,
            decoration: const InputDecoration(labelText: 'District'),
          ),
          TextFormField(
            controller: _charterNumber,
            decoration: const InputDecoration(labelText: 'Charter number'),
          ),
          TextFormField(
            controller: _timezone,
            decoration: const InputDecoration(labelText: 'Timezone'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Timezone is required'
                : null,
          ),
          TextFormField(
            controller: _contactName,
            decoration: const InputDecoration(labelText: 'Contact name'),
          ),
          TextFormField(
            controller: _contactEmail,
            decoration: const InputDecoration(labelText: 'Contact email'),
            validator: _optionalEmail,
          ),
          TextFormField(
            controller: _contactPhone,
            decoration: const InputDecoration(labelText: 'Contact phone'),
          ),
          TextFormField(
            controller: _primaryColorHex,
            decoration: const InputDecoration(
              labelText: 'Primary color (hex)',
              hintText: '#1A5632',
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return null;
              }
              return RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(trimmed)
                  ? null
                  : 'Use a 6-digit hex color like #1A5632';
            },
          ),
        ],
      ),
    );
  }

  Widget _divisionsStep() {
    final names = [..._selectedDivisions.keys];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select the divisions your league runs (at least one).'),
        for (final name in names)
          CheckboxListTile(
            title: Text(name),
            value: _selectedDivisions[name],
            onChanged: (checked) => setState(() {
              _selectedDivisions[name] = checked ?? false;
              _divisionError = null;
            }),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customDivision,
                decoration: const InputDecoration(
                  labelText: 'Add custom division',
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                final name = _customDivision.text.trim();
                if (name.isEmpty || _selectedDivisions.containsKey(name)) {
                  return;
                }
                setState(() {
                  _selectedDivisions[name] = true;
                  _customDivisions.add(name);
                  _customDivision.clear();
                  _divisionError = null;
                });
              },
              child: const Text('Add'),
            ),
          ],
        ),
        if (_divisionError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _divisionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _ownerStep() {
    return Form(
      key: _ownerFormKey,
      child: Column(
        children: [
          TextFormField(
            key: const Key('owner-name'),
            controller: _ownerName,
            decoration: const InputDecoration(labelText: 'Your name *'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Owner name is required'
                : null,
          ),
          TextFormField(
            key: const Key('owner-email'),
            controller: _ownerEmail,
            decoration: const InputDecoration(labelText: 'Your email *'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Owner email is required';
              }
              return _optionalEmail(value);
            },
          ),
          TextFormField(
            key: const Key('owner-pin'),
            controller: _pin,
            decoration: const InputDecoration(
              labelText: '6-digit PIN *',
              helperText:
                  'Unlocks this league on this device. If you forget it, '
                  'the data is only recoverable from a backup.',
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                ? null
                : 'PIN must be exactly 6 digits',
          ),
          TextFormField(
            key: const Key('owner-pin-confirm'),
            controller: _pinConfirm,
            decoration: const InputDecoration(labelText: 'Confirm PIN *'),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            validator: (value) =>
                value == _pin.text ? null : 'PINs do not match',
          ),
        ],
      ),
    );
  }

  String? _optionalEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)
        ? null
        : 'Enter a valid email address';
  }

  Future<void> _onContinue() async {
    switch (_step) {
      case 0:
        if (_profileFormKey.currentState!.validate()) {
          setState(() => _step = 1);
        }
      case 1:
        if (_selectedDivisions.values.every((selected) => !selected)) {
          setState(
            () => _divisionError = 'Select at least one division to continue.',
          );
        } else {
          setState(() => _step = 2);
        }
      case 2:
        if (_ownerFormKey.currentState!.validate()) {
          await _submit();
        }
    }
  }

  Future<void> _submit() async {
    final gateway = ref.read(databaseGatewayProvider);
    final shortName = _shortName.text.trim();

    // W1 AF-1 — short_name collision with an existing local database.
    if (shortName.isNotEmpty && await gateway.shortNameExists(shortName)) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Short name already in use'),
          content: Text(
            'A league with the short name "$shortName" already exists on '
            'this device. Rename this league or open the existing one.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final leagueId = const Uuid().v7();
      final db = await gateway.createLeagueDatabase(
        stem: leagueId,
        leagueName: _leagueName.text.trim(),
        pin: _pin.text,
        shortName: shortName.isEmpty ? null : shortName,
      );
      ref.read(appDatabaseProvider.notifier).state = db;

      final hasher = ref.read(passcodeHasherProvider);
      final result = await LeagueOnboardingRepository(db: db).bootstrapLeague(
        leagueId: leagueId,
        leagueName: _leagueName.text.trim(),
        divisions: _divisionInputs(),
        ownerEmail: _ownerEmail.text.trim(),
        ownerName: _ownerName.text.trim(),
        ownerPasscodeHash: hasher.hash(_pin.text),
        shortName: shortName.isEmpty ? null : shortName,
        district: _district.text,
        charterNumber: _charterNumber.text,
        timezone: _timezone.text.trim(),
        contactName: _contactName.text,
        contactEmail: _contactEmail.text,
        contactPhone: _contactPhone.text,
        primaryColorHex: _primaryColorHex.text,
      );

      ref.read(sessionContextProvider.notifier).state = SessionContext(
        leagueId: result.leagueId,
        userId: result.ownerUserId,
        role: UserRole.owner,
      );

      if (!mounted) {
        return;
      }
      // W1 step 8 — offer Season setup (W2) or skip to the empty Dashboard.
      final setUpSeason = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('League created'),
          content: const Text(
            'Would you like to set up your first season '
            'now, or go to the Dashboard?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip to Dashboard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Set up season'),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      );
      if (setUpSeason == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Season setup (W2) arrives in Sprint S3 — starting on the '
              'Dashboard for now.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  List<OnboardingDivisionInput> _divisionInputs() {
    final inputs = <OnboardingDivisionInput>[];
    var sortOrder = 10;
    for (final seed in defaultDivisionSeeds) {
      if (_selectedDivisions[seed.name] == true) {
        inputs.add(
          OnboardingDivisionInput(
            name: seed.name,
            sortOrder: seed.sortOrder,
            ageMin: seed.ageMin,
            ageMax: seed.ageMax,
          ),
        );
      }
      sortOrder = seed.sortOrder + 10;
    }
    for (final custom in _customDivisions) {
      if (_selectedDivisions[custom] == true) {
        inputs.add(OnboardingDivisionInput(name: custom, sortOrder: sortOrder));
        sortOrder += 10;
      }
    }
    return inputs;
  }
}
