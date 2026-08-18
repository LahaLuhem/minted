/// @docImport 'uint.dart';
library;

/// An unsigned 8-bit integer, a byte: `0` to `255`.
///
/// Bounded at both ends, unlike [Uint]. Out-of-range input is refused, never truncated to fit.
///
/// [value] is the numeric value; the string form is `value.toString()`.
///
/// {@example /example/minted_constraints_example.dart#fixedwidths}
extension type const Uint8._(int value) implements int {
  /// The [Uint8] with numeric [value], or `null` unless it is in `0`-`255`.
  static Uint8? tryFrom(int value) => value < 0 || value > _max ? null : ._(value);

  static const _max = 255;
}
