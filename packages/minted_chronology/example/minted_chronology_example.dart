// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted_chronology/minted_chronology.dart';

void main() {
  // `Date` is the calendar date `DateTime` doesn't model: no time, no zone. It
  // rejects impossible dates instead of rolling them over the way `DateTime` does.
  // #region date
  final date = Date.tryParse('2026-07-07')!;
  print(date.iso8601); // 2026-07-07
  print(date.month.daysIn(2026)); // 31  (the month is a Month, and knows its length)
  print(date.tryAddDays(30)); // Date(2026-08-06)  (null past the 0000-9999 bound)
  print(date.isBefore(Date.of(2027).getOrThrow())); // true
  print(Date.tryParse('2026-13-01')); // null (no 13th month)
  // #endregion

  // `Iso8601Duration` holds components, because a month has no length until anchored to a date.
  // #region iso8601Duration
  final span = Iso8601Duration.tryParse('P1Y2M3DT4H')!;
  print(span.iso8601); // P1Y2M3DT4H
  print(span.months); // 2
  print(
    span.toDuration(from: Date.of(2026, 1, 31).getOrThrow()),
  ); // 10252:00:00.000000  (427 days and 4 hours)
  print(
    Iso8601Duration.tryParse('P1M')!.toDuration(from: Date.of(2026, 2).getOrThrow()),
  ); // 672:00:00 (28 days)
  print(Iso8601Duration.tryParse('PT1M')!.iso8601); // PT1M  (a minute; P1M is a month)
  print(Iso8601Duration.parse('P1Y2W').reasonOrNull?.message);
  // the week form PnW cannot carry a "Y" component too
  // #endregion
}
