import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'failures/geohash_failure.dart';
import 'geo_bounds.dart';
import 'geo_coordinate.dart';
import 'standards/coordinate_bounds.dart';

part 'constants/geohash_constants.dart';
part 'helpers/geohash_helpers.dart';

/// A geohash: a base32 string naming a rectangular cell of the Earth's surface, where each further character
/// narrows the cell and every prefix encloses it. Standard: [CTA-5009-A](https://www.cta.tech/standards/cta-5009-a/),
/// public domain since 2008.
///
/// `toLowerCase()` isn't validation, the alphabet omitting `a`, `i`, `l` and `o`. And a geohash names
/// a *cell*, not a point, which a `String` leaves callers no way to say. See [centre].
///
/// Parsing trims, then lower-cases to the alphabet's own case.
///
/// Sorting comes out spatial for free, the alphabet being ASCII-ascending, which is what makes a prefix
/// range query work.
///
/// Named values: [GeohashConstants].
///
/// {@example /example/minted_geography_example.dart#geohash}
extension type const Geohash._(String value) {
  /// The geohash of [precision] characters whose cell holds [coordinate]. Can't fail: both parameters
  /// carry their own invariants, so an absurd [precision] builds an absurd string rather than getting
  /// refused.
  ///
  /// Lossy by design, and [precision] sizes the loss. A coarse cell is wide, so [centre] won't hand
  /// [coordinate] back.
  //
  // A constructor rather than the family's usual static assembly door, because it's the first one that
  // can't fail. A ParseOutcome return is what stops the others being constructors.
  factory from({required GeoCoordinate coordinate, required NaturalNumber precision}) {
    final intervals = _wholeEarth();
    final targets = [coordinate.longitude, coordinate.latitude];
    final characters = StringBuffer();
    var characterValue = 0;
    var characterBits = 0;

    for (var bit = 0; characters.length < precision.value; bit++) {
      final axis = bit % _axisCount;
      final interval = intervals[axis];
      final middle = _middleOf(interval);
      final isUpperHalf = targets[axis] >= middle;

      intervals[axis] = isUpperHalf
          ? (low: middle, high: interval.high)
          : (low: interval.low, high: middle);
      characterValue = characterValue * 2 + (isUpperHalf ? 1 : 0);
      characterBits++;

      if (characterBits == _bitsPerCharacter) {
        characters.write(_alphabet[characterValue]);
        characterValue = 0;
        characterBits = 0;
      }
    }

    return Geohash._(characters.toString());
  }

  /// Parses [input], or `null` if it's empty or holds a character outside the alphabet.
  static Geohash? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [GeohashFailure] that names what broke.
  static ParseOutcome<GeohashFailure, Geohash> parse(String input) {
    final normalisedInput = input.trim().toLowerCase();
    final failure = _failureFor(normalisedInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalisedInput));
  }

  /// How many characters, so how fine the cell. No upper bound: nothing in the standard fixes one.
  int get precision => value.length;

  /// The cell itself, as a box. What a geohash actually names, where [centre] is one point in it.
  ///
  /// Never crosses the antimeridian, since halving `-180` to `180` can't put a western edge east of
  /// an eastern one. Which is also why the box can't fail to build.
  GeoBounds get bounds {
    final intervals = _cellOf(value);
    final (low: south, high: north) = intervals[_latitudeAxis];
    final (low: west, high: east) = intervals[_longitudeAxis];

    return GeoBounds.tryFrom(west: west, south: south, east: east, north: north)!;
  }

  /// The centre of the cell, which isn't the coordinate the geohash was built from, a coarse cell being
  /// wide. Re-encoding this at [precision] does give this geohash back.
  ///
  /// Beyond about 23 characters a `double` runs out of mantissa, so the centre stops moving.
  GeoCoordinate get centre {
    final cell = bounds;

    // Midpoints of a cell inside both full ranges, so neither part can leave its own.
    return GeoCoordinate.tryFrom(
      latitude: (cell.south + cell.north) / 2,
      longitude: (cell.west + cell.east) / 2,
    )!;
  }
}
