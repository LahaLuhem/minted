/// @docImport 'date.dart';
library;

import '../shared/minted_format_exception.dart';

/// A month of the year, `1` (January) to `12` (December).
///
/// A building-block value type for calendar code: a month is one of twelve, not any `int`, so
/// modelling it as [Month] makes "this is a real month" a fact of the type instead of something
/// every caller re-checks. [Date] holds its month as a [Month], and the type carries the calendar
/// knowledge that hangs off the month: [daysIn] gives the month's length in a given year, counting
/// February as 29 days in a leap year.
///
/// [value] is the month number (`1`-`12`); the [january] to [december] constants name a month
/// without the number.
extension type const Month._(int value) {
  /// Parses [input] as a month number `1`-`12` (`'7'` or `'07'`), or returns `null` unless it is
  /// one or two digits naming a month in range.
  static Month? tryParse(String input) {
    if (!_digits.hasMatch(input)) return null;

    return tryFrom(int.parse(input));
  }

  /// Parses [input] as a month number `1`-`12`, throwing [MintedFormatException] unless it is one
  /// or two digits naming a month in range.
  static Month parse(String input) =>
      tryParse(input) ??
      (throw MintedFormatException.of('Month', input, 'not a month number 1-12'));

  /// The [Month] with number [value], or `null` unless it is in `1`-`12`.
  static Month? tryFrom(int value) =>
      value >= january.value && value <= december.value ? ._(value) : null;

  /// The [Month] with number [value], throwing [MintedFormatException] unless it is in `1`-`12`.
  static Month from(int value) =>
      tryFrom(value) ?? (throw MintedFormatException.of('Month', '$value', 'not a month in 1-12'));

  /// The number of days in this month during [year] (`28`-`31`), counting February as `29` in a
  /// leap year (proleptic Gregorian: divisible by 4, except centuries not divisible by 400).
  int daysIn(int year) =>
      value == february.value && _isLeapYear(year) ? _daysInLeapFebruary : _lengths[value - 1];

  /// January, month `1`.
  static const january = Month._(1);

  /// February, month `2`.
  static const february = Month._(2);

  /// March, month `3`.
  static const march = Month._(3);

  /// April, month `4`.
  static const april = Month._(4);

  /// May, month `5`.
  static const may = Month._(5);

  /// June, month `6`.
  static const june = Month._(6);

  /// July, month `7`.
  static const july = Month._(7);

  /// August, month `8`.
  static const august = Month._(8);

  /// September, month `9`.
  static const september = Month._(9);

  /// October, month `10`.
  static const october = Month._(10);

  /// November, month `11`.
  static const november = Month._(11);

  /// December, month `12`.
  static const december = Month._(12);

  static bool _isLeapYear(int year) =>
      year % _leapDivisor == 0 && (year % _centuryDivisor != 0 || year % _leapCenturyDivisor == 0);

  static final _digits = RegExp(r'^\d{1,2}$');

  static const _lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  static const _daysInLeapFebruary = 29;
  static const _leapDivisor = 4;
  static const _centuryDivisor = 100;
  static const _leapCenturyDivisor = 400;
}
