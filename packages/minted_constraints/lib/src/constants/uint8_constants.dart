part of '../quantities/uint8.dart';

/// The [Uint8] bounds.
abstract final class Uint8Constants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The lowest byte: `0`.
  static const zero = Uint8._(0);

  /// The highest byte: `255`.
  static const max = Uint8._(255);
}
