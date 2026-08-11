/// @docImport '../geo_coordinate.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/minted_failure.dart';

/// Why a [GeoCoordinate] refused its input. Sealed, not an enum, because the range variants report
/// the offending number back. Two remedies: [GeoCoordinateNotIso6709] means fix the format, the
/// other two mean fix a number.
@immutable
sealed class GeoCoordinateFailure implements MintedFailure {
  const GeoCoordinateFailure();

  @override
  String get typeName => 'GeoCoordinate';
}

/// The text is not the ISO 6709 shape: a signed, fixed-width latitude and longitude closed by `/`.
/// Minutes or seconds reaching `60` land here too, being part of the grammar, not a separate range.
final class GeoCoordinateNotIso6709 extends GeoCoordinateFailure {
  /// Creates the failure.
  const GeoCoordinateNotIso6709();

  @override
  String get message => 'not an ISO 6709 coordinate string';

  @override
  bool operator ==(Object other) => other is GeoCoordinateNotIso6709;

  @override
  int get hashCode => (GeoCoordinateNotIso6709).hashCode;

  @override
  String toString() => 'GeoCoordinateNotIso6709()';
}

/// The latitude falls outside `-90` to `90`.
final class GeoCoordinateLatitudeOutOfRange extends GeoCoordinateFailure {
  /// The offending latitude, in decimal degrees.
  final double latitude;

  /// Creates the failure.
  const GeoCoordinateLatitudeOutOfRange(this.latitude);

  @override
  String get message => 'latitude $latitude is outside -90 to 90';

  @override
  bool operator ==(Object other) =>
      other is GeoCoordinateLatitudeOutOfRange && other.latitude == latitude;

  @override
  int get hashCode => Object.hash(GeoCoordinateLatitudeOutOfRange, latitude);

  @override
  String toString() => 'GeoCoordinateLatitudeOutOfRange($latitude)';
}

/// The longitude falls outside `-180` to `180`.
final class GeoCoordinateLongitudeOutOfRange extends GeoCoordinateFailure {
  /// The offending longitude, in decimal degrees.
  final double longitude;

  /// Creates the failure.
  const GeoCoordinateLongitudeOutOfRange(this.longitude);

  @override
  String get message => 'longitude $longitude is outside -180 to 180';

  @override
  bool operator ==(Object other) =>
      other is GeoCoordinateLongitudeOutOfRange && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(GeoCoordinateLongitudeOutOfRange, longitude);

  @override
  String toString() => 'GeoCoordinateLongitudeOutOfRange($longitude)';
}
