/// @docImport 'uint.dart';
library;

part '../constants/uint32_constants.dart';

/// An unsigned 32-bit integer: `0` to `4294967295`.
///
/// Bounded at both ends, unlike [Uint]. Out of range is refused, never truncated.
///
/// [Uint32Constants.zero] and [Uint32Constants.max] name the ends.
///
/// Named values: [Uint32Constants].
extension type const Uint32._(int value) implements int {
  /// The [Uint32] with numeric [value], or `null` unless it's in `0`-`4294967295`.
  static Uint32? tryFrom(int value) =>
      value < Uint32Constants.zero || value > Uint32Constants.max ? null : ._(value);
}
