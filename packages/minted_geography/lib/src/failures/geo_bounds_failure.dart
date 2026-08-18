/// @docImport '../geo_bounds.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

import 'geo_coordinate_failure.dart';

/// Why a [GeoBounds] refused its input. Sealed, not an enum, because two variants carry what
/// failed, one of them a corner's own failure. Three remedies: supply four numbers, fix a corner,
/// or swap the latitudes.
@immutable
sealed class GeoBoundsFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'GeoBounds';
}

/// The text is not four comma-separated numbers, with or without the surrounding brackets GeoJSON
/// writes them in.
final class GeoBoundsNotFourNumbers extends GeoBoundsFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'not four comma-separated numbers: west,south,east,north';

  @override
  bool operator ==(Object other) => other is GeoBoundsNotFourNumbers;

  @override
  int get hashCode => (GeoBoundsNotFourNumbers).hashCode;

  @override
  String toString() => 'GeoBoundsNotFourNumbers()';
}

/// A corner is out of range. Nested rather than flattened so the diagnosis survives: a caller
/// learns which half left which range, not merely that a corner was wrong.
final class GeoBoundsInvalidCorner extends GeoBoundsFailure {
  /// Why the corner itself would not build.
  final GeoCoordinateFailure reason;

  /// Creates the failure.
  const new(this.reason);

  @override
  String get message => 'a corner is not a coordinate: ${reason.message}';

  @override
  bool operator ==(Object other) => other is GeoBoundsInvalidCorner && other.reason == reason;

  @override
  int get hashCode => Object.hash(GeoBoundsInvalidCorner, reason);

  @override
  String toString() => 'GeoBoundsInvalidCorner($reason)';
}

/// The southern edge is above the northern one. Latitude is linear, so unlike the longitudes this
/// pair has no reading as a box that wraps.
final class GeoBoundsSouthAboveNorth extends GeoBoundsFailure {
  /// The southern edge, in decimal degrees.
  final double south;

  /// The northern edge, in decimal degrees.
  final double north;

  /// Creates the failure.
  const new({required this.south, required this.north});

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
