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
      check(Date.of(2026, 7, 7).getOrThrow().iso8601).equals('2026-07-07');
      check(Date.of(2026).getOrThrow().iso8601).equals('2026-01-01');
      check(Date.of(2026, 7).getOrThrow().iso8601).equals('2026-07-01');
    });

    scenario('the factory accepts a genuine leap day', () {
      check(Date.of(2024, 2, 29).getOrThrow().iso8601).equals('2024-02-29');
    });

    scenario('the factory rejects impossible dates instead of rolling them over', () {
      // DateTime rolls an out-of-range month over into the next year; Date refuses it.
      check(DateTime(2026, 13).year).equals(2027);

      check(Date.of(2026, 13).isFailure).isTrue();
      check(Date.of(2026, 2, 29).isFailure).isTrue();
      check(Date.of(2026, 4, 31).isFailure).isTrue();
    });

    scenario('the factory rejects a year outside 0000-9999', () {
      check(Date.of(10000).isFailure).isTrue();
      check(Date.of(-1).isFailure).isTrue();
    });

    // The narrow failure type is the point of Date.of: a caller assembling from parts has no shape
    // arm to fold, because the shape was never in question.
    scenario('Date.of reports only part failures, where parse can also report the shape', () {
      check(Date.of(2026, 13).reasonOrNull).isA<DateComponentFailure>();
      check(Date.parse('07/07/2026').reasonOrNull).isA<DateNotIso8601>();
      check(const DateNotIso8601() is DateComponentFailure).isFalse();
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Date.parse('2026-13-01')).equals(const ParseFailure(DateMonthOutOfRange(13)));
      check(Date.parse('2026-07-07')).equals(ParseSuccess(Date.of(2026, 7, 7).getOrThrow()));
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Date.tryParse('2026-13-01')).isNull();
      check(Date.tryParse('2026-07-07')).equals(Date.of(2026, 7, 7).getOrThrow());
    });

    scenario('the factory reports which part is out of range', () {
      check(Date.of(10000).reasonOrNull).equals(const DateYearOutOfRange(10000));
      check(Date.of(2026, 13).reasonOrNull).equals(const DateMonthOutOfRange(13));
      check(Date.of(2026, 2, 29).reasonOrNull)
          .equals(const DateDayOutOfRange(year: 2026, month: 2, day: 29, maxDay: 28));
    });

    scenario('the day bound the failure reports is leap-year aware', () {
      check(Date.of(2024, 2, 30).reasonOrNull)
          .equals(const DateDayOutOfRange(year: 2024, month: 2, day: 30, maxDay: 29));
    });

    // Both remedies from one door: fix the format, or fix a number. DateYearOutOfRange is absent
    // deliberately, being unreachable here (a four-digit group can't leave 0000-9999); the factory
    // covers it.
    scenarioOutline<({String input, DateFailure failure})>(
      'parse reports the part that is wrong, not just the shape',
      examples: {
        'slashes never had the shape': (input: '07/07/2026', failure: const DateNotIso8601()),
        'an unpadded month never had the shape': (
          input: '2026-7-07',
          failure: const DateNotIso8601(),
        ),
        'a thirteenth month': (input: '2026-13-01', failure: const DateMonthOutOfRange(13)),
        'month zero': (input: '2026-00-10', failure: const DateMonthOutOfRange(0)),
        'the 30th of February': (
          input: '2026-02-30',
          failure: const DateDayOutOfRange(year: 2026, month: 2, day: 30, maxDay: 28),
        ),
        'a leap day in a common year': (
          input: '2026-02-29',
          failure: const DateDayOutOfRange(year: 2026, month: 2, day: 29, maxDay: 28),
        ),
        'the same day in a leap year moves the bound, not the verdict': (
          input: '2024-02-30',
          failure: const DateDayOutOfRange(year: 2024, month: 2, day: 30, maxDay: 29),
        ),
        'day 31 of a 30-day month': (
          input: '2026-04-31',
          failure: const DateDayOutOfRange(year: 2026, month: 4, day: 31, maxDay: 30),
        ),
      },
      outline: (example) => check(Date.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('the failure parse reports renders the offending part', () {
      check(Date.parse('2026-02-30').reasonOrNull?.message)
          .equals('day 30 is outside 1-28 for 2026-02');
    });

    scenario('a caller who asserts the parts gets the throw back through getOrThrow', () {
      check(() => Date.of(2026, 13).getOrThrow())
          .throws<MintedFormatError>()
          .has((error) => error.message, 'message')
          .equals('Invalid Date: month 13 is outside 1-12');
    });

    scenario('equal dates are equal by value and hash', () {
      check(Date.of(2026, 7, 7).getOrThrow()).equals(Date.of(2026, 7, 7).getOrThrow());
      check(Date.of(2026, 7, 7).getOrThrow().hashCode)
          .equals(Date.of(2026, 7, 7).getOrThrow().hashCode);
      check(Date.tryParse('2026-07-07')!).equals(Date.of(2026, 7, 7).getOrThrow());
    });

    scenario('different dates are not equal', () {
      check(Date.of(2026, 7, 7).getOrThrow() == Date.of(2026, 7, 8).getOrThrow()).isFalse();
    });

    scenario('dates order chronologically', () {
      check(Date.of(2026, 7, 7).getOrThrow().isBefore(Date.of(2026, 7, 8).getOrThrow())).isTrue();
      check(Date.of(2026, 7, 7).getOrThrow().isAfter(Date.of(2026, 7, 6).getOrThrow())).isTrue();
      check(Date.of(2025, 12, 31).getOrThrow() < Date.of(2026).getOrThrow()).isTrue();
      // Checking bounds
      // ignore: avoid-self-compare
      check(Date.of(2026, 7, 7).getOrThrow() <= Date.of(2026, 7, 7).getOrThrow()).isTrue();
      // Checking bounds
      // ignore: avoid-self-compare
      check(Date.of(2026, 7, 7).getOrThrow() >= Date.of(2026, 7, 7).getOrThrow()).isTrue();
      check(Date.of(2026, 7, 8).getOrThrow() > Date.of(2026, 7, 7).getOrThrow()).isTrue();
    });

    scenario('sorting orders by year, then month, then day', () {
      final dates = [
        Date.of(2026, 3, 15).getOrThrow(),
        Date.of(2024, 5, 9).getOrThrow(),
        Date.of(2026, 3, 2).getOrThrow(),
      ]..sort();

      check(dates).deepEquals([
        Date.of(2024, 5, 9).getOrThrow(),
        Date.of(2026, 3, 2).getOrThrow(),
        Date.of(2026, 3, 15).getOrThrow(),
      ]);
    });

    scenario('weekday matches the Gregorian calendar', () {
      check(Date.of(2000).getOrThrow().weekday)
          .equals(Weekday.saturday); // 2000-01-01 was a Saturday
      check(Date.of(2024).getOrThrow().weekday).equals(Weekday.monday); // 2024-01-01 was a Monday
      check(Date.of(2024).getOrThrow().weekday.value)
          .equals(DateTime.monday); // and bridges back to dart:core
    });

    scenario('day arithmetic crosses month, year, and leap boundaries', () {
      check(Date.of(2026, 1, 31).getOrThrow().tryAddDays(1)).equals(Date.of(2026, 2).getOrThrow());
      check(Date.of(2026, 12, 31).getOrThrow().tryAddDays(1)).equals(Date.of(2027).getOrThrow());
      check(Date.of(2024, 2, 28).getOrThrow().tryAddDays(1))
          .equals(Date.of(2024, 2, 29).getOrThrow()); // leap year
      check(Date.of(2023, 2, 28).getOrThrow().tryAddDays(1))
          .equals(Date.of(2023, 3).getOrThrow()); // common year
      check(Date.of(2026, 3).getOrThrow().trySubtractDays(1))
          .equals(Date.of(2026, 2, 28).getOrThrow());
      check(Date.of(2026, 7, 7).getOrThrow().tryAddDays(0))
          .equals(Date.of(2026, 7, 7).getOrThrow());
      check(Date.of(2026, 7, 7).getOrThrow().trySubtractDays(3))
          .equals(Date.of(2026, 7, 7).getOrThrow().tryAddDays(-3));
    });

    scenario('day arithmetic yields null when it walks off either end of 0000-9999', () {
      check(Date.of(9999, 12, 31).getOrThrow().tryAddDays(1)).isNull();
      check(Date.of(0).getOrThrow().trySubtractDays(1)).isNull();
    });

    scenario('the try variants return null at the bound instead of throwing', () {
      check(Date.of(9999, 12, 31).getOrThrow().tryAddDays(1)).isNull();
      check(Date.of(2026, 8, 4).getOrThrow().tryAddDays(3000000)).isNull();
      check(Date.of(0).getOrThrow().trySubtractDays(1)).isNull();
    });

    scenario('the try variants agree with the throwing ones inside the bound', () {
      check(Date.of(2026, 1, 31).getOrThrow().tryAddDays(1)).equals(Date.of(2026, 2).getOrThrow());
      check(Date.of(2026, 3).getOrThrow().trySubtractDays(1))
          .equals(Date.of(2026, 2, 28).getOrThrow());
      check(Date.of(9999, 12, 30).getOrThrow().tryAddDays(1))
          .equals(Date.of(9999, 12, 31).getOrThrow());
      check(Date.of(0, 1, 2).getOrThrow().trySubtractDays(1)).equals(Date.of(0).getOrThrow());
    });

    scenario('differenceInDays counts whole days, signed by order', () {
      check(Date.of(2026).getOrThrow().differenceInDays(Date.of(2025).getOrThrow()))
          .equals(365); // 2025 is a common year
      check(Date.of(2025).getOrThrow().differenceInDays(Date.of(2024).getOrThrow()))
          .equals(366); // 2024 is a leap year
      check(Date.of(2026, 7, 10).getOrThrow().differenceInDays(Date.of(2026, 7, 7).getOrThrow()))
          .equals(3);
      check(Date.of(2026).getOrThrow().differenceInDays(Date.of(2026).getOrThrow())).equals(0);
      check(Date.of(2025).getOrThrow().differenceInDays(Date.of(2026).getOrThrow())).equals(-365);
    });

    scenario('fromDateTime keeps the calendar date and drops the time and zone', () {
      check(Date.fromDateTime(DateTime(2026, 7, 7, 13, 30)).getOrThrow())
          .equals(Date.of(2026, 7, 7).getOrThrow());
      check(Date.fromDateTime(DateTime.utc(2026, 7, 7, 23, 59, 59)).getOrThrow())
          .equals(Date.of(2026, 7, 7).getOrThrow());
    });

    scenario('now gives today in the local time zone', () {
      // Bracketed by two clock reads, so a midnight rollover mid-scenario widens the window
      // rather than failing.
      final before = Date.fromDateTime(DateTime.now()).getOrThrow();
      final today = Date.now();
      final after = Date.fromDateTime(DateTime.now()).getOrThrow();

      check(today >= before).isTrue();
      check(today <= after).isTrue();
    });

    scenario('toDateTime returns local midnight', () {
      final dateTime = Date.of(2026, 7, 7).getOrThrow().toDateTime();

      check(dateTime).equals(DateTime(2026, 7, 7));
      check(dateTime.hour).equals(0);
      check(dateTime.isUtc).isFalse();
    });

    scenario('toString wraps the canonical form and pads short years', () {
      check(Date.of(2026, 7, 7).getOrThrow().toString()).equals('Date(2026-07-07)');
      check(Date.of(5).getOrThrow().toString()).equals('Date(0005-01-01)');
    });

    scenario('the canonical form round-trips through parse', () {
      for (final date in [
        Date.of(2026, 7, 7).getOrThrow(),
        Date.of(2000).getOrThrow(),
        Date.of(2024, 2, 29).getOrThrow(),
      ]) {
        check(Date.tryParse(date.iso8601)!).equals(date);
      }
    });

    scenario('the month getter is a Month that knows its length', () {
      check(Date.of(2026, 7, 7).getOrThrow().month).equals(Month.july);
      check(Date.of(2024, 2, 29).getOrThrow().month.daysIn(2024)).equals(29);
    });
  });
}
