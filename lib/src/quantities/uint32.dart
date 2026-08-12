/// @docImport 'uint.dart';
library;

/// An unsigned 32-bit integer: `0` to `4294967295`.
///
/// Bounded at both ends, unlike [Uint]. Out-of-range input is refused, never truncated to fit.
///
/// [value] is the numeric value; the string form is `value.toString()`.
extension type const Uint32._(int value) {
  /// The [Uint32] with numeric [value], or `null` unless it is in `0`-`4294967295`.
  static Uint32? tryFrom(int value) => value < 0 || value > _max ? null : ._(value);

  static const _max = 4294967295;
}
