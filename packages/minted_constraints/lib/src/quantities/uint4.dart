/// @docImport 'uint.dart';
library;

part '../constants/uint4_constants.dart';

/// An unsigned 4-bit integer, a nibble: `0` to `15`.
///
/// Bounded at both ends, unlike [Uint]. Out of range is refused, never truncated.
///
/// [Uint4Constants.u0] to [Uint4Constants.u15] are provided when the value is const-known. [Uint4Constants.max] is the top one.
///
/// Named values: [Uint4Constants].
extension type const Uint4._(int value) implements int {
  /// The [Uint4] with numeric [value], or `null` unless it's in `0`-`15`.
  static Uint4? tryFrom(int value) =>
      value < Uint4Constants.u0 || value > Uint4Constants.max ? null : ._(value);
}
