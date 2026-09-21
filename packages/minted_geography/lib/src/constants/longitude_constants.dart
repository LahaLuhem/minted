part of '../longitude.dart';

/// The [Longitude] bounds.
abstract final class LongitudeConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The western bound, kept distinct from [max] as the class dartdoc explains.
  static const min = Longitude._(-maxLongitude);

  /// The eastern bound.
  static const max = Longitude._(maxLongitude);
}
