import 'package:checks/checks.dart';
import 'package:minted_chronology/minted_chronology.dart';

import '../../../test/support/bdd.dart';

const namedDays = <DayOfMonth>{
  DayOfMonthConstants.d1,
  DayOfMonthConstants.d2,
  DayOfMonthConstants.d3,
  DayOfMonthConstants.d4,
  DayOfMonthConstants.d5,
  DayOfMonthConstants.d6,
  DayOfMonthConstants.d7,
  DayOfMonthConstants.d8,
  DayOfMonthConstants.d9,
  DayOfMonthConstants.d10,
  DayOfMonthConstants.d11,
  DayOfMonthConstants.d12,
  DayOfMonthConstants.d13,
  DayOfMonthConstants.d14,
  DayOfMonthConstants.d15,
  DayOfMonthConstants.d16,
  DayOfMonthConstants.d17,
  DayOfMonthConstants.d18,
  DayOfMonthConstants.d19,
  DayOfMonthConstants.d20,
  DayOfMonthConstants.d21,
  DayOfMonthConstants.d22,
  DayOfMonthConstants.d23,
  DayOfMonthConstants.d24,
  DayOfMonthConstants.d25,
  DayOfMonthConstants.d26,
  DayOfMonthConstants.d27,
  DayOfMonthConstants.d28,
  DayOfMonthConstants.d29,
  DayOfMonthConstants.d30,
  DayOfMonthConstants.d31,
};

void main() {
  feature('DayOfMonth', () {
    scenarioOutline<({int input, int? value})>(
      'DayOfMonth.tryFrom accepts 1-31 and refuses either side',
      examples: {
        'the first day every month has': (input: 1, value: 1),
        'a day in the middle': (input: 15, value: 15),
        'the longest a month runs': (input: 31, value: 31),
        'the 29th, which only a leap February reaches': (input: 29, value: 29),
        'zero, which no calendar has': (input: 0, value: null),
        'one past the longest month': (input: 32, value: null),
        'a negative day': (input: -1, value: null),
      },
      outline: (example) {
        check(DayOfMonth.tryFrom(example.input)?.value).equals(example.value);
      },
    );

    scenario('every named constant is one tryFrom accepts', () {
      for (final day in namedDays) {
        check(DayOfMonth.tryFrom(day.value), because: 'named constant $day').equals(day);
      }
    });

    // Catches a d-name holding the wrong number, which the round-trip above cannot: tryFrom(16)
    // equals a d15 that holds 16 just as happily.
    scenario('the set runs 1 to 31 with each name on its own number', () {
      check(namedDays.map((day) => day.value).toList())
          .deepEquals([for (var day = 1; day <= 31; day++) day]);
    });

    scenario('a DayOfMonth is an int, so it reaches arithmetic without unwrapping', () {
      check(DayOfMonthConstants.d31 - DayOfMonthConstants.d1).equals(30);
      check(DayOfMonthConstants.d15 > DayOfMonthConstants.d1).isTrue();
    });

    // The type bounds what some month could hold, never what one does, and that gap is Date's to close.
    scenario('a day no month of that year reaches still parses here', () {
      check(DayOfMonth.tryFrom(31)).isNotNull();
      check(Date.from(Year.tryFrom(2026)!, MonthConstants.april, .tryFrom(31)!).isFailure).isTrue();
    });
  });
}
