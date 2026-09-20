/// @docImport 'date.dart';
library;

import 'package:minted/minted.dart';

import 'failures/month_failure.dart';

part 'constants/month_constants.dart';

/// A month of the year, `1` (January) to `12` (December).
///
/// A month is one of 12, not any `int`, so this makes "a real month" a fact of the type rather than
/// something every caller re-checks. It also carries the calendar knowledge hanging off a month: [daysIn]
/// gives the length in a given year, February included.
///
/// Named values: [MonthConstants].
extension type const Month._(int value) {
  /// Parses [input] as a month number, `'7'` or `'07'`, or `null` unless it names one in `1`-`12`.
  static Month? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a month number, reporting [MonthFailure] unless it names one in `1`-`12`.
  static ParseOutcome<MonthFailure, Month> parse(String input) {
    final parsedMonth = !_digits.hasMatch(input) ? null : tryFrom(int.parse(input));

    return parsedMonth == null ? const ParseFailure(.notAMonth) : ParseSuccess(parsedMonth);
  }

  /// The [Month] with number [value], or `null` unless it's in `1`-`12`.
  static Month? tryFrom(int value) =>
      value >= MonthConstants.january.value && value <= MonthConstants.december.value
      ? ._(value)
      : null;

  /// How many days this month has in [year], `28`-`31`. February gets `29` in a leap year, by the proleptic
  /// Gregorian rule: divisible by 4, bar centuries not divisible by 400.
  int daysIn(int year) => value == MonthConstants.february.value && _isLeapYear(year)
      ? _daysInLeapFebruary
      : _lengths[value - 1];

  static bool _isLeapYear(int year) =>
      year % _leapDivisor == 0 && (year % _centuryDivisor != 0 || year % _leapCenturyDivisor == 0);

  static final _digits = RegExp(r'^\d{1,2}$');

  static const _lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  static const _daysInLeapFebruary = 29;
  static const _leapDivisor = 4;
  static const _centuryDivisor = 100;
  static const _leapCenturyDivisor = 400;
}
