import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Month', () {
    // A one or two digit month number round-trips through value; null means rejected.
    scenarioOutline<({String input, int? value})>(
      'Month.tryParse accepts month numbers 1-12 and rejects the rest',
      examples: {
        'a single digit': (input: '7', value: 7),
        'a zero-padded month': (input: '07', value: 7),
        'the first month': (input: '1', value: 1),
        'the last month': (input: '12', value: 12),
        'month zero': (input: '0', value: null),
        'a padded zero': (input: '00', value: null),
        'month thirteen': (input: '13', value: null),
        'three digits': (input: '007', value: null),
        'a leading plus': (input: '+7', value: null),
        'surrounding whitespace': (input: ' 7', value: null),
        'a non-digit': (input: 'x', value: null),
        'an empty string': (input: '', value: null),
      },
      outline: (example) {
        check(Month.tryParse(example.input)?.value).equals(example.value);
      },
    );

    // daysIn is leap-aware for February and fixed for every other month.
    scenarioOutline<({Month month, int year, int days})>(
      'Month.daysIn gives the length of the month in a given year',
      examples: {
        'January has 31': (month: Month.january, year: 2026, days: 31),
        'April has 30': (month: Month.april, year: 2026, days: 30),
        'December has 31': (month: Month.december, year: 2026, days: 31),
        'February in a common year has 28': (month: Month.february, year: 2023, days: 28),
        'February in a year divisible by 4 has 29': (month: Month.february, year: 2024, days: 29),
        'February in a year divisible by 100 has 28': (month: Month.february, year: 1900, days: 28),
        'February in a year divisible by 400 has 29': (month: Month.february, year: 2000, days: 29),
      },
      outline: (example) {
        check(example.month.daysIn(example.year)).equals(example.days);
      },
    );

    scenario('tryFrom accepts in-range numbers and rejects out-of-range', () {
      check(Month.tryFrom(7)?.value).equals(7);
      check(Month.tryFrom(1)?.value).equals(1);
      check(Month.tryFrom(12)?.value).equals(12);
      check(Month.tryFrom(0)).isNull();
      check(Month.tryFrom(13)).isNull();
      check(Month.tryFrom(-1)).isNull();
    });

    scenario('the named constants carry their month number', () {
      check(Month.january.value).equals(1);
      check(Month.july.value).equals(7);
      check(Month.december.value).equals(12);
    });

    scenario('equal months are equal, whichever way they are built', () {
      check(Month.from(7)).equals(Month.july);
      check(Month.parse('07')).equals(Month.july);
      check(Month.july == Month.august).isFalse();
    });

    scenario('Month.parse throws MintedFormatException, carrying the source', () {
      check(() => Month.parse('13'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('13');
    });

    scenario('Month.from throws MintedFormatException on an out-of-range number', () {
      check(() => Month.from(0)).throws<MintedFormatException>();
      check(() => Month.from(13)).throws<MintedFormatException>();
    });
  });
}
