import 'package:meta/meta.dart';

import '../shared/minted_format_exception.dart';

/// A calendar date: a year, month, and day, with no time-of-day and no time zone.
///
/// The date-only value [DateTime] doesn't give you. A birthday, an invoice date, or a
/// public holiday is a day, not an instant; holding one in a [DateTime] drags along an
/// hour, minute, second, and a time zone the value never had, which is where bugs creep
/// in (two "equal" dates comparing unequal over a stray time, or a day sliding across a
/// zone boundary).
///
/// Parse, don't validate: a [Date] exists only if it is a real calendar date. [parse] and
/// the [Date] factory reject impossible dates (month 13, 30 February, 29 February in a
/// common year) instead of rolling them over the way [DateTime] does, so any [Date] you
/// hold names a day that genuinely exists. The canonical form is ISO 8601 `YYYY-MM-DD`
/// ([iso8601]); [year] is held in `0000`-`9999`. Standard:
/// [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601).
///
/// Ordering is chronological ([compareTo], [isBefore], [isAfter], and `<` / `<=` / `>` /
/// `>=`); equality is by value over [year], [month], and [day].
@immutable
final class Date implements Comparable<Date> {
  /// The year, `0000`-`9999`.
  final int year;

  /// The month of the year, `1` (January) to `12` (December).
  final int month;

  /// The day of the month, `1` to the last day of [month] (leap-year aware).
  final int day;

  /// The [Date] for [year] (`0000`-`9999`), [month] (`1`-`12`), and [day] (bounded by the
  /// month), throwing [MintedFormatException] on an impossible date.
  ///
  /// Unlike [DateTime], out-of-range parts are rejected, not rolled over: `Date(2026, 13, 1)`
  /// throws rather than silently becoming 2027-01-01.
  factory Date(int year, [int month = 1, int day = 1]) =>
      _tryFromParts(year, month, day) ??
      (throw MintedFormatException.of('Date', '$year-$month-$day', _partsReason(year, month, day)));

  const Date._(this.year, this.month, this.day);

  /// The calendar date of [dateTime], dropping its time-of-day and time zone.
  ///
  /// Throws [MintedFormatException] only when [dateTime]'s year falls outside `0000`-`9999`
  /// (an extreme [DateTime] can reach beyond it).
  factory Date.fromDateTime(DateTime dateTime) => Date(dateTime.year, dateTime.month, dateTime.day);

  /// Parses [input] as an ISO 8601 calendar date `YYYY-MM-DD`, or returns `null` unless it is
  /// exactly that shape (four-digit year, zero-padded two-digit month and day) and a real date.
  static Date? tryParse(String input) {
    final match = _iso8601.firstMatch(input);
    if (match == null) return null;

    return _tryFromParts(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Parses [input] as an ISO 8601 calendar date `YYYY-MM-DD`, throwing [MintedFormatException]
  /// unless it is exactly that shape and a real date.
  static Date parse(String input) =>
      tryParse(input) ??
      (throw MintedFormatException.of('Date', input, 'not an ISO 8601 YYYY-MM-DD calendar date'));

  /// The canonical ISO 8601 form, `YYYY-MM-DD` (e.g. `'2026-07-07'`). Round-trips through [parse].
  String get iso8601 =>
      '${_pad(year, _yearWidth)}-${_pad(month, _fieldWidth)}-${_pad(day, _fieldWidth)}';

  /// The day of the week, `1` (Monday) to `7` (Sunday), matching [DateTime.weekday].
  int get weekday => _utcMidnight.weekday;

  /// This date as a [DateTime] at local midnight.
  ///
  /// Mirrors the `DateTime(year, month, day)` callers reach for today, so migrating a value to
  /// [Date] and back preserves behaviour.
  DateTime toDateTime() => DateTime(year, month, day);

  /// The date [days] days after this one (pass a negative [days] to go back).
  Date addDays(int days) => Date.fromDateTime(_utcMidnight.add(Duration(days: days)));

  /// The date [days] days before this one.
  Date subtractDays(int days) => addDays(-days);

  /// The whole number of days from [other] to this date (`this - other`), negative when this
  /// date is the earlier one.
  int differenceInDays(Date other) => _utcMidnight.difference(other._utcMidnight).inDays;

  /// Whether this date falls chronologically before [other].
  bool isBefore(Date other) => compareTo(other) < 0;

  /// Whether this date falls chronologically after [other].
  bool isAfter(Date other) => compareTo(other) > 0;

  /// Whether this date falls chronologically before [other].
  bool operator <(Date other) => compareTo(other) < 0;

  /// Whether this date is [other] or falls chronologically before it.
  bool operator <=(Date other) => compareTo(other) <= 0;

  /// Whether this date falls chronologically after [other].
  bool operator >(Date other) => compareTo(other) > 0;

  /// Whether this date is [other] or falls chronologically after it.
  bool operator >=(Date other) => compareTo(other) >= 0;

  @override
  int compareTo(Date other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;

    final byMonth = month.compareTo(other.month);
    if (byMonth != 0) return byMonth;

    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is Date && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'Date($iso8601)';

  // UTC midnight, used for day arithmetic: a UTC day is always 24 hours, so addDays and
  // differenceInDays can't be skewed by a daylight-saving transition the way a local day can.
  DateTime get _utcMidnight => DateTime.utc(year, month, day);

  // The [Date] for these parts, or null when they don't form a real calendar date. The single
  // validation gate that parse, the factory, and fromDateTime all funnel through.
  static Date? _tryFromParts(int year, int month, int day) {
    final wellFormed =
        year >= 0 &&
        year <= _maxYear &&
        month >= 1 &&
        month <= _monthsPerYear &&
        day >= 1 &&
        day <= _daysInMonth(year, month);

    return wellFormed ? Date._(year, month, day) : null;
  }

  // Why the given parts are not a valid date, for the exception message. Reached only after
  // _tryFromParts returns null, so exactly one of these conditions holds.
  static String _partsReason(int year, int month, int day) {
    if (year < 0 || year > _maxYear) return 'year $year is outside 0000-9999';
    if (month < 1 || month > _monthsPerYear) return 'month $month is outside 1-12';

    return 'day $day is outside 1-${_daysInMonth(year, month)} for '
        '${_pad(year, _yearWidth)}-${_pad(month, _fieldWidth)}';
  }

  static int _daysInMonth(int year, int month) =>
      month == _february && _isLeapYear(year) ? _daysInLeapFebruary : _daysPerMonth[month - 1];

  static bool _isLeapYear(int year) =>
      year % _leapDivisor == 0 && (year % _centuryDivisor != 0 || year % _leapCenturyDivisor == 0);

  static String _pad(int value, int width) => value.toString().padLeft(width, _padChar);

  static final _iso8601 = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static const _daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  static const _maxYear = 9999;
  static const _monthsPerYear = 12;
  static const _february = 2;
  static const _daysInLeapFebruary = 29;
  static const _leapDivisor = 4;
  static const _centuryDivisor = 100;
  static const _leapCenturyDivisor = 400;
  static const _yearWidth = 4;
  static const _fieldWidth = 2;
  static const _padChar = '0';
}
