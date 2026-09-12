/// @docImport 'uint.dart';
library;

/// An unsigned 16-bit integer: `0` to `65535`.
///
/// Bounded at both ends, unlike [Uint]. Out-of-range input is refused, never truncated to fit.
///
/// [value] is the numeric value. The string form is `value.toString()`.
///
/// [zero] and [max] name the ends.
extension type const Uint16._(int value) implements int {
  /// The [Uint16] with numeric [value], or `null` unless it is in `0`-`65535`.
  static Uint16? tryFrom(int value) => value < zero || value > max ? null : ._(value);

  /// The lowest value: `0`.
  static const zero = Uint16._(0);

  /// The highest value: `65535`.
  static const max = Uint16._(65535);
}
