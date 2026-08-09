import 'package:meta/meta.dart';

import '../shared/minted_failure.dart';
import '../shared/minted_format_exception.dart';
import 'month.dart';

/// A calendar date: a year, month, and day, with no time-of-day and no time zone.
///
/// The date-only value [DateTime] doesn't give you. A birthday, an invoice date, or a public holiday is a day,
/// not an instant. Holding one in a [DateTime] drags along an hour, minute, second, and a time zone
/// the value never had, which is where bugs creep in
/// (two "equal" dates comparing unequal over a stray time, or a day sliding across a zone boundary).
///
/// Parse, don't validate: a [Date] exists only if it is a real calendar date. [parse] and the [Date]
/// factory reject impossible dates (month 13, 30 February, 29 February in a common year)
/// instead of rolling them over the way [DateTime] does, so any [Date] you hold names a day that genuinely exists.
/// The canonical form is ISO 8601 `YYYY-MM-DD` ([iso8601]); [year] is held in `0000`-`9999`.
/// Standard: [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601).
///
/// Ordering is chronological ([compareTo], [isBefore], [isAfter], and `<` / `<=` / `>` / `>=`).
/// Equality is by value over [year], [month], and [day].
@immutable
final class Date implements Comparable<Date> {
  /// The year, `0000`-`9999`.
  final int year;

  /// The month of the year, as a [Month] (`1`/January to `12`/December).
  final Month month;

  /// The day of the month, `1` to the last day of [month] (leap-year aware).
  final int day;

  /// The [Date] for [year] (`0000`-`9999`), [month] (`1`-`12`), and [day] (bounded by the month),
  /// throwing [MintedFormatException] on an impossible date.
  ///
  /// Unlike [DateTime], out-of-range parts are rejected, not rolled over: `Date(2026, 13, 1)` throws
  /// rather than silently becoming 2027-01-01.
  factory Date(int year, [int month = 1, int day = 1]) =>
      _tryFromParts(year, month, day) ??
      (throw MintedFormatException.from(_partsFailure(year, month, day), '$year-$month-$day'));

  const Date._(this.year, this.month, this.day);

  /// The calendar date of [dateTime], dropping its time-of-day and time zone.
  ///
  /// Throws [MintedFormatException] only when [dateTime]'s year falls outside `0000`-`9999`
  /// (an extreme [DateTime] can reach beyond it).
  factory Date.fromDateTime(DateTime dateTime) => Date(dateTime.year, dateTime.month, dateTime.day);

  /// Parses [input] as an ISO 8601 calendar date `YYYY-MM-DD`, or returns `null` unless it is exactly
  /// that shape (four-digit year, zero-padded two-digit month and day) and a real date.
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
      tryParse(input) ?? (throw MintedFormatException.from(const DateNotIso8601(), input));

  /// The canonical ISO 8601 form, `YYYY-MM-DD` (e.g. `'2026-07-07'`). Round-trips through [parse].
  String get iso8601 =>
      '${_pad(year, _yearWidth)}-${_pad(month.value, _fieldWidth)}-${_pad(day, _fieldWidth)}';

  /// The day of the week, `1` (Monday) to `7` (Sunday), matching [DateTime.weekday].
  int get weekday => _utcMidnight.weekday;

  /// This date as a [DateTime] at local midnight.
  ///
  /// Mirrors the `DateTime(year, month, day)` callers reach for today, so migrating a value to
  /// [Date] and back preserves behaviour.
  DateTime toDateTime() => DateTime(year, month.value, day);

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

    final byMonth = month.value.compareTo(other.month.value);
    if (byMonth != 0) return byMonth;

    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is Date && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month.value, day);

  @override
  String toString() => 'Date($iso8601)';

  // UTC midnight, used for day arithmetic: a UTC day is always 24 hours, so addDays and
  // differenceInDays can't be skewed by a daylight-saving transition the way a local day can.
  DateTime get _utcMidnight => DateTime.utc(year, month.value, day);

  // The [Date] for these parts, or null when they don't form a real calendar date. The single
  // validation gate that parse, the factory, and fromDateTime all funnel through.
  static Date? _tryFromParts(int year, int month, int day) {
    final monthType = Month.tryFrom(month);
    if (monthType == null) return null;

    final wellFormed = year >= 0 && year <= _maxYear && day >= 1 && day <= monthType.daysIn(year);

    return wellFormed ? Date._(year, monthType, day) : null;
  }

  // Which part of the given date is out of range. Reached only after _tryFromParts returns null,
  // so exactly one of these conditions holds.
  static DateFailure _partsFailure(int year, int month, int day) {
    if (year < 0 || year > _maxYear) return DateYearOutOfRange(year);

    final monthType = Month.tryFrom(month);
    if (monthType == null) return DateMonthOutOfRange(month);

    return DateDayOutOfRange(year: year, month: month, day: day, maxDay: monthType.daysIn(year));
  }

  static String _pad(int value, int width) => value.toString().padLeft(width, _padChar);

  static final _iso8601 = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static const _maxYear = 9999;
  static const _yearWidth = 4;
  static const _fieldWidth = 2;
  static const _padChar = '0';
}

/// Why a [Date] refused its input.
///
/// Sealed rather than an enum because three of the four variants report the offending number back,
/// and [DateDayOutOfRange] reports a bound that depends on the month and the year.
///
/// Two kinds of remedy, which is why the shape check and the range checks are separate variants:
/// [DateNotIso8601] means fix the format, the rest mean fix a number.
@immutable
sealed class DateFailure implements MintedFailure {
  const DateFailure();

  @override
  String get typeName => 'Date';
}

/// The text is not the ISO 8601 `YYYY-MM-DD` shape: a four-digit year, then a zero-padded
/// two-digit month and day, hyphen-separated.
final class DateNotIso8601 extends DateFailure {
  /// The failure [Date.parse] reports for text that never had the right shape.
  const DateNotIso8601();

  @override
  String get message => 'not an ISO 8601 YYYY-MM-DD calendar date';

  @override
  bool operator ==(Object other) => other is DateNotIso8601;

  @override
  int get hashCode => (DateNotIso8601).hashCode;

  @override
  String toString() => 'DateNotIso8601()';
}

/// The year falls outside `0000`-`9999`, the range a [Date] can hold.
final class DateYearOutOfRange extends DateFailure {
  /// The offending year.
  final int year;

  /// The failure reported for [year], which is outside `0000`-`9999`.
  const DateYearOutOfRange(this.year);

  @override
  String get message => 'year $year is outside 0000-9999';

  @override
  bool operator ==(Object other) => other is DateYearOutOfRange && other.year == year;

  @override
  int get hashCode => Object.hash(DateYearOutOfRange, year);

  @override
  String toString() => 'DateYearOutOfRange($year)';
}

/// The month falls outside `1`-`12`.
final class DateMonthOutOfRange extends DateFailure {
  /// The offending month number.
  final int month;

  /// The failure reported for [month], which is outside `1`-`12`.
  const DateMonthOutOfRange(this.month);

  @override
  String get message => 'month $month is outside 1-12';

  @override
  bool operator ==(Object other) => other is DateMonthOutOfRange && other.month == month;

  @override
  int get hashCode => Object.hash(DateMonthOutOfRange, month);

  @override
  String toString() => 'DateMonthOutOfRange($month)';
}

/// The day falls outside `1`-[maxDay], the length of that month in that year.
///
/// The bound is leap-year aware, so 29 February is out of range in a common year and in range in
/// a leap year. Both [year] and [month] are carried so the message can name the month the bound
/// belongs to.
final class DateDayOutOfRange extends DateFailure {
  /// The year the day was given for.
  final int year;

  /// The month number the day was given for.
  final int month;

  /// The offending day.
  final int day;

  /// The last day of [month] in [year], leap-year aware.
  final int maxDay;

  /// The failure reported for [day], which is outside `1`-[maxDay] for that year and month.
  const DateDayOutOfRange({
    required this.year,
    required this.month,
    required this.day,
    required this.maxDay,
  });

  @override
  String get message =>
      'day $day is outside 1-$maxDay for '
      '${Date._pad(year, Date._yearWidth)}-${Date._pad(month, Date._fieldWidth)}';

  @override
  bool operator ==(Object other) =>
      other is DateDayOutOfRange &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.maxDay == maxDay;

  @override
  int get hashCode => Object.hash(year, month, day, maxDay);

  @override
  String toString() => 'DateDayOutOfRange(year: $year, month: $month, day: $day, maxDay: $maxDay)';
}
