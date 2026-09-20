part of '../quantities/uint.dart';

/// The [Uint] floor. Unbounded above, so there is no ceiling to name.
abstract final class UintConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The lowest value: `0`.
  static const zero = Uint._(0);
}
