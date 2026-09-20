/// @docImport 'uint.dart';
library;

part '../constants/uint8_constants.dart';

/// An unsigned 8-bit integer, a byte: `0` to `255`.
///
/// Bounded at both ends, unlike [Uint]. Out of range is refused, never truncated.
///
/// Named values: [Uint8Constants].
///
/// {@example /example/minted_constraints_example.dart#fixedwidths}
extension type const Uint8._(int value) implements int {
  /// The [Uint8] with numeric [value], or `null` unless it's in `0`-`255`.
  static Uint8? tryFrom(int value) =>
      value < Uint8Constants.zero || value > Uint8Constants.max ? null : ._(value);
}
