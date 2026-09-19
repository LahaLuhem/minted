/// @docImport 'uint.dart';
library;

/// An unsigned 4-bit integer, a nibble: `0` to `15`.
///
/// Bounded at both ends, unlike [Uint]. Out of range is refused, never truncated.
///
/// [u0] to [u15] are provided when the value is const-known. [max] is the top one.
extension type const Uint4._(int value) implements int {
  /// The [Uint4] with numeric [value], or `null` unless it's in `0`-`15`.
  static Uint4? tryFrom(int value) => value < u0 || value > max ? null : ._(value);

  /// The nibble `0`.
  static const u0 = Uint4._(0);

  /// The nibble `1`.
  static const u1 = Uint4._(1);

  /// The nibble `2`.
  static const u2 = Uint4._(2);

  /// The nibble `3`.
  static const u3 = Uint4._(3);

  /// The nibble `4`.
  static const u4 = Uint4._(4);

  /// The nibble `5`.
  static const u5 = Uint4._(5);

  /// The nibble `6`.
  static const u6 = Uint4._(6);

  /// The nibble `7`.
  static const u7 = Uint4._(7);

  /// The nibble `8`.
  static const u8 = Uint4._(8);

  /// The nibble `9`.
  static const u9 = Uint4._(9);

  /// The nibble `10`.
  static const u10 = Uint4._(10);

  /// The nibble `11`.
  static const u11 = Uint4._(11);

  /// The nibble `12`.
  static const u12 = Uint4._(12);

  /// The nibble `13`.
  static const u13 = Uint4._(13);

  /// The nibble `14`.
  static const u14 = Uint4._(14);

  /// The nibble `15`.
  static const u15 = Uint4._(15);

  /// The highest nibble: [u15].
  static const max = u15;
}
