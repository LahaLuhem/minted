[![Pub Version](https://img.shields.io/pub/v/minted_chronology.svg)](https://pub.dev/packages/minted_chronology)
[![Pub Points](https://img.shields.io/pub/points/minted_chronology?logo=dart)](https://pub.dev/packages/minted_chronology/score)
[![Package checks](https://github.com/LahaLuhem/minted/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/minted/actions/workflows/package.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://github.com/LahaLuhem/minted/blob/main/packages/minted_chronology/LICENSE)

# minted_chronology

Calendar dates and durations as well-modelled value types.

Part of the [minted](https://github.com/LahaLuhem/minted) family: pure-Dart value types built on
*parse, don't validate*, so the parser is the only door in and anything that came through it is
well-formed by construction. Once you hold a `Date`, it *is* a real calendar date.

## Install

```sh
dart pub add minted_chronology
```

[`minted`](https://pub.dev/packages/minted) comes with it, holding the vocabulary a parse hands back
(`ParseOutcome`, `MintedFailure`). Nothing here drags in
another domain's engine.

## What's in the box

| Type              | What it guarantees                                                       | Standard                                           |
|-------------------|--------------------------------------------------------------------------|----------------------------------------------------|
| `Date`            | a real calendar date: no time, no zone. Impossible dates rejected        | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |
| `Year`            | a year inside `0000`-`9999`, the window a `Date` renders as `YYYY`       | building block                                     |
| `Month`           | a real month `1`-`12` that knows its own length (leap-aware)             | building block                                     |
| `DayOfMonth`      | a day number `1`-`31`: what some month could hold, not what one does     | building block                                     |
| `Weekday`         | one of 7 named days, ISO-numbered `1` (Monday) to `7` (Sunday)           | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |
| `Iso8601Duration` | a duration with months and years, which `dart:core` Duration cannot hold | [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |

`Date` is the type `DateTime` isn't: no clock, no zone, and an impossible date is refused rather
than rolled over. `Weekday` is an enum a `Date` hands back, so a `switch` over one needs no default
arm.

`Year`, `Month` and `DayOfMonth` are the parts a `Date` is made of, each holding its own range.
Between them they still can't rule out 31 April, which is what `Date.from` refuses.

## A quick taste

```dart
final date = Date.tryParse('2026-07-07')!;   // strict ISO 8601 YYYY-MM-DD
date.iso8601;             // '2026-07-07'   (canonical form)
date.weekday;             // Weekday.tuesday   (.value is 2, matching DateTime.weekday)
date.month.daysIn(2026);  // 31   (the month is a Month, and knows its length)
date.tryAddDays(30);      // Date(2026-08-06)
date.tryAddDays(3000000); // null   (the walk left the 0000-9999 bound)
Date.now();               // today in the local zone, the date-only DateTime.now()

// impossible dates are rejected, not rolled over the way DateTime does:
Date.tryParse('2026-13-01');   // null (no 13th month; DateTime would give 2027-01-01)

// Weekday arithmetic wraps round the week, and bridges back from dart:core:
date.weekday.next;                         // Weekday.wednesday
Weekday.friday.daysUntil(Weekday.monday);  // 3
Weekday.tryFrom(DateTime.now().weekday);   // a Weekday, or null

// Iso8601Duration holds components, because a month has no length until anchored to a date:
final span = Iso8601Duration.tryParse('P1Y2M3DT4H')!;
span.months;                                        // 2
span.toDuration(from: Date.of(2026, 1, 31).getOrThrow());  // 427 days and 4 hours
Iso8601Duration.tryParse('PT1M')!.iso8601;          // 'PT1M'   (a minute; P1M is a month)
Iso8601Duration.tryParse('P1Y2W');                  // null: the week form never mixes
```

The runnable version is the
[example](https://github.com/LahaLuhem/minted/blob/main/packages/minted_chronology/example/minted_chronology_example.dart).

## Named constants

A type's named values live in a companion `<Type>Constants` namespace, so the type itself stays its
parsing API. They're `const`, so they reach where a `tryParse(...)!` can't.

```dart
DateConstants.unixEpoch.weekday;        // Weekday.thursday
DateConstants.max.tryAddDays(1);        // null, nothing sits after it
MonthConstants.february.daysIn(2024);   // 29
Iso8601DurationConstants.zero.iso8601;  // 'PT0S'
```

`DateConstants` names the 2 bounds, POSIX's Epoch, and the first day the Gregorian calendar ran.
`MonthConstants` names all 12. `Iso8601DurationConstants` names the zero that ISO 8601 makes you
write as `PT0S`, since a duration needs at least 1 component.

## One shape, every type

- `Type.tryParse(input)` hands back the value, or `null` when the input isn't valid
- `Type.parse(input)` hands back a `ParseOutcome`: the value, or a typed failure (`DateFailure`,
  `MonthFailure`, `Iso8601DurationFailure`) you can `switch` on, or read as a form-field message via
  `.reasonOrNull`. No door throws
- value equality, a canonical `.iso8601`, chronological ordering (`<`, `isBefore`, `compareTo`), and
  `Date.from` / `Date.of` / `Date.fromDateTime` for parts you already hold. `from` takes the modelled
  parts and can only refuse the day, `of` takes plain `int`s and reports whichever one is wrong
- `Weekday` is a classification rather than a parsed value, so it takes `tryFrom(isoDayNumber)`
  instead of a parse door

The [`minted` README](https://pub.dev/packages/minted) is the family guide: the package index,
handling failures, and the one caveat (never cast into a minted type).

[APPENDIX.md](./APPENDIX.md) carries the design rationale for these types: the alternatives
that were weighed and dropped, and what each decision costs.
