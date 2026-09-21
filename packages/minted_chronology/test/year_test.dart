import 'package:checks/checks.dart';
import 'package:minted_chronology/minted_chronology.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../../../test/support/bdd.dart';

const namedYears = <Year>{
  YearConstants.min,
  YearConstants.max,
  YearConstants.unixEpoch,
  YearConstants.gregorianStart,
};

void main() {
  feature('Year', () {
    scenarioOutline<({int input, int? value})>(
      'Year.tryFrom accepts 0000-9999 and refuses either side',
      examples: {
        'the earliest year': (input: 0, value: 0),
        'a year in the middle': (input: 2026, value: 2026),
        'the latest year': (input: 9999, value: 9999),
        'one past the latest': (input: 10000, value: null),
        'a negative year': (input: -1, value: null),
      },
      outline: (example) {
        check(Year.tryFrom(example.input)?.value).equals(example.value);
      },
    );

    scenario('every named constant is one tryFrom accepts', () {
      for (final year in namedYears) {
        check(Year.tryFrom(year.value), because: 'named constant $year').equals(year);
      }
    });

    // Bounds a tryFrom(max + 1) check cannot establish on its own: it stays green if max is too low.
    scenario('the bounds are the last years that parse, not merely years that do', () {
      check(Year.tryFrom(YearConstants.min.value)).isNotNull();
      check(Year.tryFrom(YearConstants.max.value)).isNotNull();
      check(Year.tryFrom(YearConstants.min.value - 1)).isNull();
      check(Year.tryFrom(YearConstants.max.value + 1)).isNull();
    });

    scenario('a Year widens to Uint without a hop, and int comes through under it', () {
      const Uint widened = YearConstants.unixEpoch;
      check(widened).equals(Uint.tryFrom(1970)!);
      check(YearConstants.unixEpoch + 1).equals(1971);
    });

    scenario('every named year is the one Date names the same thing after', () {
      check(DateConstants.min.year).equals(YearConstants.min);
      check(DateConstants.max.year).equals(YearConstants.max);
      check(DateConstants.unixEpoch.year).equals(YearConstants.unixEpoch);
      check(DateConstants.gregorianStart.year).equals(YearConstants.gregorianStart);
    });
  });
}
