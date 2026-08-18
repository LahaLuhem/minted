import 'package:meta/meta.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';

import 'failures/geo_bounds_failure.dart';
import 'geo_coordinate.dart';
import 'standards/coordinate_bounds.dart';

/// A bounding box: the rectangle between a west, south, east and north edge, which may cross the
/// antimeridian. Standard: [RFC 7946 §5](https://www.rfc-editor.org/rfc/rfc7946#section-5),
/// GeoJSON's `bbox`, whose §5.2 spells the crossing case rather than leaving it to convention.
///
/// Parse, don't validate: `west > east` is not a bug to refuse, it is how §5.2 writes a box across
/// the antimeridian, so `170,-45,-170,-35` is Fiji rather than most of the planet.
/// [crossesAntimeridian] reports it and [contains] honours it, which is the bug this type deletes.
///
/// The edges are numbers, not two [GeoCoordinate] corners: a coordinate folds `-180` onto `+180`,
/// which is one point with two spellings but two distinct edges, and the whole-world box is written
/// `-180,-90,180,90`. Corners are still range-checked through [GeoCoordinate].
///
/// A zero-width (`west == east`) or zero-height (`south == north`) box is legal and degenerate: it
/// holds its own edge, not the planet.
///
/// Normalisation on parse: input is trimmed, one surrounding pair of brackets is dropped, and a
/// negative zero becomes positive.
///
/// Equality is by value over the four edges.
///
/// {@example /example/minted_geography_example.dart#bounds}
@immutable
final class GeoBounds {
  /// The western edge in decimal degrees, `-180` to `180`. Above [east] exactly when the box
  /// crosses the antimeridian.
  final double west;

  /// The southern edge in decimal degrees, `-90` to `90`. Never above [north].
  final double south;

  /// The eastern edge in decimal degrees, `-180` to `180`.
  final double east;

  /// The northern edge in decimal degrees, `-90` to `90`.
  final double north;

  const new _({required this.west, required this.south, required this.east, required this.north});

  /// The box with these four edges, reporting the [GeoBoundsFailure] when a corner is out of range
  /// or the latitudes are the wrong way round. Named parameters, so the four numbers cannot be
  /// written in the wrong order.
  static ParseOutcome<GeoBoundsFailure, GeoBounds> from({
    required double west,
    required double south,
    required double east,
    required double north,
  }) {
    final failure = _edgeFailure(west: west, south: south, east: east, north: north);

    // A negative zero equals a positive one while hashing differently, so it cannot be stored.
    return failure != null
        ? ParseFailure(failure)
        : ParseSuccess(
            GeoBounds._(
              west: positiveZeroed(west),
              south: positiveZeroed(south),
              east: positiveZeroed(east),
              north: positiveZeroed(north),
            ),
          );
  }

  /// The box with these four edges, or `null` when one is out of range or the latitudes are the
  /// wrong way round. Derived from [from], so the two cannot diverge.
  static GeoBounds? tryFrom({
    required double west,
    required double south,
    required double east,
    required double north,
  }) => from(west: west, south: south, east: east, north: north).getOrNull();

  /// Parses [input] as a GeoJSON `bbox`, or returns `null` unless it is four numbers naming a box.
  static GeoBounds? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a GeoJSON `bbox`, reporting the [GeoBoundsFailure] that names what broke.
  static ParseOutcome<GeoBoundsFailure, GeoBounds> parse(String input) {
    final numbers = _numbersOf(input);

    return numbers == null
        ? const ParseFailure(GeoBoundsNotFourNumbers())
        : from(west: numbers.west, south: numbers.south, east: numbers.east, north: numbers.north);
  }

  /// The canonical GeoJSON `bbox` text, `west,south,east,north` (e.g.
  /// `'170.0,-45.0,-170.0,-35.0'`). Round-trips through [parse].
  String get bbox => '$west,$south,$east,$north';

  /// Whether the box wraps the antimeridian, which RFC 7946 §5.2 writes as a western edge east of
  /// the eastern one. The reading a `west <= east` check would refuse outright.
  bool get crossesAntimeridian => west > east;

  /// Whether [coordinate] falls inside, edges included, honouring a box that wraps.
  bool contains(GeoCoordinate coordinate) =>
      coordinate.latitude >= south &&
      coordinate.latitude <= north &&
      _holdsLongitude(coordinate.longitude);

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.west == west &&
      other.south == south &&
      other.east == east &&
      other.north == north;

  @override
  int get hashCode => Object.hash(west, south, east, north);

  @override
  String toString() => 'GeoBounds(west: $west, south: $south, east: $east, north: $north)';

  // A coordinate folds -180 onto +180, so the antimeridian only ever arrives as the plus spelling
  // and a box whose western edge is the minus one has to be offered both.
  bool _holdsLongitude(double longitude) =>
      _spansLongitude(longitude) || (longitude == maxLongitude && _spansLongitude(-maxLongitude));

  // Outside the west-to-east interval is what inside means for a box that wraps.
  bool _spansLongitude(double longitude) => crossesAntimeridian
      ? longitude >= west || longitude <= east
      : longitude >= west && longitude <= east;

  // Why these edges are not a box, or null when they are. The corners go through GeoCoordinate, so
  // the range diagnosis has one producer rather than four variants re-declared here.
  static GeoBoundsFailure? _edgeFailure({
    required double west,
    required double south,
    required double east,
    required double north,
  }) {
    final cornerFailure =
        GeoCoordinate.from(latitude: south, longitude: west).reasonOrNull ??
        GeoCoordinate.from(latitude: north, longitude: east).reasonOrNull;
    if (cornerFailure != null) return GeoBoundsInvalidCorner(cornerFailure);

    return south > north ? GeoBoundsSouthAboveNorth(south: south, north: north) : null;
  }

  // The four numbers in [input], or null when it holds anything else.
  static ({double west, double south, double east, double north})? _numbersOf(String input) {
    final trimmedInput = input.trim();
    final unwrapped = _bracketed.firstMatch(trimmedInput)?.group(1) ?? trimmedInput;

    return switch (unwrapped.split(_separator).map(double.tryParse).toList()) {
      [final west?, final south?, final east?, final north?] => (
        west: west,
        south: south,
        east: east,
        north: north,
      ),
      _ => null,
    };
  }

  // One surrounding pair, so a bbox pasted out of GeoJSON parses. dotAll for a pretty-printed
  // array, whose newlines double.tryParse then trims.
  static final _bracketed = RegExp(r'^\[(.*)\]$', dotAll: true);

  static const _separator = ',';
}
