# APPENDIX — `minted_chronology`

Design rationale for the types this package ships. Family-wide rationale lives in the
[workspace APPENDIX][appendix-md], code style in [CODESTYLE.md][codestyle-md]. Link by the explicit
`<a id="…">` anchors and keep them stable across renames.

<!-- TOC start -->

- [Date: a calendar date, not an instant](#date-value-type)
- [Weekday: an enum, where Month is an extension type](#weekday-enum)
- [Iso8601Duration: components, not a scalar](#iso8601-duration-value-type)

<!-- TOC end -->

---

<a id="date-value-type"></a>
## Date: a calendar date, not an instant

`DateTime` is the stdlib's time type, but it models an *instant*: a date, a time-of-day, and a zone,
down to the microsecond. A birthday or an invoice date is none of those things below the day, yet
`DateTime` is what everyone reaches for, so a plain date ends up carrying a stray `00:00:00` and a
zone. That is where the bugs come from: two "equal" dates that differ by a time nobody set, or a
date that slides across midnight when it crosses a zone. Dart has no date-only sibling to `DateTime`
(no `LocalDate`), so `Date` is that missing value.

**An immutable class, not an extension type.** Three fields means the [multi-part
shape][extension-type-representation], and the zero-cost alternatives do not hold up: an extension
type over `DateTime` cannot override `toString`, so it would print `2026-07-07 00:00:00.000` and
inherit the rollover; one over a packed `int` has an opaque canonical form and needs arithmetic to
read a component back.

**`Month` is a type; `day` and `year` are plain `int`.** A month is one of twelve regardless of
context, so `Month` is a clean building block, and it owns the calendar knowledge that hangs off a
month (`Month.daysIn(year)` is leap-aware, so `Date` delegates rather than carrying a length table).
A *day* is only valid relative to a month and a year, so a standalone `Day(1-31)` would be a shape
check that leaves `Date` doing the real validation, and a type named `Day` that accepts 31 February
overpromises on its name. `year` would be only a thin bounded `int`. This is the
[typing-versus-honesty balance][typing-versus-honesty] resolved per field.

**A validating factory, not a raw constructor.** `Date.of(2026, 7, 7)` validates and reports, backed
by a private `Date._`. A plain `const` constructor cannot promise the guarantee, because its
`assert`s are stripped in release builds, so `Date.of(2026, 13, 40)` would leak into production. The
cost is that `Date.of(...)` is not `const`; neither is `DateTime(...)`.

**Named, because a factory constructor cannot return an outcome.** `Date(y, m, d)` was the spelling
until v2, and a factory constructor must return its own type, so only the named form could grow the
`ParseOutcome` return every other door has. Its failure type is the parts-only subset
(`DateComponentFailure`), so a caller assembling from parts has no shape arm to fold: the shape was
never in question.

**Reject, don't roll over.** Where `DateTime(2026, 13, 1)` silently becomes 2027-01-01, `Date`
rejects it. Rolling an out-of-range part over invents a different value instead of refusing a bad
one, which is the opposite of parse-don't-validate.

**Local `toDateTime()`, UTC arithmetic.** `toDateTime()` returns local midnight, matching what
callers write today. Day arithmetic (`addDays`, `differenceInDays`) works in UTC internally, because
a UTC day is always 24 hours when a daylight-saving transition makes a local one 23 or 25, which
would skew the count.

**`Date.now()` types the clock, it does not read it**, being `Date.fromDateTime(DateTime.now())`:
the same division of labour as [`Uuid`][uuid-value-type]. Local, matching its sibling; for the UTC
day, `Date.fromDateTime(DateTime.now().toUtc())`.

**Year `0000`-`9999`**, so the canonical `YYYY-MM-DD` form is always well defined. The expanded ISO
representation (a leading sign and more digits) is out of scope and can be added later without
breaking the four-digit forms.

---

<a id="weekday-enum"></a>
## Weekday: an enum, where Month is an extension type

Two closed sets of named numbers, two different shapes, and the deciding question is not size but
what the value *is*. `Month` is a **parsed component**: position two of `YYYY-MM-DD`, stored by
`Date`, read out of text by `Month.parse`. `Weekday` is **derived**: nothing stores it, it never
appears in a canonical form, and it only comes from a date that already parsed. That is
`UuidVariant`'s profile, and the package already splits on it: parsed components take the
[value-type contract][value-type-contract], derived classifications are a plain enum.

**An enum, because seven days is a set that can be named honestly**, which is the same test
[`Uuid.version` fails and `UuidVariant` passes][uuid-value-type]. The payoff is exhaustiveness: a
`switch` over a `Weekday` needs no default arm and the compiler catches the day you forgot, which is
most of what weekday code does. An extension type over `int` cannot offer that at any price, since
only sealed types and enums drive exhaustiveness. The cost is an `index` sitting one apart from
`value`, so the dartdoc names `value` as the ISO number and points away from `index`.

**Ordering is a convention, and the type says so.** `compareTo` and the comparison operators run
over the ISO number, so Monday sorts first, but that is a choice rather than arithmetic: weeks begin
on Sunday in the US, Canada, and Japan and on Saturday across much of the Middle East. A weekday is
a *cycle*, and ordering a cycle means picking an origin, where [`Date`](#date-value-type) earns its
operators outright because dates are totally ordered. So the comparisons document the origin they
assume, and the origin-free arithmetic (`next`, `plusDays`, `daysUntil`, all modular and total) is
the safer default. Same reason there is no `isWeekend`: ISO 8601 numbers the days and says nothing
about which are a weekend, so a bare answer would be an opinion wearing a standard's name.

**No failure vocabulary, because nothing produces one.** `WeekdayFailure` existed for a single use,
`Weekday.from` throwing outside `1`-`7`. Once that door went (a range check needs only `tryFrom`,
and `null` says everything one invariant can), the type had no producer left and went with it. Same
story for `DigitFailure` and `DigitsFailure`: a vocabulary with no producer is public surface
carrying nothing.

---

<a id="iso8601-duration-value-type"></a>
## Iso8601Duration: components, not a scalar

**It does not extend `Duration`, and the reason is not that Dart forbids it.** Both `extends` and
`implements` are allowed. But a subclass must hand `super` a microsecond count, and `P1M` has none,
so the seed is a fiction every inherited member then reports with confidence: `inDays` answers 30,
`P1M == Duration(days: 30)` is true, and `P1M > P31D` is false. `toString` can be overridden;
`inDays`, `==`, `compareTo` and the arithmetic operators read the private field directly and cannot
be made to say "it depends on the anchor". Inheriting converts "unanswerable without a date" into a
wrong answer, which is the opposite of what the type is for. `implements` costs more, not less:
about twenty members written by hand, each facing the same problem.

**Composing a `Duration` for the exact part was the closer call.** Weeks down to seconds are all
fixed-length, so `years`, `months` and one `Duration` would replace eight fields and drop the
component enum, roughly 50 lines. It was declined because a fraction of a month is not a fixed
`Duration`, so `P0.5Y` and `P0.5M` become inexpressible unless those two fields turn into doubles,
and `P2W` collapses into `P14D` without a flag to hold the form. The components model keeps the
fidelity; the saving was not worth trading it for.

**`toDuration` takes a required named `from`.** A month is 28 to 31 days, so the anchor is what
makes the question answerable at all, and a named parameter makes it impossible to supply by
accident. Calendar components resolve first, clamping the day the way `2026-01-31` plus a month
gives `2026-02-28`.

**The week form is exclusive because ISO 8601 says so.** `PnW` is an alternative to
`PnYnMnDTnHnMnS`, not a component of it, so `P1Y2W` is refused rather than read as 54 weeks. Same
reasoning as [checking the real standard][check-digits-not-regex] elsewhere: accepting input the
standard does not define is as wrong as refusing input it does.

**Zero spells itself.** Components that are absent or zero collapse, which would leave bare `P`, and
`P` is not a duration. The canonical form emits `PT0S`, so it round-trips like every other type's.

[appendix-md]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md
[check-digits-not-regex]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#check-digits-not-regex
[codestyle-md]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md
[extension-type-representation]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#extension-type-representation
[typing-versus-honesty]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#typing-versus-honesty
[uuid-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_identifiers/APPENDIX.md#uuid-value-type
[value-type-contract]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md#value-type-contract
