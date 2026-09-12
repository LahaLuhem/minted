/// @docImport 'uint.dart';
library;

/// An unsigned 2-bit integer: `0` to `3`.
///
/// Bounded at both ends, unlike [Uint]. Out-of-range input is refused, never truncated to fit.
///
/// [value] is the numeric value. The string form is `value.toString()`.
///
/// [u0] to [u3] are provided when the value is const-known. [max] is the top one.
extension type const Uint2._(int value) implements int {
  /// The [Uint2] with numeric [value], or `null` unless it is in `0`-`3`.
  static Uint2? tryFrom(int value) => value < u0 || value > max ? null : ._(value);

  /// The value `0`.
  static const u0 = Uint2._(0);

  /// The value `1`.
  static const u1 = Uint2._(1);

  /// The value `2`.
  static const u2 = Uint2._(2);

  /// The value `3`.
  static const u3 = Uint2._(3);

  /// The highest value: [u3].
  static const max = u3;
}
