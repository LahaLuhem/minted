/// @docImport '../geo_bounds.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

import 'geo_coordinate_failure.dart';

/// Why a [GeoBounds] refused its input. Sealed rather than an enum, because 2 variants carry what
/// failed, one of them a corner's own failure.
@immutable
sealed class const GeoBoundsFailure() implements MintedFailure {
  /// Subclasses only: the type is sealed.
  this;

  @override
  String get typeName => 'GeoBounds';
}

/// The text isn't 4 comma-separated numbers, brackets or no brackets.
final class const GeoBoundsNotFourNumbers() extends GeoBoundsFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'not four comma-separated numbers: west,south,east,north';

  @override
  bool operator ==(Object other) => other is GeoBoundsNotFourNumbers;

  @override
  int get hashCode => (GeoBoundsNotFourNumbers).hashCode;

  @override
  String toString() => 'GeoBoundsNotFourNumbers()';
}

/// A corner is out of range. Nested rather than flattened so the diagnosis survives: a caller learns
/// which half left which range, not just that a corner was wrong.
final class const GeoBoundsInvalidCorner(
  /// Why the corner itself would not build.
  final GeoCoordinateFailure reason,
) extends GeoBoundsFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'a corner is not a coordinate: ${reason.message}';

  @override
  bool operator ==(Object other) => other is GeoBoundsInvalidCorner && other.reason == reason;

  @override
  int get hashCode => Object.hash(GeoBoundsInvalidCorner, reason);

  @override
  String toString() => 'GeoBoundsInvalidCorner($reason)';
}

/// The southern edge is above the northern one. Latitude is linear, so unlike the longitudes this pair
/// has no reading as a box that wraps.
final class const GeoBoundsSouthAboveNorth({
  /// The southern edge, in decimal degrees.
  required final double south,

  /// The northern edge, in decimal degrees.
  required final double north,
}) extends GeoBoundsFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'south $south is above north $north';

  @override
  bool operator ==(Object other) =>
      other is GeoBoundsSouthAboveNorth && other.south == south && other.north == north;

  @override
  int get hashCode => Object.hash(GeoBoundsSouthAboveNorth, south, north);

  @override
  String toString() => 'GeoBoundsSouthAboveNorth(south: $south, north: $north)';
}
