part of '../date.dart';

/// The [Date] bounds, plus POSIX's Epoch and the day the Gregorian calendar began.
abstract final class DateConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The earliest date, since [Date.year] is held in `0000`-`9999`.
  static const min = Date._(_minYear, MonthConstants.january, 1);

  /// The latest, for the same reason.
  static const max = Date._(_maxYear, MonthConstants.december, 31);

  /// POSIX's Epoch, where a Unix timestamp counts from.
  static const unixEpoch = Date._(1970, MonthConstants.january, 1);

  /// The first day the Gregorian calendar ran. Nothing here treats it specially: the calendar is proleptic,
  /// so the 10 days it skipped parse like any other.
  static const gregorianStart = Date._(1582, MonthConstants.october, 15);
}
