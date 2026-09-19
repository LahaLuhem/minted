/// @docImport 'uint.dart';
library;

/// An unsigned 32-bit integer: `0` to `4294967295`.
///
/// Bounded at both ends, unlike [Uint]. Out of range is refused, never truncated.
///
/// [zero] and [max] name the ends.
extension type const Uint32._(int value) implements int {
  /// The [Uint32] with numeric [value], or `null` unless it's in `0`-`4294967295`.
  static Uint32? tryFrom(int value) => value < zero || value > max ? null : ._(value);

  /// The lowest value: `0`.
  static const zero = Uint32._(0);

  /// The highest value: `4294967295`.
  static const max = Uint32._(4294967295);
}
