/// @docImport 'uint.dart';
library;

part '../constants/uint16_constants.dart';

/// An unsigned 16-bit integer: `0` to `65535`.
///
/// Bounded at both ends, unlike [Uint]. Out of range is refused, never truncated.
///
/// [Uint16Constants.zero] and [Uint16Constants.max] name the ends.
///
/// Named values: [Uint16Constants].
extension type const Uint16._(int value) implements int {
  /// The [Uint16] with numeric [value], or `null` unless it's in `0`-`65535`.
  static Uint16? tryFrom(int value) =>
      value < Uint16Constants.zero || value > Uint16Constants.max ? null : ._(value);
}
