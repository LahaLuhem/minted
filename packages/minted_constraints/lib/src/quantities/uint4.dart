/// @docImport 'uint.dart';
library;

/// An unsigned 4-bit integer, a nibble: `0` to `15`.
///
/// Bounded at both ends, unlike [Uint]. Out-of-range input is refused, never truncated to fit.
///
/// [value] is the numeric value; the string form is `value.toString()`.
extension type const Uint4._(int value) implements int {
  /// The [Uint4] with numeric [value], or `null` unless it is in `0`-`15`.
  static Uint4? tryFrom(int value) => value < 0 || value > _max ? null : ._(value);

  static const _max = 15;
}
