/// @docImport 'date.dart';
/// @docImport 'month.dart';
library;

part 'constants/day_of_month_constants.dart';

/// The day number within a month, `1` to `31`.
///
/// It bounds what some month could hold, never what a given one does: April has no 31st, and
/// February's 29th needs a leap year. [Date.from] refuses those, given a [Month] and a year.
///
/// Named values: [DayOfMonthConstants].
extension type const DayOfMonth._(int value) implements int {
  /// The [DayOfMonth] with numeric [value], or `null` unless it's in `1`-`31`.
  static DayOfMonth? tryFrom(int value) =>
      value < DayOfMonthConstants.d1 || value > DayOfMonthConstants.d31 ? null : ._(value);
}
