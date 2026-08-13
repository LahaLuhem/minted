/// @docImport 'date.dart';
library;

import 'package:collection/collection.dart';

import '../shared/outcomes/minted_format_exception.dart';
import 'failures/weekday_failure.dart';

/// A day of the week, Monday to Sunday. [Date.weekday] returns one.
///
/// [value] is the ISO 8601 day number, `1` (Monday) to `7` (Sunday), matching [DateTime.weekday];
/// read it rather than the inherited `index`, which is `0`-based and so one less.
///
/// Ordering ([compareTo], `<` / `<=` / `>` / `>=`) runs Monday to Sunday, the ISO week. That is a
/// convention, not arithmetic: weeks starting Sunday or Saturday order the same days differently.
/// [next], [plusDays] and [daysUntil] are cyclic and assume no week start.
/// Standard: [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601).
enum Weekday implements Comparable<Weekday> {
  /// Monday, ISO day `1`.
  monday(1),

  /// Tuesday, ISO day `2`.
  tuesday(2),

  /// Wednesday, ISO day `3`.
  wednesday(3),

  /// Thursday, ISO day `4`.
  thursday(4),

  /// Friday, ISO day `5`.
  friday(5),

  /// Saturday, ISO day `6`.
  saturday(6),

  /// Sunday, ISO day `7`.
  sunday(7);

  new(this.value);

  /// The ISO 8601 day number, `1` (Monday) to `7` (Sunday), matching [DateTime.weekday].
  final int value;

  /// The [Weekday] with ISO day number [value], or `null` unless it is in `1`-`7`.
  static Weekday? tryFrom(int value) => values.firstWhereOrNull((day) => day.value == value);

  /// The [Weekday] with ISO day number [value], throwing [MintedFormatException] unless it is in
  /// `1`-`7`.
  static Weekday from(int value) =>
      tryFrom(value) ?? (throw MintedFormatException.from(WeekdayFailure.notAWeekday, '$value'));

  /// The next day of the week, wrapping from Sunday round to Monday.
  Weekday get next => plusDays(1);

  /// The previous day of the week, wrapping from Monday round to Sunday.
  Weekday get previous => minusDays(1);

  /// The weekday [days] days after this one, wrapping round the week; total for any [days].
  Weekday plusDays(int days) => values[(index + days) % _daysInWeek];

  /// The weekday [days] days before this one, wrapping round the week.
  Weekday minusDays(int days) => plusDays(-days);

  /// Days forward from this weekday to [other], `0`-`6`: `friday.daysUntil(monday)` is `3`, never
  /// negative.
  int daysUntil(Weekday other) => (other.index - index) % _daysInWeek;

  /// Whether this day falls before [other] in the ISO week (Monday first).
  bool operator <(Weekday other) => compareTo(other) < 0;

  /// Whether this day is [other] or falls before it in the ISO week (Monday first).
  bool operator <=(Weekday other) => compareTo(other) <= 0;

  /// Whether this day falls after [other] in the ISO week (Monday first).
  bool operator >(Weekday other) => compareTo(other) > 0;

  /// Whether this day is [other] or falls after it in the ISO week (Monday first).
  bool operator >=(Weekday other) => compareTo(other) >= 0;

  @override
  int compareTo(Weekday other) => value.compareTo(other.value);

  static const _daysInWeek = 7;
}
