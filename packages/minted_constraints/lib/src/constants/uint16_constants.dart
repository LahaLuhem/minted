part of '../quantities/uint16.dart';

/// The [Uint16] bounds.
abstract final class Uint16Constants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The lowest value: `0`.
  static const zero = Uint16._(0);

  /// The highest value: `65535`.
  static const max = Uint16._(65535);
}
