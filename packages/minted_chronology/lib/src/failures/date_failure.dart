/// @docImport '../date.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

import '../normalisation/iso_date_format.dart';

/// Why a [Date] refused its input. Sealed rather than an enum, because the variants hand the offending
/// number back.
@immutable
sealed class const DateFailure() implements MintedFailure {
  @override
  String get typeName => 'Date';
}

/// Why one of a date's parts was refused: the subset [Date.of] can report, where the shape isn't in
/// question. Lets a caller assembling from parts switch without an arm for [DateNotIso8601].
@immutable
sealed class const DateComponentFailure() extends DateFailure;

/// The text isn't the ISO 8601 `YYYY-MM-DD` shape.
final class const DateNotIso8601() extends DateFailure {
  /// Creates the failure.
  this;

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
final class const DateYearOutOfRange(
  /// The offending year.
  final int year,
) extends DateComponentFailure {
  /// Creates the failure.
  this;

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
final class const DateMonthOutOfRange(
  /// The offending month number.
  final int month,
) extends DateComponentFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'month $month is outside 1-12';

  @override
  bool operator ==(Object other) => other is DateMonthOutOfRange && other.month == month;

  @override
  int get hashCode => Object.hash(DateMonthOutOfRange, month);

  @override
  String toString() => 'DateMonthOutOfRange($month)';
}

/// The day falls outside `1`-[maxDay]. Leap-year aware, so 29 February is out of range in a common year
/// and in range in a leap one.
final class const DateDayOutOfRange({
  /// The year the day was given for.
  required final int year,

  /// The month number the day was given for.
  required final int month,

  /// The offending day.
  required final int day,

  /// The last day of [month] in [year], leap-year aware.
  required final int maxDay,
}) extends DateComponentFailure {
  /// Creates the failure.
  this;

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
