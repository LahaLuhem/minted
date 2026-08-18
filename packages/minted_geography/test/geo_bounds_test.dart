import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:minted_geography/minted_geography.dart';

import 'support/bdd.dart';

void main() {
  feature('GeoBounds', () {
    // Acceptance and normalisation in one table: the canonical bbox doubles as the expected
    // outcome. A String means "accepted and normalised to this"; null means "rejected".
    scenarioOutline<({String input, String? canonical})>(
      'tryParse takes the GeoJSON bbox form and rejects the rest',
      examples: {
        'Fiji, crossing the antimeridian': (
          input: '170,-45,-170,-35',
          canonical: '170.0,-45.0,-170.0,-35.0',
        ),
        'the brackets GeoJSON writes it in': (
          input: '[170,-45,-170,-35]',
          canonical: '170.0,-45.0,-170.0,-35.0',
        ),
        'a space after each comma': (
          input: '170, -45, -170, -35',
          canonical: '170.0,-45.0,-170.0,-35.0',
        ),
        'a pretty-printed array': (
          input: '[\n  170,\n  -45,\n  -170,\n  -35\n]',
          canonical: '170.0,-45.0,-170.0,-35.0',
        ),
        'surrounding whitespace is not part of the value': (
          input: '  170,-45,-170,-35\n',
          canonical: '170.0,-45.0,-170.0,-35.0',
        ),
        // The commonest bbox there is, and the one a folded -180 would turn into a meridian line.
        'the whole world': (input: '-180,-90,180,90', canonical: '-180.0,-90.0,180.0,90.0'),
        'a zero-width box is its own meridian, not the planet': (
          input: '10,20,10,30',
          canonical: '10.0,20.0,10.0,30.0',
        ),
        'a zero-area box is a point': (input: '10,20,10,20', canonical: '10.0,20.0,10.0,20.0'),
        'a negative zero takes the positive sign': (
          input: '-0,-0,0,0',
          canonical: '0.0,0.0,0.0,0.0',
        ),
        'exponent notation is still a number': (
          input: '1e2,0,1.5e2,10',
          canonical: '100.0,0.0,150.0,10.0',
        ),
        'three numbers': (input: '170,-45,-170', canonical: null),
        'five numbers': (input: '170,-45,-170,-35,0', canonical: null),
        'an opening bracket with no closing one': (input: '[170,-45,-170,-35', canonical: null),
        'an empty array': (input: '[]', canonical: null),
        'an empty string': (input: '', canonical: null),
        'words where numbers go': (input: 'west,south,east,north', canonical: null),
        'a latitude past the pole': (input: '0,-91,10,10', canonical: null),
        'a longitude past the antimeridian': (input: '181,0,10,10', canonical: null),
        'south above north': (input: '0,50,10,10', canonical: null),
      },
      outline: (example) {
        check(GeoBounds.tryParse(example.input)?.bbox).equals(example.canonical);
      },
    );

    // Three remedies from one door: supply four numbers, fix a corner, or swap the latitudes.
    scenarioOutline<({String input, GeoBoundsFailure failure})>(
      'parse reports which rule broke, not just the shape',
      examples: {
        'not four numbers at all': (
          input: '170,-45,-170',
          failure: const GeoBoundsNotFourNumbers(),
        ),
        'a corner keeps its own diagnosis rather than being flattened': (
          input: '0,-91,10,10',
          failure: const GeoBoundsInvalidCorner(GeoCoordinateLatitudeOutOfRange(-91)),
        ),
        'a longitude corner too': (
          input: '181,0,10,10',
          failure: const GeoBoundsInvalidCorner(GeoCoordinateLongitudeOutOfRange(181)),
        ),
        'the latitudes the wrong way round': (
          input: '0,50,10,10',
          failure: const GeoBoundsSouthAboveNorth(south: 50, north: 10),
        ),
      },
      outline: (example) =>
          check(GeoBounds.parse(example.input).reasonOrNull).equals(example.failure),
    );

    // The reason the type exists: west past east is RFC 7946 §5.2's spelling, not a transposition.
    scenarioOutline<({String input, bool crosses})>(
      'crossesAntimeridian reports the wrap rather than refusing it',
      examples: {
        'Fiji, west past east': (input: '170,-45,-170,-35', crosses: true),
        'an ordinary box': (input: '-10,-45,10,-35', crosses: false),
        'the whole world': (input: '-180,-90,180,90', crosses: false),
        'a zero-width box': (input: '10,20,10,30', crosses: false),
      },
      outline: (example) =>
          check(GeoBounds.tryParse(example.input)!.crossesAntimeridian).equals(example.crosses),
    );

    scenarioOutline<({String bounds, double latitude, double longitude, bool held})>(
      'contains honours a box that wraps, where a plain range check would not',
      examples: {
        'inside a crossing box, east of the wrap': (
          bounds: '170,-45,-170,-35',
          latitude: -40,
          longitude: 179,
          held: true,
        ),
        'inside a crossing box, west of the wrap': (
          bounds: '170,-45,-170,-35',
          latitude: -40,
          longitude: -175,
          held: true,
        ),
        // The symptom when the crossing is not modelled: this reads as inside.
        'the long way round is outside': (
          bounds: '170,-45,-170,-35',
          latitude: -40,
          longitude: 0,
          held: false,
        ),
        'inside an ordinary box': (
          bounds: '-10,-45,10,-35',
          latitude: -40,
          longitude: 0,
          held: true,
        ),
        'outside an ordinary box': (
          bounds: '-10,-45,10,-35',
          latitude: -40,
          longitude: 20,
          held: false,
        ),
        'a corner counts as inside': (
          bounds: '-10,-45,10,-35',
          latitude: -45,
          longitude: -10,
          held: true,
        ),
        'the latitude is checked too': (
          bounds: '-10,-45,10,-35',
          latitude: 0,
          longitude: 0,
          held: false,
        ),
        // A coordinate folds -180 onto +180, so this arrives spelled as the far edge.
        'the antimeridian is on a box whose western edge is its minus spelling': (
          bounds: '-180,-45,-170,-35',
          latitude: -40,
          longitude: -180,
          held: true,
        ),
        'the whole world holds everything': (
          bounds: '-180,-90,180,90',
          latitude: -40,
          longitude: 179,
          held: true,
        ),
        'a zero-width box holds its own meridian': (
          bounds: '10,20,10,30',
          latitude: 25,
          longitude: 10,
          held: true,
        ),
        'and nothing beside it': (
          bounds: '10,20,10,30',
          latitude: 25,
          longitude: 10.5,
          held: false,
        ),
      },
      outline: (example) {
        final bounds = GeoBounds.tryParse(example.bounds)!;
        final coordinate = GeoCoordinate.tryFrom(
          latitude: example.latitude,
          longitude: example.longitude,
        )!;

        check(bounds.contains(coordinate)).equals(example.held);
      },
    );

    scenario('parse reports the failure rather than throwing', () {
      check(GeoBounds.parse('0,50,10,10'))
          .equals(const ParseFailure(GeoBoundsSouthAboveNorth(south: 50, north: 10)));
      check(GeoBounds.parse('-10,-45,10,-35'))
          .equals(ParseSuccess(GeoBounds.tryFrom(west: -10, south: -45, east: 10, north: -35)!));
    });

    // Constrained edges leave one way to fail, so from still answers an outcome where
    // GeoCoordinate.from became total.
    scenario('from takes constrained degrees and only the latitude order can still fail', () {
      final ordered = GeoBounds.from(
        west: Longitude.tryFrom(-10)!,
        south: Latitude.tryFrom(-45)!,
        east: Longitude.tryFrom(10)!,
        north: Latitude.tryFrom(-35)!,
      );
      final inverted = GeoBounds.from(
        west: Longitude.tryFrom(-10)!,
        south: Latitude.tryFrom(50)!,
        east: Longitude.tryFrom(10)!,
        north: Latitude.tryFrom(10)!,
      );

      check(ordered.getOrThrow().bbox).equals('-10.0,-45.0,10.0,-35.0');
      check(inverted.reasonOrNull).equals(const GeoBoundsSouthAboveNorth(south: 50, north: 10));
    });

    // The point of the typed getters: a box builds straight out of two coordinates, with no range
    // re-check and no bang. A west edge *on* the antimeridian still has to be spelled -180 by hand,
    // a coordinate having folded it to +180 already.
    scenario('a box composes from coordinates without re-proving their degrees', () {
      final southWest = GeoCoordinate.tryFrom(latitude: -45, longitude: -10)!;
      final northEast = GeoCoordinate.tryFrom(latitude: -35, longitude: 10)!;

      final box = GeoBounds.from(
        west: southWest.longitude,
        south: southWest.latitude,
        east: northEast.longitude,
        north: northEast.latitude,
      ).getOrThrow();

      check(box.bbox).equals('-10.0,-45.0,10.0,-35.0');
      check(box.contains(southWest)).isTrue();
    });

    scenario('tryFrom takes raw numbers and returns null when they are not a box', () {
      check(GeoBounds.tryFrom(west: -10, south: -45, east: 10, north: -35)!.bbox)
          .equals('-10.0,-45.0,10.0,-35.0');
      check(GeoBounds.tryFrom(west: 170, south: -45, east: -170, north: -35)).isNotNull();
      check(GeoBounds.tryFrom(west: 0, south: 50, east: 10, north: 10)).isNull();
      check(GeoBounds.tryFrom(west: 181, south: 0, east: 10, north: 10)).isNull();
    });

    scenario('a caller who asserts the edges gets the throw back through getOrThrow', () {
      check(() => GeoBounds.parse('0,50,10,10').getOrThrow())
          .throws<MintedFormatError>()
          .has((error) => error.failure, 'failure')
          .equals(const GeoBoundsSouthAboveNorth(south: 50, north: 10));
    });

    scenario('a NaN or an infinity is out of range on the corner that carries it', () {
      check(GeoBounds.tryFrom(west: double.nan, south: 0, east: 10, north: 10)).isNull();
      check(GeoBounds.tryFrom(west: 0, south: double.infinity, east: 10, north: 10)).isNull();
    });

    scenario('the canonical form round-trips through parse', () {
      for (final input in ['170,-45,-170,-35', '-180,-90,180,90', '10,20,10,20', '0,0,0,0']) {
        final bounds = GeoBounds.tryParse(input)!;

        check(GeoBounds.tryParse(bounds.bbox)!).equals(bounds);
      }
    });

    scenario('equal boxes are equal by value and hash, negative zero included', () {
      check(GeoBounds.tryParse('170,-45,-170,-35'))
          .equals(GeoBounds.tryParse('[170, -45, -170, -35]'));
      check(GeoBounds.tryParse('-0,-0,0,0')?.hashCode)
          .equals(GeoBounds.tryParse('0,0,0,0')?.hashCode);
    });

    scenario('a box and its transposition are different boxes', () {
      check(GeoBounds.tryParse('170,-45,-170,-35') == GeoBounds.tryParse('-170,-45,170,-35'))
          .isFalse();
    });

    scenario('toString names every edge, so a transposition is visible', () {
      check(GeoBounds.tryParse('170,-45,-170,-35')?.toString())
          .equals('GeoBounds(west: 170.0, south: -45.0, east: -170.0, north: -35.0)');
    });
  });
}
