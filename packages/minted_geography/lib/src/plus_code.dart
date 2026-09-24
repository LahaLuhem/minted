/// @docImport 'geohash.dart';
library;

import 'package:minted/minted.dart';
import 'package:open_location_code/open_location_code.dart' as olc;

import 'failures/plus_code_failure.dart';
import 'geo_bounds.dart';
import 'geo_coordinate.dart';

part 'constants/plus_code_constants.dart';
part 'helpers/plus_code_helpers.dart';
part 'short_plus_code.dart';

/// A full Plus Code: a short string naming a rectangular cell of the Earth's surface, e.g.
/// `8FVC9G8F+6W`. Standard: [Open Location Code](https://github.com/google/open-location-code),
/// Apache-2.0.
///
/// Like a [Geohash] it names a *cell*, not a point, and more digits means a smaller cell. See
/// [bounds] and [centre].
///
/// A shortened code such as `9G8F+6W` belongs to [ShortPlusCode]: it names nowhere until you say
/// where you are reading it.
///
/// Parsing trims and upper-cases, which is the case the standard writes codes in.
///
/// Sorting comes out spatial for free: the alphabet is ASCII-ascending and padding sorts ahead of
/// every digit, which is what makes a prefix range query work.
///
/// Named values: [PlusCodeConstants].
///
/// {@example /example/minted_geography_example.dart#pluscode}
extension type const PlusCode._(String value) {
  /// The 2-digit code holding [coordinate], a cell of about 2226 km.
  factory from2(GeoCoordinate coordinate) => _encode(coordinate, 2);

  /// The 4-digit code holding [coordinate], a cell of about 111 km.
  factory from4(GeoCoordinate coordinate) => _encode(coordinate, 4);

  /// The 6-digit code holding [coordinate], a cell of about 5566 m.
  factory from6(GeoCoordinate coordinate) => _encode(coordinate, 6);

  /// The 8-digit code holding [coordinate], a cell of about 278 m.
  factory from8(GeoCoordinate coordinate) => _encode(coordinate, 8);

  /// The 10-digit code holding [coordinate], a cell of about 13.9 m.
  factory from10(GeoCoordinate coordinate) => _encode(coordinate, 10);

  /// The 11-digit code holding [coordinate], a cell of about 2.8 x 3.5 m.
  factory from11(GeoCoordinate coordinate) => _encode(coordinate, 11);

  /// The 12-digit code holding [coordinate], a cell of about 56 x 87 cm.
  factory from12(GeoCoordinate coordinate) => _encode(coordinate, 12);

  /// The 13-digit code holding [coordinate], a cell of about 11 x 22 cm.
  factory from13(GeoCoordinate coordinate) => _encode(coordinate, 13);

  /// The 14-digit code holding [coordinate], a cell of about 2 x 5 cm.
  factory from14(GeoCoordinate coordinate) => _encode(coordinate, 14);

  /// The 15-digit code holding [coordinate], a cell of about 4 x 14 mm.
  factory from15(GeoCoordinate coordinate) => _encode(coordinate, 15);

  /// Parses [input], or `null` unless it is a full Plus Code.
  static PlusCode? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting [PlusCodeNotFull] when it is a real but shortened code.
  static ParseOutcome<PlusCodeFailure, PlusCode> parse(String input) {
    final normalisedInput = _normalised(input);
    final failure = _fullFailureFor(normalisedInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalisedInput));
  }

  /// How many digits carry a position, so how fine the cell. Padding does not count, leaving
  /// `8FVC0000+` on 4.
  int get digits => _significantDigits(value);

  /// Whether `0`s stand in for missing digits before the separator, as in `8FVC0000+`.
  bool get isPadded => digits < _digitsBeforeSeparator;

  /// The cell itself, as a box. What the code actually names, where [centre] is one point in it.
  ///
  /// Never crosses the antimeridian and never leaves the latitude range.
  GeoBounds get bounds {
    final area = olc.PlusCode.unverified(value).decode();

    return GeoBounds.tryFrom(
      west: area.southWest.longitude,
      south: area.southWest.latitude,
      east: area.northEast.longitude,
      north: area.northEast.latitude,
    )!;
  }

  /// The centre of the cell, not the coordinate the code was built from: a coarse cell is wide.
  /// Re-encoding this at the same digit count does give the code back.
  GeoCoordinate get centre {
    final cell = bounds;

    // Midpoints of a cell inside both full ranges, so neither part can leave its own.
    return GeoCoordinate.tryFrom(
      latitude: (cell.south + cell.north) / 2,
      longitude: (cell.west + cell.east) / 2,
    )!;
  }

  /// This code with its leading digits dropped, as far as [reference] allows, or `null` when
  /// [reference] is too far away for any to go.
  ///
  /// An [isPadded] code always answers `null`: the standard forbids shortening one.
  ShortPlusCode? shortenNear(GeoCoordinate reference) {
    if (isPadded) return null;

    final shortened = olc.PlusCode.unverified(value).shorten(_latLng(reference)).toString();

    return shortened == value ? null : ShortPlusCode._(shortened);
  }
}
