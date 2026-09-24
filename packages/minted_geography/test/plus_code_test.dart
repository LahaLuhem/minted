import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:minted_geography/minted_geography.dart';
import 'package:open_location_code/open_location_code.dart' as olc;

import '../../../test/support/bdd.dart';

const namedPlusCodes = <PlusCode>{PlusCodeConstants.first};

// The prefix a cell's finer codes share, which drops the padding and the now-trailing separator.
String _cellPrefix(PlusCode code) => code.value.replaceAll(RegExp(r'0*\+$'), '');

void main() {
  feature('PlusCode', () {
    // Every full-code row of the standard's own validityTests.csv, valid and corrupted alike.
    scenarioOutline<({String input, String? canonical})>(
      'PlusCode.tryParse accepts full codes and rejects the rest',
      examples: {
        'a 10-digit code': (input: '8FWC2345+G6', canonical: '8FWC2345+G6'),
        'an 11-digit code': (input: '8FWC2345+G6G', canonical: '8FWC2345+G6G'),
        'lower case is upper-cased': (input: '8fwc2345+', canonical: '8FWC2345+'),
        'surrounding whitespace is trimmed': (input: '  8FWC2345+G6 ', canonical: '8FWC2345+G6'),
        'a padded code': (input: '8FWCX400+', canonical: '8FWCX400+'),
        'padded down to 2 digits': (input: '84000000+', canonical: '84000000+'),
        'the longest the standard prices': (
          input: '849VGJQF+VX7QR3J',
          canonical: '849VGJQF+VX7QR3J',
        ),
        'past that length, still valid': (
          input: '849VGJQF+VX7QR3JW',
          canonical: '849VGJQF+VX7QR3JW',
        ),
        'a short code belongs to the other type': (input: 'WC2345+G6G', canonical: null),
        'a separator with nothing before it': (input: '+G6', canonical: null),
        'an odd digit count before the separator': (input: 'G+', canonical: null),
        'a bare separator': (input: '+', canonical: null),
        'one digit after the separator': (input: '8FWC2345+G', canonical: null),
        'a character outside the alphabet': (input: '8FWC2_45+G6', canonical: null),
        'a non-ASCII character': (input: '8FWC2η45+G6', canonical: null),
        'a second separator': (input: '8FWC2345+G6+', canonical: null),
        'the separator in the wrong place': (input: '8FWC2345G6+', canonical: null),
        'digits after the padding': (input: '8FWC2300+G6', canonical: null),
        'padding starting at an odd offset': (input: '84900000+', canonical: null),
        'an unalphabetic digit past 15': (input: '849VGJQF+VX7QR3JU', canonical: null),
        'an empty string': (input: '', canonical: null),
      },
      outline: (example) {
        check(PlusCode.tryParse(example.input)?.value).equals(example.canonical);
      },
    );

    // Why the type exists: `decode` guards on `isFull`, which says yes to every one of these, so
    // the door is all that stands between a caller and a wrong location.
    scenario('a code the standard refuses never becomes a location', () {
      for (final refused in [
        '8FWC2_45+G6',
        '8FWC2η45+G6',
        '8FWC2345+G6+',
        '8FWC2345G6+',
        '8FWC2300+G6',
        '84900000+',
        '849VGJQF+VX7QR3U',
      ]) {
        check(
          olc.PlusCode.unverified(refused).isFull(),
          because: 'the engine would let $refused through',
        ).isTrue();
        check(PlusCode.tryParse(refused), because: 'the door refuses $refused').isNull();
      }
    });

    scenario('parse names a short code rather than calling it malformed', () {
      check(PlusCode.parse('WC2345+G6G').reasonOrNull).isA<PlusCodeNotFull>();
      check(PlusCode.parse('8FWC2_45+G6').reasonOrNull).isA<PlusCodeMalformed>();
    });

    scenario('a caller who asserts the string gets the throw back through getOrThrow', () {
      check(() => PlusCode.parse('9G8F+6W').getOrThrow())
          .throws<MintedFormatError>()
          .has((error) => error.failure, 'failure')
          .equals(const PlusCodeNotFull('9G8F+6W'));
    });

    // One row per legal digit count, lifted from the standard's encoding.csv.
    scenarioOutline<({double latitude, double longitude, int digits, String code})>(
      'each door builds the code the standard gives for that digit count',
      examples: {
        '2 digits': (
          latitude: 37.539669125,
          longitude: -122.375069724,
          digits: 2,
          code: '84000000+',
        ),
        '4 digits': (latitude: 0.5, longitude: -179.5, digits: 4, code: '62G20000+'),
        '6 digits': (latitude: 20.375, longitude: 2.775, digits: 6, code: '7FG49Q00+'),
        '8 digits': (latitude: -48.71, longitude: 142.78, digits: 8, code: '4R347QRJ+'),
        '10 digits': (latitude: 20.3700625, longitude: 2.7821875, digits: 10, code: '7FG49QCJ+2V'),
        '11 digits': (
          latitude: 20.3701125,
          longitude: 2.782234375,
          digits: 11,
          code: '7FG49QCJ+2VX',
        ),
        '12 digits': (latitude: 13.9, longitude: 164.88, digits: 12, code: '7V56WV2J+2222'),
        '13 digits': (
          latitude: 20.3701135,
          longitude: 2.78223535156,
          digits: 13,
          code: '7FG49QCJ+2VXGJ',
        ),
        '14 digits': (latitude: -52.166, longitude: 13.694, digits: 14, code: '3FVMRMMV+JJ2222'),
        '15 digits': (
          latitude: 37.539669125,
          longitude: -122.375069724,
          digits: 15,
          code: '849VGJQF+VX7QR3J',
        ),
      },
      outline: (example) {
        final here = GeoCoordinate.tryFrom(
          latitude: example.latitude,
          longitude: example.longitude,
        )!;
        final built = switch (example.digits) {
          2 => PlusCode.from2(here),
          4 => PlusCode.from4(here),
          6 => PlusCode.from6(here),
          8 => PlusCode.from8(here),
          10 => PlusCode.from10(here),
          11 => PlusCode.from11(here),
          12 => PlusCode.from12(here),
          13 => PlusCode.from13(here),
          14 => PlusCode.from14(here),
          _ => PlusCode.from15(here),
        };

        check(built.value).equals(example.code);
      },
    );

    scenario('every door builds a code its own parse accepts, at the digits it promises', () {
      final here = GeoCoordinate.tryFrom(latitude: 47.36559, longitude: 8.524997)!;
      final built = {
        2: PlusCode.from2(here),
        4: PlusCode.from4(here),
        6: PlusCode.from6(here),
        8: PlusCode.from8(here),
        10: PlusCode.from10(here),
        11: PlusCode.from11(here),
        12: PlusCode.from12(here),
        13: PlusCode.from13(here),
        14: PlusCode.from14(here),
        15: PlusCode.from15(here),
      };

      for (final MapEntry(key: digits, value: code) in built.entries) {
        check(PlusCode.tryParse(code.value), because: '$digits-digit $code').equals(code);
        check(code.digits, because: '$digits-digit $code').equals(digits);
      }
    });

    scenario('padding does not count towards the digits, and reports itself', () {
      check(PlusCode.tryParse('84000000+')!.digits).equals(2);
      check(PlusCode.tryParse('8FWCX400+')!.digits).equals(6);
      check(PlusCode.tryParse('8FWC2345+')!.digits).equals(8);
      check(PlusCode.tryParse('84000000+')!.isPadded).isTrue();
      check(PlusCode.tryParse('8FWC2345+')!.isPadded).isFalse();
    });

    // From the standard's decoding.csv, which gives the cell rather than the centre.
    scenario('bounds is the cell the standard decodes to', () {
      final cell = PlusCode.tryParse('7FG49Q00+')!.bounds;

      // Within a micrometre, not on the digit: the CSV writes its edges to a fixed number of
      // decimals, so Google's own implementations miss it by the same margin.
      for (final (name, got, want) in [
        ('south', cell.south, 20.35),
        ('west', cell.west, 2.75),
        ('north', cell.north, 20.4),
        ('east', cell.east, 2.8),
      ]) {
        check((got - want).abs(), because: '$name edge of $cell').isLessThan(1e-9);
      }
    });

    scenario('the centre re-encodes to the code it came from', () {
      final code = PlusCode.tryParse('8FVC9G8F+6W')!;

      check(PlusCode.from10(code.centre)).equals(code);
    });

    scenario('every named constant parses back to itself, unchanged', () {
      for (final code in namedPlusCodes) {
        check(
          PlusCode.tryParse(code.value)?.value,
          because: 'named constant $code',
        ).equals(code.value);
      }
    });

    // The floor is the far south-west cell, so a floor that is merely low shows up at a corner.
    scenarioOutline<({double latitude, double longitude})>(
      'no full code anywhere on Earth sorts before the first cell',
      examples: {
        'the south-west corner': (latitude: -90, longitude: -179.9),
        'the antimeridian from the east': (latitude: -90, longitude: 180),
        'the north-east corner': (latitude: 90, longitude: 180),
        'the north pole': (latitude: 90, longitude: 0),
        'the south pole at the prime meridian': (latitude: -90, longitude: 0),
        'the origin': (latitude: 0, longitude: 0),
        'mid-latitude against the western edge': (latitude: 45, longitude: -179.9),
      },
      outline: (example) {
        final corner = GeoCoordinate.tryFrom(
          latitude: example.latitude,
          longitude: example.longitude,
        )!;

        for (final code in <PlusCode>[.from2(corner), .from8(corner), .from15(corner)]) {
          check(
            code.value.compareTo(PlusCodeConstants.first.value),
            because: '$corner gives $code',
          ).isGreaterOrEqual(0);
        }
      },
    );

    // What a prefix range query leans on.
    scenario('a finer code sorts after the cell holding it, and stays inside it', () {
      final here = GeoCoordinate.tryFrom(latitude: 47.36559, longitude: 8.524997)!;
      final ladder = <PlusCode>[
        .from2(here),
        .from4(here),
        .from6(here),
        .from8(here),
        .from10(here),
        .from15(here),
      ];

      for (var step = 0; step + 1 < ladder.length; step++) {
        final (coarse, finer) = (ladder[step], ladder[step + 1]);

        check(
          finer.value.compareTo(coarse.value),
          because: '$finer against $coarse',
        ).isGreaterThan(0);
        check(finer.value, because: '$finer inside $coarse').startsWith(_cellPrefix(coarse));
      }
    });

    // A cell is built by halving a range that starts as the whole Earth, so no edge can overshoot.
    scenario('no cell wraps the antimeridian or leaves the latitude range', () {
      for (final (latitude, longitude) in [
        (0.0, 179.9999),
        (0.0, -179.9999),
        (0.0, 180.0),
        (89.9999, 0.0),
        (-89.9999, 0.0),
        (90.0, 0.0),
        (-90.0, -180.0),
      ]) {
        final here = GeoCoordinate.tryFrom(latitude: latitude, longitude: longitude)!;
        final cell = PlusCode.from11(here).bounds;

        check(cell.crossesAntimeridian, because: 'cell at $latitude,$longitude').isFalse();
        check(cell.contains(here), because: 'cell at $latitude,$longitude').isTrue();
      }
    });
  });
}
