part of '../date.dart';

/// The [Date] bounds, plus POSIX's Epoch and the day the Gregorian calendar began.
abstract final class DateConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The earliest date, since [Date.year] is held in `0000`-`9999`.
  static const min = Date._(YearConstants.min, MonthConstants.january, DayOfMonthConstants.d1);

  /// The latest, for the same reason.
  static const max = Date._(YearConstants.max, MonthConstants.december, DayOfMonthConstants.d31);

  /// POSIX's Epoch, where a Unix timestamp counts from.
  static const unixEpoch = Date._(
    YearConstants.unixEpoch,
    MonthConstants.january,
    DayOfMonthConstants.d1,
  );

  /// The first day the Gregorian calendar ran. Nothing here treats it specially: the calendar is proleptic,
  /// so the 10 days it skipped parse like any other.
  static const gregorianStart = Date._(
    YearConstants.gregorianStart,
    MonthConstants.october,
    DayOfMonthConstants.d15,
  );
}
