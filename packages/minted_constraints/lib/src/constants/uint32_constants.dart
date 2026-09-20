part of '../quantities/uint32.dart';

/// The [Uint32] bounds.
abstract final class Uint32Constants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The lowest value: `0`.
  static const zero = Uint32._(0);

  /// The highest value: `4294967295`.
  static const max = Uint32._(4294967295);
}
