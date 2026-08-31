import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

import 'failures/geo_bounds_failure.dart';
import 'geo_coordinate.dart';
import 'latitude.dart';
import 'longitude.dart';
import 'standards/coordinate_bounds.dart';

/// A bounding box: the rectangle between a west, south, east and north edge, which may cross the
/// antimeridian. Standard: [RFC 7946 §5](https://www.rfc-editor.org/rfc/rfc7946#section-5),
/// GeoJSON's `bbox`, whose §5.2 spells the crossing case rather than leaving it to convention.
///
/// Parse, don't validate: `west > east` is not a bug to refuse, it is how §5.2 writes a box across
/// the antimeridian, so `170,-45,-170,-35` is Fiji. [crossesAntimeridian] reports it and [contains]
/// honours it.
///
/// The edges are a [Longitude] and a [Latitude] pair rather than two [GeoCoordinate] corners, so
/// [from] leaves only the latitude order to fail. [tryFrom] takes raw numbers. A zero-width
/// (`west == east`) or zero-height box is legal, and holds its own edge.
///
/// Normalisation on parse: input is trimmed and one surrounding pair of brackets is dropped.
///
/// Equality is by value over the four edges.
///
/// {@example /example/minted_geography_example.dart#bounds}
@immutable
final class GeoBounds {
  /// The western edge. Above [east] exactly when the box crosses the antimeridian. A `double`, so
  /// arithmetic and formatting need no unwrapping.
  final Longitude west;

  /// The southern edge. Never above [north].
  final Latitude south;

  /// The eastern edge.
  final Longitude east;

  /// The northern edge.
  final Latitude north;

  const new _({required this.west, required this.south, required this.east, required this.north});

  /// The box with these four edges, reporting [GeoBoundsSouthAboveNorth] when the latitudes are the
  /// wrong way round. The only failure left: the edges carry their own ranges, and west past east
  /// is the crossing rather than a mistake.
  static ParseOutcome<GeoBoundsFailure, GeoBounds> from({
    required Longitude west,
    required Latitude south,
    required Longitude east,
    required Latitude north,
  }) => south > north
      ? ParseFailure(GeoBoundsSouthAboveNorth(south: south, north: north))
      : ParseSuccess(GeoBounds._(west: west, south: south, east: east, north: north));

  /// The box with these four edges in decimal degrees, or `null` when one is out of range or the
  /// latitudes are the wrong way round. The raw-number door, where [from] takes degrees already
  /// constrained.
  static GeoBounds? tryFrom({
    required num west,
    required num south,
    required num east,
    required num north,
  }) {
    final boundedWest = Longitude.tryFrom(west);
    final boundedSouth = Latitude.tryFrom(south);
    final boundedEast = Longitude.tryFrom(east);
    final boundedNorth = Latitude.tryFrom(north);

    return boundedWest == null ||
            boundedSouth == null ||
            boundedEast == null ||
            boundedNorth == null
        ? null
        : from(
            west: boundedWest,
            south: boundedSouth,
            east: boundedEast,
            north: boundedNorth,
          ).getOrNull();
  }

  /// Parses [input] as a GeoJSON `bbox`, or returns `null` unless it is four numbers naming a box.
  static GeoBounds? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a GeoJSON `bbox`, reporting the [GeoBoundsFailure] that names what broke.
  static ParseOutcome<GeoBoundsFailure, GeoBounds> parse(String input) {
    final numbers = _numbersOf(input);
    if (numbers == null) return const ParseFailure(GeoBoundsNotFourNumbers());

    final (:west, :south, :east, :north) = numbers;
    final cornerFailure =
        degreesFailure(latitude: south, longitude: west) ??
        degreesFailure(latitude: north, longitude: east);

    // Past the diagnosis every edge is in range, so the constrained doors cannot answer null.
    return cornerFailure != null
        ? ParseFailure(GeoBoundsInvalidCorner(cornerFailure))
        : from(
            west: Longitude.tryFrom(west)!,
            south: Latitude.tryFrom(south)!,
            east: Longitude.tryFrom(east)!,
            north: Latitude.tryFrom(north)!,
          );
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
