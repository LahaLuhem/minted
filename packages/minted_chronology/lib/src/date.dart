import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

import 'failures/date_failure.dart';
import 'month.dart';
import 'normalisation/iso_date_format.dart';
import 'weekday.dart';

part 'helpers/date_helpers.dart';

/// A calendar date: a year, month, and day, with no time-of-day and no time zone.
///
/// The date-only value [DateTime] doesn't give you. Held in a [DateTime], a birthday drags along a time
/// and a zone it never had, so 2 "equal" dates compare unequal and a day slides across a zone boundary.
/// Standard: [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601).
///
/// [parse] and [Date.of] refuse the impossible dates (month 13, 30 February, 29 February in a common
/// year) rather than rolling them over the way [DateTime] does. [year] is held in `0000`-`9999`, and
/// [iso8601] is the canonical form.
///
/// Ordering is chronological, on [compareTo], [isBefore], [isAfter] and `<` / `<=` / `>` / `>=`.
///
/// {@example /example/minted_chronology_example.dart#date}
@immutable
final class Date implements Comparable<Date> {
  /// The year, `0000`-`9999`.
  final int year;

  /// The month of the year.
  final Month month;

  /// The day of the month, `1` to the last day of [month] (leap-year aware).
  final int day;

  const new _(this.year, this.month, this.day);

  /// The [Date] for [year], [month] and [day], reporting which part is out of range on an impossible
  /// date.
  ///
  /// Nothing rolls over: `Date.of(2026, 13, 1)` reports [DateMonthOutOfRange] rather than quietly becoming
  /// 2027-01-01. The failure type is the parts-only subset, so there's no shape arm to fold here.
  static ParseOutcome<DateComponentFailure, Date> of(int year, [int month = 1, int day = 1]) {
    final parsedDate = _tryFromParts(year, month, day);

    return parsedDate == null
        ? ParseFailure(_partsFailure(year, month, day))
        : ParseSuccess(parsedDate);
  }

  /// The calendar date of [dateTime], dropping its time-of-day and time zone. Fails only when its year
  /// falls outside `0000`-`9999`, which an extreme [DateTime] can reach.
  static ParseOutcome<DateComponentFailure, Date> fromDateTime(DateTime dateTime) =>
      of(dateTime.year, dateTime.month, dateTime.day);

  /// Today's date in the local time zone. For the UTC day, use `Date.fromDateTime(DateTime.now().toUtc())`.
  // The local clock is always inside 0000-9999, so this cannot fail.
  factory now() => fromDateTime(DateTime.now()).getOrThrow();

  /// Parses [input], or `null` unless it's exactly `YYYY-MM-DD` (4-digit year, zero-padded month
  /// and day) and a real date.
  static Date? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [DateFailure] that says whether the shape or one of the parts is
  /// wrong.
  static ParseOutcome<DateFailure, Date> parse(String input) {
    final dateParts = _partsOf(input);
    if (dateParts == null) return const ParseFailure(DateNotIso8601());

    final (:year, :month, :day) = dateParts;
    final parsedDate = _tryFromParts(year, month, day);

    return parsedDate == null
        ? ParseFailure(_partsFailure(year, month, day))
        : ParseSuccess(parsedDate);
  }

  /// The canonical ISO 8601 form, `'2026-07-07'`. Round-trips through [parse].
  String get iso8601 => isoDate(year, month.value, day);

  /// The day of the week.
  // DateTime.weekday is always 1-7, so tryFrom cannot return null here.
  Weekday get weekday => Weekday.tryFrom(_utcMidnight.weekday)!;

  /// This date as a [DateTime] at local midnight, matching the `DateTime(year, month, day)` that callers
  /// reach for today.
  DateTime toDateTime() => DateTime(year, month.value, day);

  /// The date [days] days after this one, negative to go back, or `null` if the result leaves `0000`-`9999`.
  Date? tryAddDays(int days) {
    final shiftedUtc = _utcMidnight.add(Duration(days: days));

    return _tryFromParts(shiftedUtc.year, shiftedUtc.month, shiftedUtc.day);
  }

  /// The date [days] days before this one, or `null` if the result leaves `0000`-`9999`.
  Date? trySubtractDays(int days) => tryAddDays(-days);

  /// The whole days from [other] to this date, negative when this one is earlier.
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

  // UTC midnight, used for day arithmetic: a UTC day is always 24 hours, so tryAddDays and differenceInDays
  // can't be skewed by a daylight-saving transition the way a local day can.
  DateTime get _utcMidnight => DateTime.utc(year, month.value, day);

  /// The earliest date, since [year] is held in `0000`-`9999`.
  static const min = Date._(_minYear, Month.january, 1);

  /// The latest, for the same reason.
  static const max = Date._(_maxYear, Month.december, 31);

  /// POSIX's Epoch, where a Unix timestamp counts from.
  static const unixEpoch = Date._(1970, Month.january, 1);

  /// The first day the Gregorian calendar ran. Nothing here treats it specially: the calendar is proleptic,
  /// so the 10 days it skipped parse like any other.
  static const gregorianStart = Date._(1582, Month.october, 15);
}
