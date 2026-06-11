import 'dart:typed_data';

/// EXECUTION-PLAN §6.1.3 — the derived master key lives in memory only.
/// The buffer is zeroed on screen lock / backgrounding, explicit Lock,
/// session timeout, and app termination; those lifecycle hooks call [zero].
/// The key is never copied through a String.
class MasterKeyHolder {
  Uint8List? _key;

  bool get hasKey => _key != null;

  /// Takes ownership of [key]; any previously held key is zeroed first.
  void set(Uint8List key) {
    zero();
    _key = key;
  }

  /// The live key buffer. Callers must not retain the reference past
  /// immediate use.
  Uint8List get key {
    final key = _key;
    if (key == null) {
      throw StateError('Master key is not loaded');
    }
    return key;
  }

  /// Overwrites the key bytes with zeros and drops the reference.
  void zero() {
    final key = _key;
    if (key != null) {
      key.fillRange(0, key.length, 0);
      _key = null;
    }
  }
}
