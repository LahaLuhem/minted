// The pattern admits only ASCII signs, digits, and a decimal point, so slicing by index is safe.
// ignore_for_file: avoid-substring

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';

import 'failures/geo_coordinate_failure.dart';
import 'standards/coordinate_bounds.dart';

/// A point on the Earth's surface: a latitude and a longitude, in decimal degrees.
///
/// Two raw doubles cannot say which is which, so `f(latitude, longitude)` and
/// `f(longitude, latitude)` compile the same and no range check catches the swap.
///
/// Parse, don't validate: a [GeoCoordinate] exists only if [latitude] is within `-90` to `90` and
/// [longitude] within `-180` to `180`. [parse] reads all three ISO 6709 widths, where the number of
/// degree digits selects the unit: degrees, degrees-minutes, or degrees-minutes-seconds.
/// Standard: [ISO 6709](https://en.wikipedia.org/wiki/ISO_6709).
///
/// Normalisation on parse: sexagesimal input becomes decimal degrees ([iso6709]), `-180` becomes
/// `+180` (one meridian, two spellings), a negative zero becomes positive, the sign the standard
/// gives the equator and the prime meridian, and a degree finer than [iso6709] can spell is snapped
/// to one it can. Altitude and a CRS are refused, not dropped.
///
/// Equality is by value over [latitude] and [longitude].
///
/// {@example /example/minted_geography_example.dart#geo}
@immutable
final class GeoCoordinate {
  /// The latitude in decimal degrees, `-90` to `90`. Negative is south of the equator.
  final double latitude;

  /// The longitude in decimal degrees, `-180` to `180`. Negative is west of the prime meridian.
  final double longitude;

  const new _(this.latitude, this.longitude);

  // The only door that constructs, so every instance normalises alike. A negative zero prints as
  // "-0.0000" here, and the snap runs inside the clearing, because a tiny negative degree rounds
  // to -0.0.
  factory _canonical(double latitude, double longitude) => GeoCoordinate._(
    positiveZeroed(_renderable(latitude)),
    positiveZeroed(_renderable(longitude == -maxLongitude ? maxLongitude : longitude)),
  );

  /// The coordinate at [latitude] and [longitude] decimal degrees, reporting the
  /// [GeoCoordinateFailure] when either leaves its range. Named parameters, so a transposed pair
  /// cannot be written by accident.
  static ParseOutcome<GeoCoordinateFailure, GeoCoordinate> from({
    required double latitude,
    required double longitude,
  }) {
    final failure = _rangeFailure(latitude, longitude);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._canonical(latitude, longitude));
  }

  /// The coordinate at [latitude] and [longitude] decimal degrees, or `null` when either leaves its
  /// range. A `NaN` is out of range on both. Derived from [from], so the two cannot diverge.
  static GeoCoordinate? tryFrom({required double latitude, required double longitude}) =>
      from(latitude: latitude, longitude: longitude).getOrNull();

  /// Parses [input] as an ISO 6709 latitude and longitude, or returns `null` unless it is exactly
  /// that shape (signed, fixed-width, closed by `/`, no altitude) and both parts are in range.
  static GeoCoordinate? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an ISO 6709 latitude and longitude, reporting the [GeoCoordinateFailure]
  /// that says whether the shape or one of the parts is wrong.
  static ParseOutcome<GeoCoordinateFailure, GeoCoordinate> parse(String input) {
    final degrees = _degreesOf(input);
    if (degrees == null) return const ParseFailure(GeoCoordinateNotIso6709());

    final (:latitude, :longitude) = degrees;
    final failure = _rangeFailure(latitude, longitude);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._canonical(latitude, longitude));
  }

  /// The canonical ISO 6709 form: decimal degrees, signed and zero-padded, closed by a solidus
  /// (e.g. `'+48.8577+002.295/'`). Round-trips through [parse].
  String get iso6709 =>
      '${_decimalField(latitude, _latitudeDegreeWidth)}'
      '${_decimalField(longitude, _longitudeDegreeWidth)}/';

  /// The display form, degrees-minutes-seconds with a hemisphere letter
  /// (e.g. `'48°51′27.72″N 2°17′42″E'`). Seconds are rounded to two decimals, so it is for display,
  /// not storage; [iso6709] is what round-trips.
  String get sexagesimal =>
      '${_sexagesimalField(latitude, 'N', 'S')} ${_sexagesimalField(longitude, 'E', 'W')}';

  @override
  bool operator ==(Object other) =>
      other is GeoCoordinate && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoCoordinate(latitude: $latitude, longitude: $longitude)';

  // Snapped to a value [iso6709] can spell exactly, so the canonical form always reads back as
  // itself. Identity above 1e-20 degrees. Why: `APPENDIX.md#geo-coordinate-value-type`.
  static double _renderable(double degrees) =>
      double.parse(degrees.toStringAsFixed(_maxFractionDigits));

  // Why these degrees are out of range, or null when they are not. The one gate from, tryFrom, and
  // parse funnel through, so a diagnosis and an acceptance cannot disagree.
  static GeoCoordinateFailure? _rangeFailure(double latitude, double longitude) {
    if (!_isWithin(latitude, maxLatitude)) return GeoCoordinateLatitudeOutOfRange(latitude);

    return _isWithin(longitude, maxLongitude) ? null : GeoCoordinateLongitudeOutOfRange(longitude);
  }

  // A positive test rather than `< -bound || > bound`, so a NaN falls out as out of range.
  static bool _isWithin(double degrees, double bound) => degrees >= -bound && degrees <= bound;

  // Both parts of an ISO 6709 string in decimal degrees, or null when the input isn't that shape.
  static ({double latitude, double longitude})? _degreesOf(String input) {
    final pairMatch = _coordinatePair.firstMatch(input);
    if (pairMatch == null) return null;

    final latitude = _degreesIn(pairMatch, _signGroup, _latitudeDegreeWidth);
    final longitude = _degreesIn(pairMatch, _signGroup + _groupsPerField, _longitudeDegreeWidth);

    return latitude == null || longitude == null
        ? null
        : (latitude: latitude, longitude: longitude);
  }

  // One signed field in decimal degrees, or null when its whole part is not the degree width plus
  // zero, one, or two sexagesimal pairs, or a minute or second reaches 60.
  static double? _degreesIn(RegExpMatch fieldMatch, int signGroup, int degreeWidth) {
    final whole = fieldMatch.group(signGroup + 1)!;
    final sexagesimalDigits = whole.length - degreeWidth;
    if (sexagesimalDigits < 0 ||
        sexagesimalDigits > _minutesAndSecondsWidth ||
        sexagesimalDigits.isOdd) {
      return null;
    }

    final pairCount = sexagesimalDigits ~/ _sexagesimalPairWidth;
    final sexagesimalPairs = Iterable.generate(pairCount, (pair) {
      final start = degreeWidth + pair * _sexagesimalPairWidth;

      return int.parse(whole.substring(start, start + _sexagesimalPairWidth));
    });
    if (sexagesimalPairs.any((pair) => pair >= _sexagesimalBase)) return null;

    final fraction = fieldMatch.group(signGroup + 2) ?? '';

    // Degrees, minutes, and seconds are digits of one base-60 number: fold to a count of the
    // smallest unit the fraction joins, and scale down once. One rounding, not one per field.
    // A plain decimal field skips all of it, because adding the fraction to the degrees rounds a
    // second time and lands up to one ulp off what converting the whole field gives.
    final degrees = int.parse(whole.substring(0, degreeWidth));
    final smallestUnits = sexagesimalPairs.fold(
      degrees,
      (coarserUnits, pair) => coarserUnits * _sexagesimalBase + pair,
    );
    final magnitude = pairCount == 0
        ? double.parse('$whole$fraction')
        : (smallestUnits + double.parse('0$fraction')) / pow(_sexagesimalBase, pairCount);

    return fieldMatch.group(signGroup) == hyphen ? -magnitude : magnitude;
  }

  // One signed, zero-padded decimal field.
  static String _decimalField(double degrees, int degreeWidth) =>
      '${degrees < 0 ? hyphen : '+'}${_wholePadded(_shortestExact(degrees.abs()), degreeWidth)}';

  // Rounding once, on hundredths of a second, then decomposing is what carries 59.999" into the
  // minute instead of rendering it as 60".
  static String _sexagesimalField(double degrees, String positive, String negative) {
    final hundredths = (degrees.abs() * _secondHundredthsPerDegree).round();
    final degreeRemainder = hundredths % _secondHundredthsPerDegree;
    final minutes = degreeRemainder ~/ _secondHundredthsPerMinute;
    final seconds = degreeRemainder % _secondHundredthsPerMinute / _hundredths;

    return '${hundredths ~/ _secondHundredthsPerDegree}°'
        '${_wholePadded('$minutes', _sexagesimalPairWidth)}′'
        '${_wholePadded(_shortestExact(seconds), _sexagesimalPairWidth)}″'
        '${degrees < 0 ? negative : positive}';
  }

  // The shortest fixed-point decimal, over rising decimal-place counts, that reads back as exactly
  // this double. Not toString: it goes exponential below 1e-6, which is not an ISO 6709 field.
  //
  // No orElse: _renderable snaps every stored degree to something the widest candidate spells, and
  // seconds arrive as hundredths, so a StateError here would mean that invariant had broken.
  static String _shortestExact(double magnitude) => Iterable.generate(
    _maxFractionDigits + 1,
    magnitude.toStringAsFixed,
  ).firstWhere((candidate) => double.parse(candidate) == magnitude);

  static String _wholePadded(String decimal, int width) {
    final pointIndex = decimal.indexOf('.');
    final whole = pointIndex < 0 ? decimal : decimal.substring(0, pointIndex);
    final fraction = pointIndex < 0 ? '' : decimal.substring(pointIndex);

    return '${whole.padLeft(width, zeroPad)}$fraction';
  }

  // Sign, whole part, and optional fraction for each of the two fields, then the closing solidus.
  static final _coordinatePair = RegExp(r'^([+-])(\d+)(\.\d+)?([+-])(\d+)(\.\d+)?/$');

  static const _signGroup = 1;
  static const _groupsPerField = 3;

  static const _latitudeDegreeWidth = 2;
  static const _longitudeDegreeWidth = 3;
  static const _sexagesimalPairWidth = 2;
  static const _minutesAndSecondsWidth = 4;
  static const _sexagesimalBase = 60;

  static const _hundredths = 100;
  static const _secondHundredthsPerMinute = _sexagesimalBase * _hundredths;
  static const _secondHundredthsPerDegree = _sexagesimalBase * _secondHundredthsPerMinute;

  // toStringAsFixed's ceiling, and finer than any coordinate a measurement can carry.
  static const _maxFractionDigits = 20;
}
