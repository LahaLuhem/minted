import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'failures/geohash_failure.dart';
import 'geo_coordinate.dart';
import 'standards/coordinate_bounds.dart';

/// A geohash: a base32 string naming a rectangular cell of the Earth's surface, where each further
/// character narrows the cell and every prefix encloses it.
/// Standard: [CTA-5009-A](https://www.cta.tech/standards/cta-5009-a/), public domain since 2008.
///
/// Parse, don't validate: `toLowerCase()` is not validation, because the alphabet omits `a`, `i`,
/// `l` and `o`. And a geohash is a *cell*, not a point, which a `String` leaves callers no way to
/// say. See [centre].
///
/// Normalisation on parse: surrounding whitespace trimmed, then lower-cased, the alphabet's own case.
///
/// Sorting is spatial for free, the alphabet being ASCII-ascending: plain string order is geohash
/// order, which is what makes a prefix range query work.
///
/// {@example /example/minted_geography_example.dart#geohash}
extension type const Geohash._(String value) {
  /// The geohash of [precision] characters whose cell contains [coordinate]. Cannot fail: both
  /// parameters carry their own invariants, so an absurd [precision] builds an absurd string rather
  /// than being refused.
  ///
  /// Lossy by design, and [precision] sizes the loss: a coarse cell is wide, so [centre] will not
  /// hand [coordinate] back.
  //
  // A constructor rather than the family's usual static assembly door, because it is the first one
  // that cannot fail: a ParseOutcome return is what stops the others being constructors.
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

  /// Parses [input] as a geohash, or returns `null` when it is empty or holds a character the
  /// alphabet does not.
  static Geohash? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a geohash, reporting the [GeohashFailure] that names what broke.
  static ParseOutcome<GeohashFailure, Geohash> parse(String input) {
    final normalisedInput = input.trim().toLowerCase();
    final failure = _failureFor(normalisedInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalisedInput));
  }

  /// How many characters, so how fine the cell. No upper bound: nothing in the standard fixes one.
  int get precision => value.length;

  /// The centre of the cell, which is not the coordinate the geohash was built from: a coarse cell
  /// is wide. Re-encoding this at [precision] does return this geohash.
  ///
  /// Beyond about 23 characters a `double` runs out of mantissa, so the centre stops moving.
  GeoCoordinate get centre {
    final intervals = _cellOf(value);

    // Midpoints of the halved full ranges, so neither part can leave its own.
    return GeoCoordinate.tryFrom(
      latitude: _middleOf(intervals[_latitudeAxis]),
      longitude: _middleOf(intervals[_longitudeAxis]),
    )!;
  }

  // Why normalised input is not a geohash, or null when it is one. The one gate parse funnels
  // through.
  static GeohashFailure? _failureFor(String normalisedInput) {
    if (normalisedInput.isEmpty) return const GeohashEmpty();

    final offendingCharacter = _nonAlphabetCharacter.firstMatch(normalisedInput)?.group(0);

    return offendingCharacter == null ? null : GeohashInvalidCharacter(offendingCharacter);
  }

  // The cell [geohashValue] narrows to. Reached only from a parsed value, so every character is in
  // the alphabet and indexOf cannot answer -1.
  static List<({double low, double high})> _cellOf(String geohashValue) {
    final intervals = _wholeEarth();
    var bit = 0;

    for (final codeUnit in geohashValue.codeUnits) {
      final characterValue = _alphabetCodeUnits.indexOf(codeUnit);

      for (var mask = _highestCharacterBit; mask > 0; mask >>= 1) {
        final axis = bit % _axisCount;
        final interval = intervals[axis];
        final middle = _middleOf(interval);

        intervals[axis] = characterValue & mask == 0
            ? (low: interval.low, high: middle)
            : (low: middle, high: interval.high);
        bit++;
      }
    }

    return intervals;
  }

  // Both axes at full extent, longitude first because it takes the first bit. Fresh per call: the
  // walk narrows it in place.
  static List<({double low, double high})> _wholeEarth() => [
    (low: -maxLongitude, high: maxLongitude),
    (low: -maxLatitude, high: maxLatitude),
  ];

  // Exact in binary: every bound is ±90 or ±180 times a dyadic rational, so halving never rounds.
  static double _middleOf(({double low, double high}) interval) =>
      (interval.low + interval.high) / 2;

  // The 36 alphanumerics less `a`, `i`, `l` and `o`, leaving 32 and dropping the letters that read
  // as digits. ASCII-ascending on purpose, which is what makes string order spatial order.
  static const _alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';

  static final _alphabetCodeUnits = _alphabet.codeUnits;
  static final _nonAlphabetCharacter = RegExp('[^$_alphabet]');

  static const _bitsPerCharacter = 5;
  static const _highestCharacterBit = 1 << (_bitsPerCharacter - 1);

  // Longitude takes the first bit and the two alternate, so a bit index's parity picks its axis.
  static const _axisCount = 2;
  static const _longitudeAxis = 0;
  static const _latitudeAxis = 1;
}
