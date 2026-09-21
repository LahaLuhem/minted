part of '../latitude.dart';

/// The [Latitude] bounds.
abstract final class LatitudeConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The southern bound, at the pole.
  static const min = Latitude._(-maxLatitude);

  /// The northern bound.
  static const max = Latitude._(maxLatitude);
}
