/// @docImport '../date.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/iso_date_format.dart';
import '../../shared/minted_failure.dart';

/// Why a [Date] refused its input. Sealed, not an enum, because the variants report the offending
/// number back. Two remedies: [DateNotIso8601] means fix the format, the rest mean fix a number.
@immutable
sealed class DateFailure implements MintedFailure {
  const DateFailure();

  @override
  String get typeName => 'Date';
}

/// The text is not the ISO 8601 `YYYY-MM-DD` shape.
final class DateNotIso8601 extends DateFailure {
  /// The failure [Date.parse] reports for text of the wrong shape.
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

/// The day falls outside `1`-[maxDay]. The bound is leap-year aware, so 29 February is out of
/// range in a common year and in range in a leap one.
final class DateDayOutOfRange extends DateFailure {
  /// The year the day was given for.
  final int year;

  /// The month number the day was given for.
  final int month;

  /// The offending day.
  final int day;

  /// The last day of [month] in [year], leap-year aware.
  final int maxDay;

  /// The failure reported for a [day] outside `1`-[maxDay].
  const DateDayOutOfRange({
    required this.year,
    required this.month,
    required this.day,
    required this.maxDay,
  });

  @override
  String get message => 'day $day is outside 1-$maxDay for ${isoYearMonth(year, month)}';

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
