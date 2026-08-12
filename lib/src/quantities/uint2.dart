/// @docImport 'uint.dart';
library;

/// An unsigned 2-bit integer: `0` to `3`.
///
/// Bounded at both ends, unlike [Uint]. Out-of-range input is refused, never truncated to fit.
///
/// [value] is the numeric value; the string form is `value.toString()`.
extension type const Uint2._(int value) {
  /// The [Uint2] with numeric [value], or `null` unless it is in `0`-`3`.
  static Uint2? tryFrom(int value) => value < 0 || value > _max ? null : ._(value);

  static const _max = 3;
}
