import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Date', () {
    // A strict ISO 8601 date round-trips through iso8601; null means rejected.
    scenarioOutline<({String input, String? canonical})>(
      'Date.tryParse accepts strict YYYY-MM-DD calendar dates and rejects the rest',
      examples: {
        'a plain date': (input: '2026-07-07', canonical: '2026-07-07'),
        'the minimum year': (input: '0000-01-01', canonical: '0000-01-01'),
        'the maximum year': (input: '9999-12-31', canonical: '9999-12-31'),
        'a leap day in a year divisible by 400': (input: '2000-02-29', canonical: '2000-02-29'),
        'a leap day in a year divisible by 4': (input: '2024-02-29', canonical: '2024-02-29'),
        'no leap day in a year divisible by 100': (input: '1900-02-29', canonical: null),
        'no leap day in a common year': (input: '2023-02-29', canonical: null),
        'the last day of a 30-day month': (input: '2026-04-30', canonical: '2026-04-30'),
        'day 31 of a 30-day month': (input: '2026-04-31', canonical: null),
        'month zero': (input: '2026-00-10', canonical: null),
        'month thirteen': (input: '2026-13-01', canonical: null),
        'day zero': (input: '2026-07-00', canonical: null),
        'day 32': (input: '2026-01-32', canonical: null),
        'unpadded month and day': (input: '2026-7-7', canonical: null),
        'the basic format without hyphens': (input: '20260707', canonical: null),
        'slashes instead of hyphens': (input: '2026/07/07', canonical: null),
        'a time component appended': (input: '2026-07-07T00:00', canonical: null),
        'leading whitespace': (input: ' 2026-07-07', canonical: null),
        'trailing whitespace': (input: '2026-07-07 ', canonical: null),
        'a five-digit year': (input: '12026-07-07', canonical: null),
        'a signed year': (input: '-2026-07-07', canonical: null),
        'an empty string': (input: '', canonical: null),
      },
      outline: (example) {
        check(Date.tryParse(example.input)?.iso8601).equals(example.canonical);
      },
    );

    scenario('the factory builds from parts, defaulting month and day to 1', () {
      check(Date(2026, 7, 7).iso8601).equals('2026-07-07');
      check(Date(2026).iso8601).equals('2026-01-01');
      check(Date(2026, 7).iso8601).equals('2026-07-01');
    });

    scenario('the factory accepts a genuine leap day', () {
      check(Date(2024, 2, 29).iso8601).equals('2024-02-29');
    });

    scenario('the factory rejects impossible dates instead of rolling them over', () {
      // DateTime rolls an out-of-range month over into the next year; Date refuses it.
      check(DateTime(2026, 13).year).equals(2027);

      check(() => Date(2026, 13)).throws<MintedFormatException>();
      check(() => Date(2026, 2, 29)).throws<MintedFormatException>();
      check(() => Date(2026, 4, 31)).throws<MintedFormatException>();
    });

    scenario('the factory rejects a year outside 0000-9999', () {
      check(() => Date(10000)).throws<MintedFormatException>();
      check(() => Date(-1)).throws<MintedFormatException>();
    });

    scenario('Date.parse throws MintedFormatException, carrying the source', () {
      check(() => Date.parse('2026-13-01'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('2026-13-01');
    });

    scenario('the factory throws MintedFormatException naming the bad part', () {
      check(() => Date(2026, 13))
          .throws<MintedFormatException>()
          .has((error) => error.message, 'message')
          .equals('Invalid Date: month 13 is outside 1-12');
    });

    scenario('equal dates are equal by value and hash', () {
      check(Date(2026, 7, 7)).equals(Date(2026, 7, 7));
      check(Date(2026, 7, 7).hashCode).equals(Date(2026, 7, 7).hashCode);
      check(Date.parse('2026-07-07')).equals(Date(2026, 7, 7));
    });

    scenario('different dates are not equal', () {
      check(Date(2026, 7, 7) == Date(2026, 7, 8)).isFalse();
    });

    scenario('dates order chronologically', () {
      check(Date(2026, 7, 7).isBefore(Date(2026, 7, 8))).isTrue();
      check(Date(2026, 7, 7).isAfter(Date(2026, 7, 6))).isTrue();
      check(Date(2025, 12, 31) < Date(2026)).isTrue();
      check(Date(2026, 7, 7) <= Date(2026, 7, 7)).isTrue();
      check(Date(2026, 7, 7) >= Date(2026, 7, 7)).isTrue();
      check(Date(2026, 7, 8) > Date(2026, 7, 7)).isTrue();
    });

    scenario('sorting orders by year, then month, then day', () {
      final dates = [Date(2026, 3, 15), Date(2024, 5, 9), Date(2026, 3, 2)]..sort();

      check(dates).deepEquals([Date(2024, 5, 9), Date(2026, 3, 2), Date(2026, 3, 15)]);
    });

    scenario('weekday matches the Gregorian calendar', () {
      check(Date(2000).weekday).equals(DateTime.saturday); // 2000-01-01 was a Saturday
      check(Date(2024).weekday).equals(DateTime.monday); // 2024-01-01 was a Monday
    });

    scenario('addDays and subtractDays cross month, year, and leap boundaries', () {
      check(Date(2026, 1, 31).addDays(1)).equals(Date(2026, 2));
      check(Date(2026, 12, 31).addDays(1)).equals(Date(2027));
      check(Date(2024, 2, 28).addDays(1)).equals(Date(2024, 2, 29)); // leap year
      check(Date(2023, 2, 28).addDays(1)).equals(Date(2023, 3)); // common year
      check(Date(2026, 3).subtractDays(1)).equals(Date(2026, 2, 28));
      check(Date(2026, 7, 7).addDays(0)).equals(Date(2026, 7, 7));
      check(Date(2026, 7, 7).subtractDays(3)).equals(Date(2026, 7, 7).addDays(-3));
    });

    scenario('differenceInDays counts whole days, signed by order', () {
      check(Date(2026).differenceInDays(Date(2025))).equals(365); // 2025 is a common year
      check(Date(2025).differenceInDays(Date(2024))).equals(366); // 2024 is a leap year
      check(Date(2026, 7, 10).differenceInDays(Date(2026, 7, 7))).equals(3);
      check(Date(2026).differenceInDays(Date(2026))).equals(0);
      check(Date(2025).differenceInDays(Date(2026))).equals(-365);
    });

    scenario('fromDateTime keeps the calendar date and drops the time and zone', () {
      check(Date.fromDateTime(DateTime(2026, 7, 7, 13, 30))).equals(Date(2026, 7, 7));
      check(Date.fromDateTime(DateTime.utc(2026, 7, 7, 23, 59, 59))).equals(Date(2026, 7, 7));
    });

    scenario('toDateTime returns local midnight', () {
      final dateTime = Date(2026, 7, 7).toDateTime();

      check(dateTime).equals(DateTime(2026, 7, 7));
      check(dateTime.hour).equals(0);
      check(dateTime.isUtc).isFalse();
    });

    scenario('toString wraps the canonical form and pads short years', () {
      check(Date(2026, 7, 7).toString()).equals('Date(2026-07-07)');
      check(Date(5).toString()).equals('Date(0005-01-01)');
    });

    scenario('the canonical form round-trips through parse', () {
      for (final date in [Date(2026, 7, 7), Date(2000), Date(2024, 2, 29)]) {
        check(Date.parse(date.iso8601)).equals(date);
      }
    });
  });
}
