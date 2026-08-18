import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:minted_geography/minted_geography.dart';

import 'support/bdd.dart';

void main() {
  feature('GeoCoordinate', () {
    // Acceptance and normalisation in one table: the canonical decimal-degree form doubles as the
    // expected outcome. A String means "accepted and normalised to this"; null means "rejected".
    // The valid rows are the examples published with ISO 6709, one per field width.
    scenarioOutline<({String input, String? canonical})>(
      'tryParse accepts the three ISO 6709 widths and rejects the rest',
      examples: {
        'the Atlantic, whole degrees': (input: '+00-025/', canonical: '+00-025/'),
        'France, whole degrees': (input: '+46+002/', canonical: '+46+002/'),
        'the Eiffel Tower, mixed precision': (
          input: '+48.8577+002.295/',
          canonical: '+48.8577+002.295/',
        ),
        'the Statue of Liberty': (input: '+40.6894-074.0447/', canonical: '+40.6894-074.0447/'),
        'the North Pole, where longitude is meaningless but still required': (
          input: '+90+000/',
          canonical: '+90+000/',
        ),
        'a trailing zero is not part of the value': (
          input: '+48.52+002.20/',
          canonical: '+48.52+002.2/',
        ),
        'a whole degree loses its fraction': (input: '+40.75-074.00/', canonical: '+40.75-074/'),
        'degrees and minutes': (input: '+5012-00010/', canonical: '+50.2-000.16666666666666666/'),
        // A repeating fraction keeps every digit it needs to read back as the same double.
        'degrees, minutes, and seconds': (
          input: '+501234-0001042/',
          canonical: '+50.20944444444444-000.17833333333333334/',
        ),
        'a fraction rides on the minutes when minutes are the smallest unit': (
          input: '+4012.22-07500.25/',
          canonical: '+40.20366666666666-075.00416666666666/',
        ),
        'a fraction rides on the seconds when seconds are': (
          input: '+401213.1-0750015.1/',
          canonical: '+40.20363888888889-075.00419444444444/',
        ),
        'the antimeridian folds onto its plus spelling': (input: '+00-180/', canonical: '+00+180/'),
        'a negative zero takes the sign the standard gives the equator': (
          input: '-00-000/',
          canonical: '+00+000/',
        ),
        'a fraction too small for exponent-free toString': (
          input: '+00.0000001+000/',
          canonical: '+00.0000001+000/',
        ),
        'surrounding whitespace is not part of the value': (
          input: '  +48.8577+002.295/\n',
          canonical: '+48.8577+002.295/',
        ),
        'a space between the fields is': (input: '+48.8577 +002.295/', canonical: null),
        'an unsigned latitude': (input: '50.12-000.10/', canonical: null),
        'no closing solidus': (input: '+50.12-000.10', canonical: null),
        // Fixed widths are the whole reason this must fail: a loose parser reads it as a plausible
        // but wrong location rather than as an error.
        'an unpadded longitude': (input: '+46+2/', canonical: null),
        'a three-digit latitude, which is no width at all': (input: '+050+000/', canonical: null),
        'minutes reaching 60': (input: '+5060+00000/', canonical: null),
        'a latitude past the pole': (input: '+91+000/', canonical: null),
        'a longitude past the antimeridian': (input: '+00+181/', canonical: null),
        // Both are valid ISO 6709, and both are out of this type's scope.
        'Mount Everest, carrying altitude and a CRS': (
          input: '+27.5916+086.5640+8850CRSWGS_84/',
          canonical: null,
        ),
        'the South Pole, carrying depth and a CRS': (
          input: '-90+000+2800CRSWGS_84/',
          canonical: null,
        ),
        'a bare decimal pair': (input: '48.8577, 2.295', canonical: null),
        'an empty string': (input: '', canonical: null),
      },
      outline: (example) {
        check(GeoCoordinate.tryParse(example.input)?.iso6709).equals(example.canonical);
      },
    );

    // Two remedies from one door: fix the format, or fix a number.
    scenarioOutline<({String input, GeoCoordinateFailure failure})>(
      'parse reports which part is wrong, not just the shape',
      examples: {
        'a missing sign never had the shape': (
          input: '50.12-000.10/',
          failure: const GeoCoordinateNotIso6709(),
        ),
        'minutes reaching 60 are a grammar failure, not a range one': (
          input: '+5060+00000/',
          failure: const GeoCoordinateNotIso6709(),
        ),
        'a latitude past the pole': (
          input: '+91+000/',
          failure: const GeoCoordinateLatitudeOutOfRange(91),
        ),
        'a longitude past the antimeridian': (
          input: '+00+181/',
          failure: const GeoCoordinateLongitudeOutOfRange(181),
        ),
      },
      outline: (example) =>
          check(GeoCoordinate.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('parse reports the failure rather than throwing', () {
      check(GeoCoordinate.parse('+91+000/'))
          .equals(const ParseFailure(GeoCoordinateLatitudeOutOfRange(91)));
      check(GeoCoordinate.parse('+00+000/'))
          .equals(ParseSuccess(GeoCoordinate.tryFrom(latitude: 0, longitude: 0)!));
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(GeoCoordinate.tryParse('+91+000/')).isNull();
      check(GeoCoordinate.tryParse('+48.8577+002.295/'))
          .equals(GeoCoordinate.tryFrom(latitude: 48.8577, longitude: 2.295));
    });

    scenario('from takes constrained degrees and cannot fail, tryFrom takes raw ones', () {
      check(
        GeoCoordinate.from(
          latitude: Latitude.tryFrom(48.8577)!,
          longitude: Longitude.tryFrom(2.295)!,
        ).iso6709,
      ).equals('+48.8577+002.295/');
      check(GeoCoordinate.tryFrom(latitude: 90, longitude: -180)).isNotNull();
      check(GeoCoordinate.tryFrom(latitude: 90.1, longitude: 0)).isNull();
      check(GeoCoordinate.tryFrom(latitude: 0, longitude: -180.1)).isNull();
    });

    // The range moved into the degree types, so the assembly doors prevent it rather than report
    // it. The diagnosis survives on parse, the one door that meets text nobody has checked.
    scenario('the degree types refuse what is out of range, and parse is what names it', () {
      check(Latitude.tryFrom(91)).isNull();
      check(Longitude.tryFrom(181)).isNull();
      check(GeoCoordinate.parse('+91+000/').reasonOrNull)
          .equals(const GeoCoordinateLatitudeOutOfRange(91));
      check(GeoCoordinate.parse('+00+181/').reasonOrNull?.message)
          .equals('longitude 181.0 is outside -180 to 180');
    });

    scenario('a caller who asserts the text gets the throw back through getOrThrow', () {
      check(() => GeoCoordinate.parse('+91+000/').getOrThrow())
          .throws<MintedFormatError>()
          .has((error) => error.failure, 'failure')
          .equals(const GeoCoordinateLatitudeOutOfRange(91));
    });

    // Latitude's narrower range catches the swaps outright; named parameters catch the rest.
    scenario('a swapped pair whose longitude exceeds 90 is refused', () {
      check(GeoCoordinate.tryFrom(latitude: 174.7762, longitude: -36.8509)).isNull();
      check(GeoCoordinate.tryFrom(latitude: -36.8509, longitude: 174.7762)).isNotNull();
    });

    scenario('a NaN or an infinity is out of range', () {
      check(GeoCoordinate.tryFrom(latitude: double.nan, longitude: 0)).isNull();
      check(GeoCoordinate.tryFrom(latitude: 0, longitude: double.nan)).isNull();
      check(GeoCoordinate.tryFrom(latitude: double.infinity, longitude: 0)).isNull();
      check(GeoCoordinate.tryFrom(latitude: 0, longitude: double.negativeInfinity)).isNull();
    });

    scenario('the antimeridian is one value with two spellings', () {
      check(GeoCoordinate.tryFrom(latitude: 0, longitude: -180)!)
          .equals(GeoCoordinate.tryFrom(latitude: 0, longitude: 180)!);
      check(GeoCoordinate.tryFrom(latitude: 0, longitude: -180)!.longitude.value).equals(180);
    });

    // -0.0 == 0.0 while the two need not hash alike, so storing one would break Set and Map keys.
    scenario('a negative zero is normalised away', () {
      // -0 in a double context is IEEE negative zero, not integer zero.
      final origin = GeoCoordinate.tryFrom(latitude: -0, longitude: -0)!;

      check(origin.iso6709).equals('+00+000/');
      check(origin.hashCode).equals(GeoCoordinate.tryFrom(latitude: 0, longitude: 0)!.hashCode);
    });

    scenario('equal coordinates are equal by value and hash', () {
      check(GeoCoordinate.tryFrom(latitude: 48.8577, longitude: 2.295)!)
          .equals(GeoCoordinate.tryFrom(latitude: 48.8577, longitude: 2.295)!);
      check(GeoCoordinate.tryFrom(latitude: 48.8577, longitude: 2.295)!.hashCode)
          .equals(GeoCoordinate.tryFrom(latitude: 48.8577, longitude: 2.295)!.hashCode);
    });

    scenario('a transposed pair is not the same coordinate', () {
      check(
        GeoCoordinate.tryFrom(latitude: 40, longitude: 2)! ==
            GeoCoordinate.tryFrom(latitude: 2, longitude: 40)!,
      ).isFalse();
    });

    scenario('the canonical form round-trips through parse, sexagesimal input included', () {
      for (final input in ['+48.8577+002.295/', '+501234-0001042/', '+00-180/', '+90+000/']) {
        final coordinate = GeoCoordinate.tryParse(input)!;

        check(GeoCoordinate.tryParse(coordinate.iso6709)!).equals(coordinate);
      }
    });

    // Converting the whole field in one go, rather than adding the fraction to the degrees, which
    // rounds a second time and lands an ulp away for about one coordinate in four hundred.
    scenario('a full-precision decimal field parses to the exact double', () {
      final coordinate = GeoCoordinate.tryParse('+06.523984073660007-006.45826944430357/')!;

      check(coordinate.latitude.value).equals(6.523984073660007);
      check(coordinate.longitude.value).equals(-6.45826944430357);
    });

    // The canonical form spells at most 20 fraction digits, so a finer degree is snapped to one it
    // can. Without that, distinct coordinates render alike and the rendering reads back as neither.
    scenario('a degree finer than the canonical form can spell is snapped to one it can', () {
      final subAtomic = GeoCoordinate.tryFrom(latitude: 3.7182818284590454e-13, longitude: 0)!;

      check(GeoCoordinate.tryParse(subAtomic.iso6709)!).equals(subAtomic);
      check(GeoCoordinate.tryParse('+00.00000000000000000001+000.0000/')!.latitude.value)
          .equals(1e-20);
      check(GeoCoordinate.tryParse('+00.000000000000000000001+000.0000/')!.latitude.value)
          .equals(0);
    });

    scenario('a degree that snaps to zero from below is still a positive zero', () {
      final southOfNothing = GeoCoordinate.tryFrom(latitude: -1e-30, longitude: -1e-30)!;

      check(southOfNothing.iso6709).equals('+00+000/');
      check(southOfNothing.hashCode)
          .equals(GeoCoordinate.tryFrom(latitude: 0, longitude: 0)!.hashCode);
    });

    scenario('sexagesimal rebuilds the display form', () {
      check(GeoCoordinate.tryParse('+48.8577+002.295/')!.sexagesimal)
          .equals('48°51′27.72″N 2°17′42″E');
      check(GeoCoordinate.tryParse('+00-025/')!.sexagesimal).equals('0°00′00″N 25°00′00″W');
      check(GeoCoordinate.tryFrom(latitude: 5.5 / 3600, longitude: 0)!.sexagesimal)
          .equals('0°00′05.5″N 0°00′00″E');
    });

    // Rounding the seconds field instead would print 0°59′60″N.
    scenario('a rounded second carries into the minute and the degree', () {
      check(GeoCoordinate.tryFrom(latitude: 0.99999999, longitude: 0)!.sexagesimal)
          .equals('1°00′00″N 0°00′00″E');
    });

    scenario('toString names both parts, so a transposition is visible', () {
      check(GeoCoordinate.tryFrom(latitude: 48.8577, longitude: 2.295)!.toString())
          .equals('GeoCoordinate(latitude: 48.8577, longitude: 2.295)');
    });
  });
}
