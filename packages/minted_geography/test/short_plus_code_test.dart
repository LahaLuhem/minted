import 'package:checks/checks.dart';
import 'package:minted_geography/minted_geography.dart';

import '../../../test/support/bdd.dart';

/// The reference the standard's shortCodeTests.csv uses throughout.
final _near = GeoCoordinate.tryFrom(latitude: 51.3701125, longitude: -1.217765625)!;

void main() {
  feature('ShortPlusCode', () {
    // The short rows of the standard's own validityTests.csv, plus the full ones it must turn away.
    scenarioOutline<({String input, String? canonical})>(
      'ShortPlusCode.tryParse accepts shortened codes and rejects the rest',
      examples: {
        'six digits dropped': (input: 'WC2345+G6g', canonical: 'WC2345+G6G'),
        'four digits dropped': (input: '2345+G6', canonical: '2345+G6'),
        'six digits dropped, shorter tail': (input: '45+G6', canonical: '45+G6'),
        'everything before the separator dropped': (input: '+G6', canonical: '+G6'),
        'surrounding whitespace is trimmed': (input: ' 2345+G6 ', canonical: '2345+G6'),
        'a full code belongs to the other type': (input: '8FWC2345+G6', canonical: null),
        'a padded full code, also not short': (input: '8FWCX400+', canonical: null),
        'a shortened code cannot be padded': (input: 'WC2300+', canonical: null),
        'padding with digits after it': (input: 'WC2300+G6g', canonical: null),
        'one digit after the separator': (input: 'WC2345+G', canonical: null),
        'a bare separator': (input: '+', canonical: null),
        'an empty string': (input: '', canonical: null),
      },
      outline: (example) {
        check(ShortPlusCode.tryParse(example.input)?.value).equals(example.canonical);
      },
    );

    scenario('parse names a full code rather than calling it malformed', () {
      check(ShortPlusCode.parse('8FWC2345+G6').reasonOrNull).isA<PlusCodeNotShort>();
      check(ShortPlusCode.parse('WC2300+G6g').reasonOrNull).isA<PlusCodeMalformed>();
    });

    // The reason this is its own type: 1 string, 2 places.
    scenario('the same short code recovers to different places near different references', () {
      final short = ShortPlusCode.tryParse('9G8F+6W')!;
      final zurich = GeoCoordinate.tryFrom(latitude: 47.5, longitude: 8.5)!;
      final sydney = GeoCoordinate.tryFrom(latitude: -33.9, longitude: 151.2)!;

      check(short.recoverNear(zurich).value).equals('8FVC9G8F+6W');
      check(short.recoverNear(sydney).value).equals('4RRH9G8F+6W');
      check(short.recoverNear(zurich)).not((it) => it.equals(short.recoverNear(sydney)));
    });

    // Rows from the standard's shortCodeTests.csv.
    scenarioOutline<({String full, String short})>(
      'recovery gives back the full code the standard pairs with that reference',
      examples: {
        'two digits dropped': (full: '9C3W9QCJ+2VX', short: 'CJ+2VX'),
        'four digits dropped': (full: '9C3W9QCJ+2VX', short: '9QCJ+2VX'),
        'six digits dropped': (full: '9C3W9QCJ+2VX', short: '+2VX'),
      },
      outline: (example) {
        check(ShortPlusCode.tryParse(example.short)!.recoverNear(_near).value).equals(example.full);
      },
    );

    scenario('shortening and recovering is a round trip', () {
      final full = PlusCode.tryParse('9C3W9QCJ+2VX')!;
      final short = full.shortenNear(_near);

      check(short).isNotNull();
      check(short!.recoverNear(_near)).equals(full);
    });

    scenario('shortening gives null when the reference is too far for a digit to go', () {
      final full = PlusCode.tryParse('8FVC9G8F+6W')!;
      final sydney = GeoCoordinate.tryFrom(latitude: -33.9, longitude: 151.2)!;

      check(full.shortenNear(sydney)).isNull();
    });

    // The standard forbids it outright, so isPadded is the answer rather than a far reference.
    scenario('a padded code never shortens, however close the reference', () {
      final padded = PlusCode.tryParse('8FVC0000+')!;
      final inside = padded.centre;

      check(padded.isPadded).isTrue();
      check(padded.shortenNear(inside)).isNull();
    });

    scenario('recovery holds at the poles, the antimeridian and the origin', () {
      final short = ShortPlusCode.tryParse('9G8F+6W')!;

      for (final (latitude, longitude) in [
        (0.0, 0.0),
        (89.9, 179.9),
        (-89.9, -179.9),
        (0.0, 180.0),
        (90.0, 0.0),
        (-90.0, -180.0),
      ]) {
        final reference = GeoCoordinate.tryFrom(latitude: latitude, longitude: longitude)!;
        final recovered = short.recoverNear(reference);

        check(
          PlusCode.tryParse(recovered.value),
          because: 'recovered near $latitude,$longitude',
        ).equals(recovered);
      }
    });
  });
}
