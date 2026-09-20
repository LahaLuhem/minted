part of '../geo_bounds.dart';

/// The maximal [GeoBounds], every degree of both axes.
abstract final class GeoBoundsConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The maximum box, every degree of both axes.
  static const wholeWorld = GeoBounds._(
    west: LongitudeConstants.min,
    south: LatitudeConstants.min,
    east: LongitudeConstants.max,
    north: LatitudeConstants.max,
  );
}
