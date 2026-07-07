# APPENDIX — `minted`

Design rationale: the "why" behind decisions that the code and the hard rules alone don't
explain. Hard rules and workflow live in [`.ai/AGENTS.md`](./.ai/AGENTS.md); code style in
[`CODESTYLE.md`](./CODESTYLE.md). Each heading carries an explicit `<a id="…">` anchor; link by
anchor, and keep anchors stable across renames.

<!-- TOC start -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#ai-files-symlinked)
- [Pure-Dart package, no Flutter dependency](#pure-dart-not-flutter)
- [Parse, don't validate](#parse-dont-validate)
- [Extension type vs immutable class](#extension-type-representation)
- [Typed digits: `Digit` and `Digits`](#typed-digit-subparts)
- [Why a typed `FormatException`](#why-typed-format-exception)
- [Normalise on parse](#normalise-on-parse)
- [Check the real standard, not a regex shape](#check-digits-not-regex)
- [Behavioural tests: a helper, not a framework](#behavioural-tests-helper)
- [Public API funnelled through `lib/minted.dart`](#public-api-via-single-export-file)
- [Packaging: one core, companions for opinionated deps](#packaging-core-and-companions)
- [British spelling in the public API](#spelling)
- [SDK floor](#sdk-floor)
- [What `minted` deliberately does not cover](#what-not-covered)

<!-- TOC end -->

<a id="ai-files-symlinked"></a>
## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

The canonical files live in [`.ai/`](./.ai/); the repo-root `AGENTS.md` and `CLAUDE.md` are
symlinks to them. Keeping the sources in `.ai/` groups the agent-facing docs in one place while
still letting tools that look at the repo root (and humans) find them. `.pubignore` excludes both
the symlinks and the targets so none of it ships in the published tarball.

---

<a id="pure-dart-not-flutter"></a>
## Pure-Dart package, no Flutter dependency

`minted` is value types with validation logic and nothing platform-specific, so it stays pure
Dart: no Flutter dependency, no `dart:io`, no platform channels. That keeps it usable in a Dart
server, a CLI, a web app, and a Flutter app alike, which is exactly the set of places these
primitives (email, IBAN, card numbers) show up.

Anything that would need Flutter (a `FormField` validator, a `TextInputFormatter`) or another
heavy dependency does not go here; it goes in a companion package (see
[packaging](#packaging-core-and-companions)). The core's dependency list is a promise to every
downstream user, so it stays as short as the validation honestly requires.

---

<a id="parse-dont-validate"></a>
## Parse, don't validate

The organising principle, after Alexis King's essay of the same name. A function that *validates*
takes a `String`, checks it, and hands the same `String` back; every later consumer has to trust
that the check happened and re-check if unsure. A function that *parses* takes a `String` and
returns a **different type** that can only exist if the input was well-formed. The validity
becomes a fact of the type system, checked once, carried everywhere.

That is what `Uri` does for URLs and `int.parse` does for integers, and it is what every `minted`
type does for its domain. The mechanics that enforce it:

- The primary constructor is **private** (`._`). No caller can build an instance directly.
- The only way in is `tryParse` (returns `T?`) or `parse` (throws). Both run the full check.
- Therefore an instance of `Iban` is a proof that the string passed mod-97; a `CreditCardNumber`
  is a proof that it passed Luhn. Downstream code stops re-checking and stops carrying "is this
  string actually valid?" as an open question.

This is the direct antidote to primitive obsession: `String email, String phone, String name`
are three interchangeable, mixed-up-able parameters; `Email`, `Phone`, `PersonName` are not.

---

<a id="extension-type-representation"></a>
## Extension type vs immutable class

Two shapes, chosen by the data, both presenting the [same contract](./CODESTYLE.md#value-type-contract).

**Single primitive → extension type.** An `extension type const Email._(String value)` is a
purely static, zero-runtime-cost wrapper: at runtime the instance *is* the `String`, so there is
no allocation and no indirection. Equality, `hashCode`, and `toString` delegate to the
representation, which is precisely what a `String`-backed value type wants: two `Email`s that
normalise to the same string are equal and hash equal for free, and `print(email)` shows the
email. The trade-offs are real and deliberate:

- You cannot override `toString` / `==` / `hashCode` (the analyzer forbids redeclaring `Object`
  members on an extension type). Fine here, because the delegated behaviour is the behaviour we
  want.
- There is no runtime distinction between the type and its representation (`email is String` is
  true). So the type safety is compile-time only, which is where primitive obsession bites
  anyway, and serialization must be explicit rather than reflective.
- `const` construction is closed to callers (the constructor is private). That is the point:
  closing construction is what makes the invariant hold. Curated constants (say `CountryCode.gb`)
  are still built inside the library via the private constructor.

**Multiple parts → immutable class.** When a value is genuinely several fields (a coordinate's
latitude and longitude), an `@immutable final class` with a private constructor, hand-written
`==` / `hashCode`, and a `ClassName(...)` `toString` is the right shape. No `Equatable`
dependency: the core stays dependency-light, and hand-written equality is a few honest lines.

---

<a id="typed-digit-subparts"></a>
## Typed digits: `Digit` and `Digits`

The parse-don't-validate guarantee normally stops at the whole value (`Iban`, `PhoneNumber`).
Where a validated whole exposes a part that is *only* decimal digits, that part is typed as digits
rather than a raw `String`, so "these are digits" is a fact of the type instead of an assumption
each caller re-checks. Neither `Digit` nor `Digits` is a domain entity from a standard; they are
the building blocks the standard types are cut from.

`Digit` (a single `0`-`9`) is an `extension type` over `int`, so it erases at runtime and costs
nothing per value; `.value` is the number. Arity decides how each consumer exposes its digits.
`Iban.checkDigits` is always exactly two, so it is a `({Digit first, Digit second})` record (a
record gives structural value equality for free). `PhoneNumber.nationalNumber` is variable-length,
so it is a `Digits`.

`Digits` (a sequence) is where the representation matters. The obvious `List<Digit>` is a trap:
the element type erases, so `List<Digit>` *is* `List<int>` at runtime, one pointer-sized word per
digit, roughly eight times the bytes of the string it came from. So `Digits` is backed by a
`Uint8List`: one byte per digit, and a real `Uint8Array` on the web (where a `String` would be
two-byte UTF-16). `dart:ffi`'s fixed-width types are not an option: they are native-ABI markers for
C interop, not web-safe, and no C ABI has a sub-byte scalar, so there is nothing to pack against
there.

`Digits` is an `@immutable` class, not an extension type, for two reasons. Value equality: an
extension type's `==` delegates to its representation and can't be overridden, and `Uint8List` uses
*identity* equality, so `Digits.parse('12')` would never equal another `Digits.parse('12')`; the
class hand-writes structural `==`/`hashCode` over the bytes (its first use of `package:meta`, for
`@immutable`). Encapsulation: the `Uint8List` is private, so a denser backing (nibble-packed BCD at
two digits per byte, or tighter) can replace it behind the same `Iterable<Digit>` / `operator []` /
`asString` interface without touching callers. Packing is deferred on purpose; it only pays off at
a volume identifiers rarely reach, and the unpacked bytes read as the digits under a debugger.

---

<a id="why-typed-format-exception"></a>
## Why a typed `FormatException`

`parse` throws `MintedFormatException`, which **extends** `dart:core`'s `FormatException`. Two
goals at once:

- **Stdlib-consistent.** The package sells itself as "like `Uri`", and `int.parse` / `Uri.parse`
  / `DateTime.parse` all throw `FormatException`. Anyone already writing `on FormatException`
  catches ours too. It carries the offending `source` and an optional `offset`, same as the base.
- **Discriminable.** Extending (rather than throwing the base type) lets a caller write
  `on MintedFormatException` to catch specifically this package's parse failures, and lets us
  attach a consistent, informative message (`'Invalid Iban: failed mod-97 check'`) via a shared
  `MintedFormatException.of(typeName, source, reason)` factory. The type name is an explicit
string, not a `<T>`, because the value types are extension types that erase to their representation
at runtime, so a `'$T'` in the message would render `String`, not `Iban`.

`tryParse` throws nothing and returns `null`; the throwing path is `parse` only. A failed parse
is a runtime condition on untrusted input, so it is always a `throw`, never an `assert` (see
[CODESTYLE class structure](./CODESTYLE.md#class-structure)).

---

<a id="normalise-on-parse"></a>
## Normalise on parse

`tryParse` reduces input to one canonical form before it constructs the instance: trim
whitespace, strip the separators the standard treats as cosmetic (spaces in an IBAN, dashes in a
card number), and case-fold the parts the standard says are case-insensitive (an IBAN is
upper-case; an email's domain is lower-case, its local-part left as-is).

This is not cosmetic. Extension-type equality is representation equality, so the stored canonical
form *is* the equality key. Normalising on the way in is what makes
`Iban.parse('gb82 west 1234') == Iban.parse('GB82WEST1234')` hold, and what makes these types
safe to use in a `Set` or as a `Map` key. Each type documents its exact normalisation in dartdoc
so the canonicalisation is never a surprise. Render helpers (`Iban.formatted`, the grouped paper
form) reconstruct a display form from the canonical one on demand; they do not change what is
stored.

---

<a id="check-digits-not-regex"></a>
## Check the real standard, not a regex shape

Where a standard defines a checksum, `minted` computes it. IBAN carries a mod-97 check; card
numbers carry a Luhn check; ISBN, EAN/GTIN, and ISSN carry check digits. A regex that matches the
*shape* (right length, right character classes) accepts an enormous number of strings the
standard rejects, and shipping that would defeat the entire "an instance is a proof of validity"
premise. These check-digit types are the highest-value members of the package precisely because
the standard hands us a real correctness test, not just a format.

Tests for these types use the **official standard test vectors** (the IBAN registry examples, the
Luhn worked examples, published ISBN/EAN check-digit cases), plus deliberately corrupted variants
(one transposed digit, one wrong check digit) that must be rejected.

---

<a id="behavioural-tests-helper"></a>
## Behavioural tests: a helper, not a framework

Tests read as behaviour (Given/When/Then, one named case per row), but that framing comes from a
tiny in-repo helper, not a BDD framework. [`test/support/bdd.dart`](./test/support/bdd.dart) is
about 25 lines of `feature` / `scenario` / `scenarioOutline` over `package:test`, with the
assertions still written in `package:checks`.

A real Gherkin runner was on the table and was turned down on the merits. An earlier
`bdd_framework` dev-dependency had already been dropped because it pulled in `flutter_test`, which
breaks `dart test` off Flutter and clashes with the `analyzer` / `meta` pin. Its pure-Dart
replacement, the `gherkin` package, was then evaluated properly: it *does* resolve against the full
dependency set and runs Flutter-free under Dart 3.12 when wrapped in a `package:test` case. It was
still rejected, for reasons independent of the version:

- **No audience for the payoff.** Gherkin earns its keep when non-technical stakeholders read and
  write `.feature` files. `minted`'s consumers are Dart developers; there is nobody here for whom
  `Given the input "a@b.com" Then it is rejected` beats `check(Email.tryParse('a@b.com')).isNull()`.
  The specification is the published standard (RFC 5322, ISO 13616) plus the dartdoc and the
  structural [`test/conformance_test.dart`](./test/conformance_test.dart), all already executable.
- **Ceremony over pure functions.** A value type is a single-call, stateless parse. Gherkin's
  Given/When/Then and `World` context are built for stateful, multi-step flows; routing a pure
  parse through them means inventing a stateful world just to carry the input across three steps.
- **It degrades `dart test`.** The runner reports a whole feature as one opaque test; the
  individual scenarios are printed by its own reporter and stay invisible to `dart test`'s test
  counting, `-n` name filtering, and per-case failure attribution.
- **Frozen.** `gherkin`'s last release was 2022 (Dart 2.15 era); it resolves under Dart 3 only
  because pub relaxes the legacy `<3.0.0` SDK cap, and it holds `uuid` below 4.

The helper keeps the readability that was actually wanted and drops all four costs. Every example
row stays a genuine `dart test` case, so counting, `-n` filtering, and failure naming still work.
The examples table is the point: each row groups its input parameters with the expected outcome
under a descriptive name, so the cases read as a table instead of literals scattered across
separate tests and loop lists. Where a type normalises on parse, the canonical form doubles as the
outcome (a string means "accepted and normalised to this", `null` means "rejected"), folding
acceptance, rejection, and normalisation into one table. The how-to is in
[CODESTYLE test style](./CODESTYLE.md#test-style).

---

<a id="public-api-via-single-export-file"></a>
## Public API funnelled through `lib/minted.dart`

The public API is only what [`lib/minted.dart`](./lib/minted.dart) re-exports. Everything under
`lib/src/` is private by convention; consumers never import `package:minted/src/…`. One barrel
means the public surface is auditable in one file, and moving code around inside `lib/src/` is
never a breaking change as long as the re-exports hold. Each value type is one self-contained file
under `lib/src/<type>.dart`; shared internals (the `MintedFormatException`, the check-digit
helpers) live under `lib/src/shared/`.

---

<a id="packaging-core-and-companions"></a>
## Packaging: engine dependencies in core, adapters in companions

The constraint is that no *opinionated* dependency is forced on a consumer who just wants the value
types. In Dart, dependencies are declared per package, not per library: the moment any file in
`minted` imports a package, that package lands in *every* consumer's resolution and lockfile, even
someone who only touches one type. Tree-shaking drops unused *code* from a release binary, but not
the entry in the dependency graph. So "one package with optional heavy libraries" is not possible;
the decision turns on *what a dependency is for*, not merely whether there is one.

- **Engine dependencies live in core.** A dependency that a core value type is *built on* may sit
  in core, provided it is pure Dart, web-safe, and free of a heavy transitive closure: `Email`
  wraps `email_validator`, `Iban` wraps `iban_validator`, and a `Phone` type wraps
  `phone_numbers_parser`. These are the parser or registry the type needs to exist, in the same
  category as each other. The guard still rejects a heavy or platform-bound engine: a type whose
  only parser dragged in Flutter or a large runtime would go to a companion instead.
- **Adapter dependencies go in companions.** A dependency that *adapts* the value types to another
  ecosystem is genuinely opt-in and must never burden core: `fpdart` (Option / Either), `hive`
  (persistence), a Flutter form-field validator. Each becomes its own package (`minted_fpdart`,
  `minted_hive`, `minted_flutter`), depending on core plus its one integration dependency.
- **Zero-dependency integrations can be opt-in libraries in core.** JSON via plain methods, where
  `fromJson` is just `parse`, needs no extra dependency, so it can live in core as
  `package:minted/json.dart` without forcing anything on anyone.

Companions are built when actually needed, as their own repositories, matching the maintainer's
other packages. A monorepo / pub workspace is a later option if the companion count grows enough.

---

<a id="spelling"></a>
## British spelling in the public API

Prose and identifiers use British spelling (`normalise`, `canonicalise`, `behaviour`), matching
the maintainer's other packages. The one carve-out is any name fixed by the SDK or a dependency:
`toJson`, `compareTo`, `hashCode`, and the `LICENSE` filename stay as they are. This costs almost
nothing on this package's surface, because the value-type API (`parse`, `tryParse`, `value`,
`formatted`, `checkDigits`, `mailtoUri`) barely contains a spelling-divergent identifier;
"normalise" stays internal to parsing.

---

<a id="sdk-floor"></a>
## SDK floor

The floor is **Dart 3.12** (`sdk: ^3.12.0`). Extension types (the mechanism behind every
single-primitive type) need ≥ 3.3, and static dot shorthands need ≥ 3.10; pinning at 3.12 gets
both as stable, on-by-default features. The trade-off is reach: 3.12 is recent, so a project on an
older SDK can't depend on `minted`. For a fresh package that is an acceptable price for building
on current language features, and since a floor can only be raised (never lowered) without a
breaking change, starting current avoids churn later.

**Primary (declaring) constructors are deliberately not used**, even though they exist in 3.12.
They are still an *experiment* there (`--enable-experiment=primary-constructors`, off by default,
verified against 3.12.2). Experiments are per-compilation and global, so a published package that
used them would force every downstream consumer to enable the same experiment in their own build,
and the syntax can still change before it stabilises. Until the feature ships stable (no flag),
the private-representation extension type (`extension type const T._(String _value)`) already
gives the same "private field declared at the constructor" shape with zero experiments; revisit
the [value-type contract](./CODESTYLE.md#value-type-contract) when it stabilises. Record any floor
bump here, since it is breaking for anyone on the older SDK.

---

<a id="date-value-type"></a>
## Date: a calendar date, not an instant

`DateTime` is the stdlib's time type, but it models an *instant*: a date, a time-of-day, and a
zone, down to the microsecond. A birthday or an invoice date is none of those things below the
day, yet `DateTime` is what everyone reaches for, so a plain date ends up carrying a stray
`00:00:00` and a zone. That is where the bugs come from: two "equal" dates that differ by a time
nobody set, or a date that slides across midnight when it crosses a zone. Dart has no date-only
sibling to `DateTime` (no `LocalDate`), so `Date` is that missing value.

**An immutable class, not an extension type.** A date is three fields (year, month, day), so it
takes the [multi-part shape](#extension-type-representation), not an extension type. The
zero-cost alternatives don't hold up: an extension type over `DateTime` can't override `toString`,
so it would print `2026-07-07 00:00:00.000` instead of `2026-07-07`, and it would inherit
`DateTime`'s rollover; an extension type over a packed `int` (days-since-epoch, or a `yyyymmdd`
number) has an opaque canonical form and needs arithmetic to read a component back. Plain fields
with hand-written equality read best and cost least in confusion.

**`Month` is a type; `day` and `year` are plain `int`.** A month is one of twelve regardless of
context, so `Month` (an extension type on `int`, 1-12) is a clean building block, and it owns the
calendar knowledge that hangs off the month: `Month.daysIn(year)` gives the length, leap-aware, so
`Date` delegates to it instead of hand-rolling a month-length table. A *day*, by contrast, is only
valid relative to a month and a year (is there a 30 February? a 31 April?), so a standalone
`Day(1-31)` would be a shape check that still leaves `Date` to do the real validation, and a type
named `Day` that accepts 31 February over-promises on its name. The meaningful notion of a valid
day lives in `Date`, so `day` stays `int`; `year` would be only a thin bounded `int`, so it stays
`int` too.

**A validating factory, not a raw constructor.** `Date(2026, 7, 7)` is a factory that validates
and throws `MintedFormatException` on an impossible date, backed by a private `Date._`. It is not
a plain public constructor, because the package's guarantee is that every instance is well-formed
and a raw constructor can't promise that: a `const` constructor's `assert`s are stripped in release
builds, so `Date(2026, 13, 40)` would leak an impossible date into production. The factory is the
parts-keyed parsing entry point the [value-type contract](./CODESTYLE.md#value-type-contract)
allows, so the guarantee holds. The cost is that `Date(...)` is not `const`; neither is
`DateTime(...)`, and the type is new, so nothing downstream loses a `const` it had.

**Reject, don't roll over.** Where `DateTime(2026, 13, 1)` silently becomes 2027-01-01, `Date`
rejects it. Rolling an out-of-range part over is the opposite of parse-don't-validate: it invents
a different value instead of refusing a bad one.

**Local `toDateTime()`, UTC arithmetic.** `toDateTime()` returns local midnight, matching the
`DateTime(year, month, day)` callers write today, so moving a value to `Date` and back preserves
behaviour. Day arithmetic (`addDays`, `differenceInDays`) works in UTC internally, because a UTC
day is always 24 hours and a local one is not (a daylight-saving transition makes a local day 23
or 25 hours, which would skew the count).

**Year `0000`-`9999`.** Parsing is the strict ISO 8601 calendar date `YYYY-MM-DD`, so the year is
four digits and the canonical form is always well-defined; the factory holds the same range. The
expanded ISO representation (a leading sign and more than four digits) is deliberately out of
scope, and can be added later without breaking the four-digit forms.

---

<a id="what-not-covered"></a>
## What `minted` deliberately does not cover

`minted` targets the gap where no clean Dart value type exists. It does not re-model things the
Dart stdlib or a strong existing package already handles well:

- **Stdlib already covers:** URLs/URIs (`Uri`), IP addresses (`InternetAddress`), instants and
  durations (`DateTime` / `Duration`), big integers (`BigInt`); in Flutter, `Color`, `Locale`,
  `TimeOfDay`.
- **Strong existing packages cover (wrap or reuse, don't reimplement):** phone numbers
  (`phone_numbers_parser`), money/decimals (`money2`, `decimal`, `rational`), UUIDs (`uuid`),
  SemVer (`pub_semver`), formatting and ISO code *lists* (`intl`), IANA time zones (`timezone`),
  hashes (`crypto`).

The one apparent overlap is date-only values. `DateTime` models an *instant* (a date, a time,
and a zone), not a plain calendar date, and Dart has no `LocalDate`, so [`Date`](#date-value-type)
fills that gap rather than re-modelling `DateTime`.

Where `minted` builds *on* such a package (a `Phone` type wrapping `phone_numbers_parser`, or
`email_validator` for the email grammar, or `iban_validator` for the IBAN registry), it wraps rather
than reinvents. A pure-Dart, web-safe engine sits in core; only an adapter to another ecosystem goes
in a companion (see [packaging](#packaging-core-and-companions)). The README carries the full,
current comparison and the roadmap of gap types still to land.
