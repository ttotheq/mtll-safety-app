import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/database_gateway.dart';
import '../../app/providers.dart';
import '../../data/repositories/session_context.dart';
import '../shell/home_shell.dart';

/// Minimal PIN unlock for subsequent launches: derives the SQLCipher key
/// from the PIN (§6.1.1), opens the league database, and verifies the PIN
/// against User.local_passcode_hash (§6.5.2). The full §6.5.1 sealed
/// AuthenticationCoordinator state machine and biometric unlock land with
/// later auth work; this screen covers the PIN path only.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key, required this.entry});

  final LeagueCatalogEntry entry;

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.entry.name,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pin,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  errorText: _error,
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final gateway = ref.read(databaseGatewayProvider);
      final db = await gateway.openLeagueDatabase(
        stem: widget.entry.stem,
        pin: _pin.text,
      );

      try {
        // A wrong key surfaces here as a SQLCipher read failure. No session
        // exists yet to tenant-filter by; the §6.3.1 file boundary is the
        // tenancy boundary for this single-league database.
        // ignore: cross_tenant_query
        final users = await db.select(db.users).get();
        final hasher = ref.read(passcodeHasherProvider);
        final owner = users
            .where(
              (user) =>
                  user.localPasscodeHash != null &&
                  hasher.verify(_pin.text, user.localPasscodeHash!),
            )
            .firstOrNull;
        if (owner == null) {
          await db.close();
          setState(() => _error = 'Incorrect PIN');
          return;
        }

        ref.read(appDatabaseProvider.notifier).state = db;
        ref.read(sessionContextProvider.notifier).state = SessionContext(
          leagueId: owner.leagueId,
          userId: owner.id,
          role: UserRole.fromWire(owner.role),
        );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeShell()),
        );
      } catch (_) {
        await db.close();
        rethrow;
      }
    } catch (_) {
      setState(() => _error = 'Incorrect PIN');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
