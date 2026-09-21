part of '../quantities/uint2.dart';

/// Every [Uint2], plus the top one again as `max`.
abstract final class Uint2Constants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The value `0`.
  static const u0 = Uint2._(0);

  /// The value `1`.
  static const u1 = Uint2._(1);

  /// The value `2`.
  static const u2 = Uint2._(2);

  /// The value `3`.
  static const u3 = Uint2._(3);

  /// The highest value: [u3].
  static const max = u3;
}
