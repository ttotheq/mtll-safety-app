import 'package:flutter_test/flutter_test.dart';
import 'package:mtll_safety_app/security/kdf_params.dart';

void main() {
  group('KdfParams', () {
    test('floor matches the §6.1.1 minimums', () {
      expect(KdfParams.floor.memoryKiB, 64 * 1024);
      expect(KdfParams.floor.iterations, 3);
      expect(KdfParams.floor.parallelism, 1);
      expect(KdfParams.floor.outputLength, 32);
    });

    test('encode/decode round-trips', () {
      const params = KdfParams(
        memoryKiB: 128 * 1024,
        iterations: 3,
        parallelism: 1,
      );

      expect(KdfParams.decode(params.encode()), params);
    });
  });

  group('tuneKdfParams', () {
    test('keeps the floor when derivation already takes >= 200ms', () {
      final measured = <KdfParams>[];

      final tuned = tuneKdfParams(
        measure: (params) {
          measured.add(params);
          return const Duration(milliseconds: 250);
        },
      );

      expect(tuned, KdfParams.floor);
      expect(measured, hasLength(1));
    });

    test('ratchets to 128 MiB when that rung meets the 300ms target', () {
      final durations = [
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 350),
      ];
      var call = 0;

      final tuned = tuneKdfParams(measure: (_) => durations[call++]);

      expect(tuned.memoryKiB, 128 * 1024);
      expect(call, 2);
    });

    test('ratchets to 256 MiB when 128 MiB is still under target', () {
      final durations = [
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 250),
        const Duration(milliseconds: 400),
      ];
      var call = 0;

      final tuned = tuneKdfParams(measure: (_) => durations[call++]);

      expect(tuned.memoryKiB, 256 * 1024);
    });

    test('stops at the top rung even when still under target', () {
      final tuned = tuneKdfParams(
        measure: (_) => const Duration(milliseconds: 50),
      );

      expect(tuned.memoryKiB, 256 * 1024);
      expect(tuned.iterations, KdfParams.floor.iterations);
    });
  });
}
