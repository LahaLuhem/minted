/// @docImport 'uint.dart';
library;

/// An unsigned 16-bit integer: `0` to `65535`.
///
/// Bounded at both ends, unlike [Uint]. Out-of-range input is refused, never truncated to fit.
///
/// [value] is the numeric value; the string form is `value.toString()`.
extension type const Uint16._(int value) implements int {
  /// The [Uint16] with numeric [value], or `null` unless it is in `0`-`65535`.
  static Uint16? tryFrom(int value) => value < 0 || value > _max ? null : ._(value);

  static const _max = 65535;
}
