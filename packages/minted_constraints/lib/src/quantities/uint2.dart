/// @docImport 'uint.dart';
library;

part '../constants/uint2_constants.dart';

/// An unsigned 2-bit integer: `0` to `3`.
///
/// Bounded at both ends, unlike [Uint]. Out of range is refused, never truncated.
///
/// [Uint2Constants.u0] to [Uint2Constants.u3] are provided when the value is const-known. [Uint2Constants.max] is the top one.
///
/// Named values: [Uint2Constants].
extension type const Uint2._(int value) implements int {
  /// The [Uint2] with numeric [value], or `null` unless it's in `0`-`3`.
  static Uint2? tryFrom(int value) =>
      value < Uint2Constants.u0 || value > Uint2Constants.max ? null : ._(value);
}
