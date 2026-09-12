/// @docImport 'uint.dart';
library;

/// An unsigned 8-bit integer, a byte: `0` to `255`.
///
/// Bounded at both ends, unlike [Uint]. Out-of-range input is refused, never truncated to fit.
///
/// [value] is the numeric value. The string form is `value.toString()`.
///
/// [zero] and [max] name the ends.
///
/// {@example /example/minted_constraints_example.dart#fixedwidths}
extension type const Uint8._(int value) implements int {
  /// The [Uint8] with numeric [value], or `null` unless it is in `0`-`255`.
  static Uint8? tryFrom(int value) => value < zero || value > max ? null : ._(value);

  /// The lowest byte: `0`.
  static const zero = Uint8._(0);

  /// The highest byte: `255`.
  static const max = Uint8._(255);
}
