import 'package:checks/checks.dart';
import 'package:minted_geography/minted_geography.dart';

import 'support/bdd.dart';

void main() {
  feature('Latitude and Longitude', () {
    scenarioOutline<({num degrees, bool accepted})>(
      'Latitude holds -90 to 90 and nothing beyond',
      examples: {
        'the equator': (degrees: 0, accepted: true),
        'the north pole': (degrees: 90, accepted: true),
        'the south pole': (degrees: -90, accepted: true),
        'an int, since degrees are written both ways': (degrees: 48, accepted: true),
        'past the north pole': (degrees: 90.1, accepted: false),
        'past the south pole': (degrees: -90.1, accepted: false),
        'a longitude that would have fitted': (degrees: 174.7762, accepted: false),
        'a NaN, the bound being a positive test': (degrees: double.nan, accepted: false),
        'an infinity': (degrees: double.infinity, accepted: false),
      },
      outline: (example) =>
          check(Latitude.tryFrom(example.degrees) != null).equals(example.accepted),
    );

    scenarioOutline<({num degrees, bool accepted})>(
      'Longitude holds -180 to 180 and nothing beyond',
      examples: {
        'the prime meridian': (degrees: 0, accepted: true),
        'the antimeridian': (degrees: 180, accepted: true),
        'its minus spelling, which is a different edge': (degrees: -180, accepted: true),
        'past the antimeridian': (degrees: 180.1, accepted: false),
        'a NaN': (degrees: double.nan, accepted: false),
        'a negative infinity': (degrees: double.negativeInfinity, accepted: false),
      },
      outline: (example) =>
          check(Longitude.tryFrom(example.degrees) != null).equals(example.accepted),
    );

    // GeoCoordinate folds -180 onto +180 because a point has one antimeridian. An edge has two, so
    // the number keeps what it was given and the fold stays with the coordinate.
    scenario('Longitude keeps -180 as written, unlike the coordinate built from it', () {
      check(Longitude.tryFrom(-180)?.value).equals(-180);
      check(GeoCoordinate.tryFrom(latitude: 0, longitude: -180)?.longitude).equals(180);
    });

    scenario('a negative zero takes the sign the standard gives the origin', () {
      check(Latitude.tryFrom(-0.0)!.value.isNegative).isFalse();
      check(Longitude.tryFrom(-0.0)!.value.isNegative).isFalse();
    });
  });
}
