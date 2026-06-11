import 'dart:convert';

/// Argon2id parameters for SQLCipher master-key derivation
/// (EXECUTION-PLAN §6.1.1).
class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    this.outputLength = 32,
  });

  /// §6.1.1 minimum floor: 64 MiB memory, 3 iterations, parallelism 1,
  /// 32-byte output.
  static const floor = KdfParams(
    memoryKiB: 64 * 1024,
    iterations: 3,
    parallelism: 1,
  );

  /// §6.1.1 tuning ladder — memory is ratcheted upward through these rungs
  /// when derivation on the current device is too fast.
  static const memoryLadderKiB = [64 * 1024, 128 * 1024, 256 * 1024];

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int outputLength;

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
    memoryKiB: json['memoryKiB'] as int,
    iterations: json['iterations'] as int,
    parallelism: json['parallelism'] as int,
    outputLength: json['outputLength'] as int,
  );

  Map<String, dynamic> toJson() => {
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'outputLength': outputLength,
  };

  String encode() => jsonEncode(toJson());

  static KdfParams decode(String encoded) =>
      KdfParams.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

  KdfParams withMemoryKiB(int newMemoryKiB) => KdfParams(
    memoryKiB: newMemoryKiB,
    iterations: iterations,
    parallelism: parallelism,
    outputLength: outputLength,
  );

  @override
  bool operator ==(Object other) =>
      other is KdfParams &&
      other.memoryKiB == memoryKiB &&
      other.iterations == iterations &&
      other.parallelism == parallelism &&
      other.outputLength == outputLength;

  @override
  int get hashCode =>
      Object.hash(memoryKiB, iterations, parallelism, outputLength);

  @override
  String toString() =>
      'KdfParams(memoryKiB: $memoryKiB, iterations: $iterations, '
      'parallelism: $parallelism, outputLength: $outputLength)';
}

/// §6.1.1 step 2 device tuning — measure Argon2id wall time at the floor;
/// if below 200 ms, ratchet memory upward (128 MiB, then 256 MiB) until the
/// 300–500 ms target is met or the ladder is exhausted.
KdfParams tuneKdfParams({
  required Duration Function(KdfParams params) measure,
  KdfParams start = KdfParams.floor,
}) {
  var params = start;
  if (measure(params).inMilliseconds >= 200) {
    return params;
  }

  for (final memoryKiB in KdfParams.memoryLadderKiB) {
    if (memoryKiB <= params.memoryKiB) {
      continue;
    }
    params = params.withMemoryKiB(memoryKiB);
    if (measure(params).inMilliseconds >= 300) {
      break;
    }
  }
  return params;
}
