part of '../geohash.dart';

/// The [Geohash] floor. There is no ceiling, since any geohash takes another `z`.
abstract final class GeohashConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The first cell in sort order: every geohash sorts at or after this. There is no last one, since
  /// any geohash takes another `z`.
  static const first = Geohash._('0');
}
