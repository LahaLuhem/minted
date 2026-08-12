# APPENDIX — `minted`

Design rationale: the "why" behind decisions that the code and the hard rules alone don't
explain. Hard rules and workflow live in [`.ai/AGENTS.md`](./.ai/AGENTS.md); code style in
[`CODESTYLE.md`](./CODESTYLE.md). Each heading carries an explicit `<a id="…">` anchor; link by
anchor, and keep anchors stable across renames.

<!-- TOC start -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#ai-files-symlinked)
- [Pure-Dart package, no Flutter dependency](#pure-dart-not-flutter)
- [The format gate runs Flutter's Dart, everything else runs Dart stable](#ci-sdk-toolchain)
- [Parse, don't validate](#parse-dont-validate)
- [Extension type vs immutable class](#extension-type-representation)
- [Compose from modelled parts, don't re-derive them](#compose-from-modelled-parts)
- [Typed digits: `Digit` and `Digits`](#typed-digit-subparts)
- [Why a typed `FormatException`](#why-typed-format-exception)
- [A throw is for a claim you made in source](#claim-in-source)
- [Why a bespoke `ParseOutcome`, not `Either`](#parse-outcome)
- [Failures are per type, because standards are](#per-type-failures)
- [Normalise on parse](#normalise-on-parse)
- [Check the real standard, not a regex shape](#check-digits-not-regex)
- [Registry data ships a clock](#registry-data-ships-a-clock)
- [Behavioural tests: a helper, not a framework](#behavioural-tests-helper)
- [Public API funnelled through `lib/minted.dart`](#public-api-via-single-export-file)
- [Packaging: engine dependencies in core, adapters in companions](#packaging-core-and-companions)
- [British spelling in the public API](#spelling)
- [SDK floor](#sdk-floor)
- [Date: a calendar date, not an instant](#date-value-type)
- [Weekday: an enum, where Month is an extension type](#weekday-enum)
- [Uuid: a typed identifier, not a generator](#uuid-value-type)
- [Isni: one type, because Orcid would over-promise](#isni-value-type)
- [Isbn: two generations, one value, no hyphens](#isbn-value-type)
- [Issn: the one type that keeps its hyphen](#issn-value-type)
- [Isin: a prefix that need not be a country](#isin-value-type)
- [Bic: no checksum, so the standard is the whole check](#bic-value-type)
- [PaymentCardNumber: a class so it can mask, and a scheme it only reports](#payment-card-number-value-type)
- [Gtin: four lengths, one number, padded to fourteen](#gtin-value-type)
- [Imei: printed in full, unlike a card number](#imei-value-type)
- [GeoCoordinate: a bounded pair, not two doubles](#geo-coordinate-value-type)
- [MacAddress: two widths, four notations, and no registry](#mac-address-value-type)
- [Hostname: strict on purpose, in three directions](#hostname-value-type)
- [IpAddress: a wrapped engine, but not a wrapped grammar](#ip-address-value-type)
- [Cidr: a block that masks, not a string that starts with](#cidr-value-type)
- [Constraint types: a range, not a standard](#constraint-types)
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

<a id="ci-sdk-toolchain"></a>
## The format gate runs Flutter's Dart, everything else runs Dart stable

**Split along style versus correctness.** `dart format` is the only check whose output must agree
with the maintainer's machine character for character, so that job takes its Dart from Flutter, the
channel [`.fvmrc`](../.fvmrc) names. Analyze, test, the dependency validator and the example stay on
Dart stable through the [`setup-dart` composite](../.github/actions/setup-dart/action.yml).

**What forced it:** Dart stable runs ahead of Flutter's bundled Dart, and the formatter changed
between them. `sdk: stable` gave CI 3.13.0 against a local 3.12.2, so a green tree met a red gate
that reformatted fifteen files the pull request had never touched. The decisive property is that a
format failure must be *reproducible*: whatever CI rejects, `dart format .` locally has to be able to
fix, which neither Dart stable nor a pinned literal promises once it drifts from the machine the code
is written on.

**Elsewhere the newer SDK is the point.** `pubspec.yaml` admits `^3.12.0`, so a downstream Dart-only
user is on 3.13 today and those jobs test what they actually run. The known cost is that the analyzer
is version-sensitive too, so a Dart-stable-only diagnostic would be fixed slightly blind; explicit
rules in [`analysis_options.yaml`](../analysis_options.yaml) stop new lints switching themselves on,
and if it ever stops being tolerable the format job's recipe moves into the composite.

**Installing Flutter contradicts [the section above](#pure-dart-not-flutter) only in appearance:**
that rule governs the package's dependencies, this is the toolchain. Nothing under `lib/` imports
Flutter, and the published package stays usable from a plain Dart SDK.

**When the gate goes red, check which Dart CI is carrying.** Both sides name the `stable` channel,
but a local FVM install is frozen until the next `fvm install` while CI resolves stable at run time,
so the two can still drift. Flutter's release metadata gives the mapping:

```bash
curl -s https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json \
  | jq -r '.current_release.stable as $h | .releases[] | select(.hash == $h) | .dart_sdk_version'
```

Compare that against `dart --version`; `fvm install stable` closes any gap. Pinning that literal on
both sides would close it too, at the cost of a coordinated bump every release, and pinning CI alone
would be worse than the channel, since local would still float.

---

<a id="parse-dont-validate"></a>
## Parse, don't validate

The organizing principle, after Alexis King's essay of the same name. A function that *validates*
takes a `String`, checks it, and hands the same `String` back; every later consumer has to trust
that the check happened and re-check if unsure. A function that *parses* takes a `String` and
returns a **different type** that can only exist if the input was well-formed. The validity
becomes a fact of the type system, checked once, carried everywhere.

That is what `Uri` does for URLs and `int.parse` does for integers, and it is what every `minted`
type does for its domain. The mechanics that enforce it:

- The primary constructor is **private** (`._`). No caller can build an instance directly.
- The only ways in are `parse` (returns a [`ParseOutcome`](#parse-outcome)), `tryParse` (returns
  `T?`), and the assembly factories (which throw). All run the same full check.
- Therefore, an instance of `Iban` is a proof that the string passed mod-97; a `PaymentCardNumber`
  is a proof that it passed Luhn. Downstream code stops re-checking and stops carrying "is this
  string actually valid?" as an open question.

This is the direct antidote to primitive obsession: `String email, String phone, String card`
are three interchangeable, mixed-up-able parameters; `Email`, `PhoneNumber`, `PaymentCardNumber`
are not.

---

<a id="extension-type-representation"></a>
## Extension type vs immutable class

*Which* shape each value takes, and the mechanics you must design around, are specified in
[CODESTYLE](./CODESTYLE.md#value-type-contract). This is only why the split exists.

**A single primitive gets an extension type because the delegation is free and correct.** At runtime
the instance *is* the `String`, so there is no allocation and no indirection, and `==` / `hashCode`
/ `toString` all delegate to the representation. For a `String`-backed value type that delegation
is exactly the wanted behaviour: two `Email`s that normalise to the same string are equal and hash
equal for nothing, and `print(email)` shows the email. The cost is that type safety is compile-time
only, so `'nope' as Email` is a no-op cast that succeeds. That is unfixable from inside the package
(a lint is proposed in [dart-lang/sdk#59310](https://github.com/dart-lang/sdk/issues/59310)), so the
README documents it as a usage rule instead. Since primitive obsession bites at compile time anyway,
the trade is worth taking.

**A class is for when that delegation would be wrong, or there is nothing to delegate to.**
Genuinely multi-field values ([`Date`](#date-value-type)) have no single representation to wrap.
Single-valued ones still take a class when an inherited `Object` member misbehaves:
[`Digits`](#typed-digit-subparts) needs structural `==` that `Uint8List` will not give, and
[`PaymentCardNumber`](#payment-card-number-value-type) needs a `toString` that does not print the
card. Same test, different member. No `Equatable` dependency either way: handwritten equality is a
few honest lines and the core stays dependency-light.

---

<a id="compose-from-modelled-parts"></a>
## Compose from modelled parts, don't re-derive them

**The shape question is which parts exist as types, not how many primitives the value spells.** An
earlier version of the rule in `CODESTYLE.md` said a value spelled by one `String` takes an extension
type and a value with several parts takes a class. That reads the wrong signal. `10.0.0.0/8` is one
string, so the old rule made `Cidr` an extension type that would slice an address back out of its own
text on every call. The part it is slicing out is an [`IpAddress`](#ip-address-value-type), a type
this package already has, with a canonical form and a parse gate of its own. Holding one is both
safer and cheaper than re-deriving it.

**Safer, because an invariant held by a part cannot be re-broken by the whole.** A `Cidr` holding an
`IpAddress` cannot have a malformed network address, whatever anyone does to it later, and its
`contains` cannot be handed something that merely looks like an address. A `Cidr` holding a `String`
re-establishes that fact on every accessor, and each re-establishment is a place to get it wrong.
This is the package's own thesis applied inward: the argument for handing consumers a parsed type
rather than a `String` does not stop at the API boundary.

**`Digits` had the pattern first.** It is an `Iterable<Digit>` rather than an extension type over its
characters, so indexing one yields a `Digit` rather than a character a caller must re-check. That was
recorded as a carve-out about `==` and `Uint8List`, which undersold it: the reason it is right is the
composition, and the `==` argument is a second, unrelated reason to reach for a class.

**The cost is real and worth paying.** A class hand-writes `==`, `hashCode` and `toString`, and gives
up the zero-cost representation. Extension types stay right for values with no inner structure worth
naming: an [`IpAddress`](#ip-address-value-type)'s octets are bytes rather than a modelled type, and
a [`Hostname`](#hostname-value-type)'s labels are plain strings, so both stay extension types until
something like a `DnsLabel` exists to hold.

**Types that predate the rule are queued for v2, not fixed piecemeal.** `Isbn`, `Gtin`, `Imei`,
`Issn` and `Isni` slice digits out of a `String` where `Digits` exists; `Email.domain` returns a
`String` that is a `Hostname`. Each correction is breaking, so they land together with the rest of
the v2 signature work rather than one at a time.

---

<a id="typed-digit-subparts"></a>
## Typed digits: `Digit` and `Digits`

The parse-don't-validate guarantee normally stops at the whole value (`Iban`, `PhoneNumber`).
Where a validated whole exposes a part that is *only* decimal digits, that part is typed as digits
rather than a raw `String`, so "these are digits" is a fact of the type instead of an assumption
each caller re-checks. Neither `Digit` nor `Digits` is a domain entity from a standard; they are
the building blocks the standard types are cut from.

**They travel inbound too, not only outbound.** For a while these types were returned by getters but
never accepted by a parameter, so every assembly factory took `String` for parts it knew were digits.
That was the package declining to eat its own cooking, and it had a concrete cost: the charset failure
stayed reachable through a door whose caller was already asserting validity. So a digits-only part of
an assembly factory is a `Digits` (`Isbn.fromComponents`, `PaymentCardNumber.fromComponents`,
`Gtin.fromBody`, `Imei.fromComponents`, `Issn.fromBody`), and the corresponding
`*InvalidCharacters` variant becomes unreachable from that door while staying live for `parse`. Parts
that are genuinely alphanumeric keep `String`: an IBAN's `bban` and a BIC's institution code are
`[A-Z0-9]`, so `Digits` there would be a narrower type, not a stronger one, and there is no
alphanumeric sibling to reach for yet.

**`getOrThrow` is what makes that spelling bearable, and it belongs on the outcome.** Building a
`Digits` from a literal to hand to a factory used to mean `Digits.tryParse('978')!`, which throws
away the `DigitsFailure` the parse just produced and leaves a bare null-check error in its place.
The first fix attempted was a per-type `Digits.fromString`, and it was wrong: the
[door table](#parse-outcome) has four kinds, and a throwing factory whose parameter is a single
`String` that *is* the whole value is none of them, it is `parse`'s own signature wearing a throw.
So the door moved onto `ParseOutcome` instead, where one method serves every type and nothing grows
a fifth kind. It carries the failure but not the text that produced it, so
`MintedFormatException.source` is null there; the typed reason and the rendered message are what
matter for a bug in the caller's own source.

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

The **assembly factories** (`fromComponents`, `from`, `fromBytes`, `Date(y, m, d)`) throw
`MintedFormatException`, which **extends** `dart:core`'s `FormatException`. `parse` does not throw;
it returns a [`ParseOutcome`](#parse-outcome). Two goals at once:

- **Stdlib-consistent.** The package sells itself as "like `Uri`", and `int.parse` / `Uri.parse`
  / `DateTime.parse` all throw `FormatException`. Anyone already writing `on FormatException`
  catches ours too. It carries the offending `source` and an optional `offset`, same as the base.
- **Discriminable.** Extending (rather than throwing the base type) lets a caller write
  `on MintedFormatException` to catch specifically this package's parse failures, and lets us
  attach a consistent, informative message (`'Invalid Iban: failed mod-97 check'`) via a shared
  `MintedFormatException.from(failure, source)` factory, which renders the message from the typed
  `MintedFailure` it carries. That failure's `typeName` is an explicit string, not a `<T>`, because
  the value types are extension types that erase to their representation at runtime, so a `'$T'` in
  the message would render `String`, not `Iban`.

A failed assembly is still a runtime condition, so it is a `throw`, never an `assert` (see
[CODESTYLE class structure](./CODESTYLE.md#class-structure)): `assert` is stripped in release, and
these guard the type's core guarantee.

---

<a id="claim-in-source"></a>
## A throw is for a claim you made in source

The line between the two doors is **who is responsible for the failure**, not what the parameter
type is.

`parse` takes text you did not control: a form field, a CSV cell, a JSON payload. Invalid input is
an expected outcome there, and the caller *must* handle it, so it belongs in the return type where
the compiler can insist. That is `ParseOutcome`.

The assembly factories take parts the caller already believes in. Writing `Date(2026, 7, 7)` or
`Iban.fromComponents(countryCode: 'GB', bban: …)` is a claim, made in source, that those parts are
good. A violated claim is a bug in the calling code, not a condition to branch on, and there is no
remedy to write at the call site. Forcing an outcome there would make every caller write an arm
they cannot act on, and they would write `case _ => null` next to the arm that mattered.

This is the line every comparable system draws: Rust separates `Result` from `panic!`, Haskell
separates `Either` from `error`, and ribs ships `Either.catching` for crossing it deliberately.

---

<a id="parse-outcome"></a>
## Why a bespoke `ParseOutcome`, not `Either`

`ParseOutcome<F extends MintedFailure, T>` is a sealed two-arm type in core, with no new dependency.
It is deliberately `Either`-shaped so FP-style code reads natively, but named for the domain rather
than `Left` / `Right`, because the package is general-purpose.

**The door table**, which governs what any new member returns. One rule decides every row: *a throw
is for a claim you made in source; the outcome is for data you did not control.*

| Door | Example | Returns |
|------|---------|---------|
| Parse text | `Iban.parse(String)` | `ParseOutcome<F, T>` |
| Parse text, cheaply | `Iban.tryParse(String)` | `T?` |
| Assemble from parts you assert are valid | `Date(2026, 7, 7)`, `Isbn.fromComponents`, `Digits.from`, `Uuid.fromBytes` | `T`, throws `MintedFormatException` |
| Range-check a primitive | `Digit.tryFrom(int)`, `Digits.tryFrom(List<int>)` | `T?` |
| Assert against an outcome you already hold | `Digits.parse('978').getOrThrow()` | `T`, throws `MintedFormatException` |

The last row is the one that arrived late, and its absence caused a real mistake: with no way to
assert against an outcome, a type that wanted one grew its own throwing `String` door instead, which
is just `parse`'s signature with a throw bolted on. `getOrThrow` lives on the sealed base, so the
table stays five rows however many value types land.

**Why not depend on an FP library.** `ribs_core`'s `Either` was considered and rejected because the
dependency would be **viral in the public API**: unlike `iban_validator` it appears in every
signature, so every consumer would have to add and import it, re-pitching a general package as an
FP-only one and leaving anyone already on `fpdart` with two incompatible `Either`s. That is exactly
the *engine* versus *adapter* line in [hard rule 7](./.ai/AGENTS.md#hard-rules).

**FP interop is three lines in the consumer's own app**, not a companion package:

```dart
extension RibsOutcome<F extends MintedFailure, T> on ParseOutcome<F, T> {
  Either<F, T>       get either    => fold(Either.left, Either.right);
  ValidatedNel<F, T> get validated => fold(Validated.invalidNel, Validated.validNel);
}
```

**Why no third state.** Folding the assembly-factory failure in as a third variant, so nothing ever
throws, crosses the [claim-in-source](#claim-in-source) line, loses the stack trace exactly where it
is the only useful diagnostic, and is viral upward: every function building a `Date` would return the
three-state type. Java's checked exceptions, same failure mode.

**Why the constructors are public.** `ParseOutcome` protects no invariant, since building a
`ParseSuccess(iban)` requires already holding an `Iban`, which only parsing produces. The sealed base
and `final` arms still stop anyone adding a third state, and public `const` constructors buy consumer
test fixtures for nothing.

---

<a id="per-type-failures"></a>
## Failures are per type, because standards are

Every value type declares its own failure vocabulary implementing `MintedFailure`, rather than the
package sharing one enum, and the deciding factor is **uniformity across the family**.

One shared vocabulary would have to pick a single granularity, and neither setting fits both ends:
coarse enough for `Digit` and `Iban`'s distinct failures collapse into "invalid"; rich enough for
`Iban` and `Digit` carries variants it can never produce, leaving consumer `switch`es mostly
unreachable arms. The variation is a property of the standards themselves:

> A standard that is a single grammar has one failure mode. A standard that is a checksum plus a
> registry has several, because it has independent things to fail against.

So uniformity lives in the *shape* of the API (every type has a failure type, every parse failure
produces one, every one is a `MintedFailure`) and not in the *content*, which is how the package
handles family-level variation everywhere else: `Iban.checkDigits`, `Email.mailtoUri` and `Uuid.bytes`
have nothing in common either.

**A variant earns its place by changing what the user does next.** "Checksum failed" means *you
mistyped, look again*; "unknown country" means *we do not support this, stop*; "too short" means *keep
typing*. Three remedies, three variants. "Bad character at index 7" versus "at index 9" is one remedy,
so one variant.

**The engine sets the ceiling, and we do not guess past it.** `email_validator` exposes a single
`bool`, so `Email` gets exactly one variant; a heuristic guess at "invalid domain" would be a
fabricated diagnosis wearing a type name, and honestly silent beats confidently wrong. `PhoneNumber`
is nearly the same story, since only one of `phone_numbers_parser`'s five codes is ever thrown.
`Iban` is the opposite extreme, handed a five-way diagnosis for free.

**Sealed or enum, decided by when the payload is known.** Enum where every variant's data is a
declaration-time constant or absent; sealed where any variant carries something derived from the input
(`IbanInvalidLength(expected, actual)`, `DateDayOutOfRange`'s leap-aware bound). The second prong is
about *timing*, not shape: an enhanced enum's payload is fixed at declaration.

**Why `tryParse` still returns `T?`.** Replacing it with the outcome would kill `??`, `?.`,
`whereType<Iban>()` and collection-`if` for every caller who only ever wanted the null, and deriving
one door from the other costs nothing.

---

<a id="normalise-on-parse"></a>
## Normalize on parse

`tryParse` reduces input to one canonical form before it constructs the instance: trim
whitespace, strip the separators the standard treats as cosmetic (spaces in an IBAN, dashes in a
card number), and case-fold the parts the standard says are case-insensitive (an IBAN is
upper-case; an email's domain is lower-case, its local-part left as-is).

This is not cosmetic. Extension-type equality is representation equality, so the stored canonical
form *is* the equality key. Normalizing on the way in is what makes
`Iban.parse('gb82 west 1234') == Iban.parse('GB82WEST1234')` hold, and what makes these types
safe to use in a `Set` or as a `Map` key. Each type documents its exact normalization in dartdoc
so the canonicalization is never a surprise. Render helpers (`Iban.formatted`, the grouped paper
form) reconstruct a display form from the canonical one on demand; they do not change what is
stored.

---

<a id="check-digits-not-regex"></a>
## Check the real standard, not a regex shape

Where a standard defines a checksum, `minted` computes it: mod-97 for `Iban`, Luhn for
`PaymentCardNumber` and `Imei`, GS1 mod-10 for `Gtin` and ISBN-13, mod-11 for ISBN-10. A regex that
matches the *shape* (right length, right character classes) accepts an enormous number of strings
the standard rejects, and shipping that would defeat the entire "an instance is a proof of validity"
premise. These check-digit types are the highest-value members of the package precisely because
the standard hands us a real correctness test, not just a format.

Tests for these types use the **official standard test vectors** (the IBAN registry examples, the
Luhn worked examples, published ISBN/GTIN/IMEI check-digit cases), plus deliberately corrupted
variants (one transposed digit, one wrong check digit) that must be rejected.

<a id="check-digit-blind-spots"></a>
**What the mod-10 family cannot catch**, stated once because three types inherit it. Luhn misses a
`09`/`90` transposition and the twin errors 22/55, 33/66, and 44/77; GS1 mod-10 misses a
transposition of two adjacent digits differing by five. Both members of each pair carry the same
weighted sum, so the check digit is identical either way. Only mod-11 (ISBN-10) catches every
transposition. These are properties of the standards, not of these implementations, and each
affected type pins its own case in a test so it does not read as a bug later.

---

<a id="registry-data-ships-a-clock"></a>
## Registry data ships a clock

The most repeated decision in this package, hoisted here so the type sections can point at it instead
of re-deriving it. **A validation rule built on registry data is correct on release day and quietly
wrong afterwards**, because the registry moves and a published package does not. That is worse than
under-validating: rejecting a real value, or confidently mis-rendering one, costs the caller more than
saying less would have.

So the rule is uniform. Validate what the *standard* fixes; **report** what a registry merely
observes, and leave the caller to decide what to do with it. Every instance:

| Type                | Registry kept out                              | What is done instead                                                                 |
|---------------------|------------------------------------------------|--------------------------------------------------------------------------------------|
| `Isbn`              | ISBN International's hyphenation range table   | hyphens stripped, derivable parts exposed                                            |
| `Bic`               | current SWIFT practice (letters-only prefixes) | `parse` takes the wider ISO 9362 rule, `isSwiftRegistrable` reports the narrower one |
| `PaymentCardNumber` | the IIN-to-network brand table                 | only uncontested ranges listed, `unknown` means "cannot say"                         |
| `Gtin`              | GS1's company-prefix boundary                  | no company-prefix / item-reference split                                             |
| `Email`             | anything past the engine's single `bool`       | exactly one failure variant, no guessed diagnosis                                    |

Two consequences worth naming. It keeps mutable data out of core entirely, which is why no type here
carries a table it would have to maintain (`Bic` borrows its country list rather than owning one).
And it is not hypothetical: a real digit-prefixed BIC already broke a mature validator in production,
which is the concrete case the rule exists to avoid.

---

<a id="behavioural-tests-helper"></a>
## Behavioural tests: a helper, not a framework

Tests read as behaviour (Given/When/Then, one named case per row), but that framing comes from a
tiny in-repo helper, not a BDD framework. [`test/support/bdd.dart`](./test/support/bdd.dart) is
about 25 lines of `feature` / `scenario` / `scenarioOutline` over `package:test`, with the
assertions still written in `package:checks`.

A real Gherkin runner was evaluated and turned down on the merits, not on availability. An earlier
`bdd_framework` dev-dependency was dropped for pulling in `flutter_test` (which breaks `dart test`
off Flutter), but the pure-Dart `gherkin` package *does* resolve and run Flutter-free here. It was
still rejected, for four reasons independent of any version:

- **No audience for the payoff.** Gherkin earns its keep when non-technical stakeholders read and
  write `.feature` files. This package's consumers are Dart developers, and the specification is
  already the published standard plus the dartdoc plus the structural
  [`conformance_test.dart`](./test/conformance_test.dart).
- **Ceremony over pure functions.** A value type is a single-call, stateless parse. `World` context
  and multistep flows mean inventing a stateful world to carry one input across three steps.
- **It degrades `dart test`.** A whole feature reports as one opaque test, so scenario counting,
  `-n` filtering, and per-case failure attribution all stop working.
- **Frozen.** Last released 2022, resolves under Dart 3 only because pub relaxes the legacy SDK cap,
  and it holds `uuid` below 4.

The helper keeps the readability and drops all four costs, since every example row stays a genuine
`dart test` case. The examples’ table is the point: each row groups its inputs with the expected
outcome under a descriptive name. Where a type normalizes on parse, the canonical form doubles as
that outcome (a string means "accepted and normalized to this", `null` means "rejected"), folding
acceptance, rejection, and normalization into one table. How-to in
[CODESTYLE test style](./CODESTYLE.md#test-style).

---

<a id="public-api-via-single-export-file"></a>
## Public API funnelled through `lib/minted.dart`

The mechanics are [hard rule 2](./.ai/AGENTS.md#hard-rules); the reason is that one barrel makes the
public surface auditable in a single file, and makes any move inside `lib/src/` a non-breaking
change. That is what buys the freedom to regroup types into sector directories, or lift a shared
check-digit algorithm out of one, without a semver event.

---

<a id="packaging-core-and-companions"></a>
## Packaging: engine dependencies in core, adapters in companions

The constraint is that no *opinionated* dependency is forced on a consumer who just wants the value
types. In Dart, dependencies are declared per package, not per library: the moment any file in
`minted` imports a package, that package lands in *every* consumer's resolution and lockfile, even
someone who only touches one type. Tree-shaking drops unused *code* from a release binary, but not
the entry in the dependency graph. So "one package with optional heavy libraries" is not possible;
the decision turns on *what a dependency is for*, not merely whether there is one.

- **Engine dependencies live in the core.** A dependency that a core value type is *built on* may sit
  in core, provided it is pure Dart, web-safe, and free of a heavy transitive closure: `Email`
  wraps `email_validator`, `Iban` wraps `iban_validator`, `PhoneNumber` wraps
  `phone_numbers_parser`. These are the parser or registry the type needs to exist. The guard still
  rejects a heavy or platform-bound engine: a type whose only parser dragged in Flutter or a large
  runtime would go to a companion instead.
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
and the syntax can still change before it stabilizes. Until the feature ships stable (no flag),
the private-representation extension type (`extension type const T._(String _value)`) already
gives the same "private field declared at the constructor" shape with zero experiments; revisit
the [value-type contract](./CODESTYLE.md#value-type-contract) when it stabilizes. Record any floor
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

**An immutable class, not an extension type.** Three fields means the
[multi-part shape](#extension-type-representation), and the zero-cost alternatives do not hold up: an
extension type over `DateTime` cannot override `toString`, so it would print `2026-07-07 00:00:00.000`
and inherit the rollover; one over a packed `int` has an opaque canonical form and needs arithmetic
to read a component back.

**`Month` is a type; `day` and `year` are plain `int`.** A month is one of twelve regardless of
context, so `Month` is a clean building block, and it owns the calendar knowledge that hangs off a
month (`Month.daysIn(year)` is leap-aware, so `Date` delegates rather than carrying a length table).
A *day* is only valid relative to a month and a year, so a standalone `Day(1-31)` would be a shape
check that leaves `Date` doing the real validation, and a type named `Day` that accepts 31 February
overpromises on its name. `year` would be only a thin bounded `int`. This is the
[typing-versus-honesty balance](#typing-versus-honesty) resolved per field.

**A validating factory, not a raw constructor.** `Date(2026, 7, 7)` validates and throws
`MintedFormatException`, backed by a private `Date._`. A plain `const` constructor cannot promise the
guarantee, because its `assert`s are stripped in release builds, so `Date(2026, 13, 40)` would leak
into production. The cost is that `Date(...)` is not `const`; neither is `DateTime(...)`.

**Reject, don't roll over.** Where `DateTime(2026, 13, 1)` silently becomes 2027-01-01, `Date`
rejects it. Rolling an out-of-range part over invents a different value instead of refusing a bad
one, which is the opposite of parse-don't-validate.

**Local `toDateTime()`, UTC arithmetic.** `toDateTime()` returns local midnight, matching what
callers write today. Day arithmetic (`addDays`, `differenceInDays`) works in UTC internally, because
a UTC day is always 24 hours when a daylight-saving transition makes a local one 23 or 25, which
would skew the count.

**`Date.now()` types the clock, it does not read it**, being `Date.fromDateTime(DateTime.now())`:
the same division of labour as [`Uuid`](#uuid-value-type). Local, matching its sibling; for the UTC
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
[value-type contract](./CODESTYLE.md#value-type-contract), derived classifications are a plain enum.

**An enum, because seven days is a set that can be named honestly**, which is the same test
[`Uuid.version` fails and `UuidVariant` passes](#uuid-value-type). The payoff is exhaustiveness: a
`switch` over a `Weekday` needs no default arm and the compiler catches the day you forgot, which is
most of what weekday code does. An extension type over `int` cannot offer that at any price, since
only sealed types and enums drive exhaustiveness. The cost is an `index` sitting one apart from
`value`, so the dartdoc names `value` as the ISO number and points away from `index`.

**Ordering is a convention, and the type says so.** `compareTo` and the comparison operators run over
the ISO number, so Monday sorts first, but that is a choice rather than arithmetic: weeks begin on
Sunday in the US, Canada, and Japan and on Saturday across much of the Middle East. A weekday is a
*cycle*, and ordering a cycle means picking an origin, where [`Date`](#date-value-type) earns its
operators outright because dates are totally ordered. So the comparisons document the origin they
assume, and the origin-free arithmetic (`next`, `plusDays`, `daysUntil`, all modular and total) is the
safer default. Same reason there is no `isWeekend`: ISO 8601 numbers the days and says nothing about
which are a weekend, so a bare answer would be an opinion wearing a standard's name.

**Failure vocabulary for a type that never parses.** `WeekdayFailure` exists for one use,
`Weekday.from` throwing outside `1`-`7`, and never reaches a `ParseOutcome`. It stays anyway,
because `MintedFormatException` needs a `MintedFailure` carrying `typeName: 'Weekday'`, and the
alternative is a shared parameterized failure: a new public shape that would turn later per-type
growth into a breaking signature change ([failures are per type](#per-type-failures)).

---

<a id="uuid-value-type"></a>
## Uuid: a typed identifier, not a generator

A UUID is the textbook `String`-that-should-not-be-a-`String`: 36 characters a caller passes around,
compares, and stores, trusting that whoever produced it wrote a well-formed one. `Uuid` makes
well-formedness a fact of the type, the same bargain [`Email`](#parse-dont-validate) and `Iban`
strike.

**It types, it does not generate.** The `uuid` package already mints v1/v4/v7/… UUIDs and does it
well, but it hands back a `String`, so the primitive obsession is untouched the moment the value
leaves the generator. So `uuid` generates, `Uuid` types the result, which also keeps core
dependency-free here (validation is a regex plus two nibble reads). Same shape as
[`Date`](#date-value-type) filling the date-only gap: minted adds the missing *value* rather than
re-implementing the neighbouring tool. (Both are named `Uuid`; a consumer using both imports one with
a prefix.)

**An extension type over `String`**, normalised on parse (lower-case hex, strip a `urn:uuid:` prefix
or surrounding `{…}`, trim) so that `Uuid.parse('URN:UUID:F81D…') == Uuid.parse('f81d…')`
([normalise on parse](#normalise-on-parse)).

**Accept every well-formed UUID; classify, don't reject.**
[Hard rule 3](./.ai/AGENTS.md#hard-rules) wants the real standard rather than a regex shape, but a
UUID carries no checksum, and RFC 9562 treats its version and variant fields as *classification*
rather than a validity gate: the Nil and Max UUIDs are valid with nibbles in "reserved" buckets, and
versions `0` and `9`-`15` are reserved-but-legal. Rejecting on either would refuse values the standard
itself calls valid. So `Uuid` validates the grammar and exposes `version`, `variant`, `isNil` and
`isMax` as read-back accessors. Validating the real standard here *means* parsing those fields
correctly, not inventing a stricter rule the RFC does not have.

<a id="typing-versus-honesty"></a>
**`version` is an `int`; `variant` is an enum**, and the split is the balance this package keeps
returning to: stronger typing against honest representation. The variant is a genuine finite
classification (NCS, RFC 9562, Microsoft, future-reserved), so an enum names its whole domain. The
version is a raw 4-bit field where an enum would either omit the reserved range (and so fail to
represent a valid UUID) or carry a catch-all member that lies about being one value, so an `int` is
the honest type. Resolved per field, on the merits, never as a reflex toward the strongest type.

---

<a id="isni-value-type"></a>
## Isni: one type, because Orcid would over-promise

**There is no `Orcid`, and that is the decision.** ORCID issues iDs from a block inside the ISNI
range, so every ORCID iD *is* an ISNI. Two types need something to tell them apart and the only
candidate is that block: gating on it makes `Isni` refuse most of its own standard, and not gating
makes `Orcid.parse` accept Isaac Newton's ISNI `0000000121032683`. The second is the
[`Day` test](#date-value-type), a type named for what it does not guarantee. So one type holds the
standard and `isInOrcidBlock` reports the narrower fact.

The block is genuinely registry-shaped here, unlike [`Isbn`'s prefix](#isbn-value-type): ORCID has
said publicly that it will grow, where ISO 2108's `978`/`979` is fixed. Reporting rather than gating
is [the usual answer](#registry-data-ships-a-clock).

**Its check is not the mod-11 the package already had.** ISO 7064 MOD 11-2 doubles a running total,
so its weights are powers of two mod 11 where `mod11_check_character.dart` descends linearly. They
share a modulus and an `X` glyph and agree on nothing: the weighted one rejected all five ORCID iDs
tested against it. Hence a separate file, and a test pinning that the two cannot be swapped, because
that resemblance is exactly what invites a "simplification".

**The block test compares text, not integers.** Sixteen digits reach 10^16, past the web's safe
integer range of 2^53-1, so `int.parse` would lose precision on a real ISNI. Equal-length
zero-padded strings order the same way the numbers do, so `compareTo` is both correct and web-safe.

---

<a id="isbn-value-type"></a>
## Isbn: two generations, one value, no hyphens

ISO 2108 has had two shapes: ten characters with a mod-11 check digit (ten spelled `X`), and, since
2007, thirteen digits with the GS1 mod-10 check. Every 978-prefixed ISBN-13 has exactly one ISBN-10
twin, so the same book arrives written both ways.

**Everything folds to thirteen digits.** Extension-type equality is representation equality, so the
stored form *is* the equality key ([normalise on parse](#normalise-on-parse)). Keeping whichever
spelling arrived would make `0-306-40615-2` and `978-0-306-40615-7` unequal and put one book in a
`Set` twice. Nothing is lost, since the mapping is a bijection: `isbn10` rebuilds the legacy form,
`null` for the 979 range that never had one. The check digit is recomputed rather than carried
across, because the two generations use different algorithms.

**979-0 is refused.** `977` is an ISSN and `9790` an ISMN (ISO 10957, printed music): real
identifiers that are also well-formed GS1 article numbers, so a shape-only check would take them
for books. `IsbnInvalidPrefix` names ISMN specifically, because "this is sheet music" is a remedy,
while staying one variant, *not an ISBN*.

**No hyphenation, which is the load-bearing decision.** The groups in `978-0-306-40615-7` are not
in the digits; they come from ISBN International's range table, so embedding a snapshot
[ships a clock](#registry-data-ships-a-clock), and a confidently mis-hyphenated ISBN is worse than a
plain one. So `Isbn` strips hyphens and exposes the parts that *are* derivable. `Iban.formatted` is
no precedent: grouping by four needs no table. The `isbn` package on pub carries no range data
either, so it would buy only the two check-digit algorithms, which is the case
[hard rule 7](./.ai/AGENTS.md#hard-rules) sends to `lib/src/shared/` rather than a micro-dependency.

**Its blind spot is mod-10's**, so `9780306401657` passes as readily as `9780306406157`; mod-11 over
the ten-digit form catches every transposition. See
[check-digit blind spots](#check-digit-blind-spots).

---

<a id="issn-value-type"></a>
## Issn: the one type that keeps its hyphen

**The hyphen is in `value`, where [`Isbn`](#isbn-value-type) strips its own.** That looks
inconsistent and is not, because the two hyphens are different things. An ISBN's groups come from
ISBN International's range table, so rendering them [ships a clock](#registry-data-ships-a-clock); an
ISSN's single hyphen sits after the fourth character always, fixed by ISO 3297 and derivable from
nothing but the length. So there is no data to go stale, the standard's own written form is
`NNNN-NNNC`, and storing anything else would mean `print(issn)` showing a form that appears on no
masthead, in no citation and in no catalogue. `compact` drops it for a URL or a database key, the
same reconstruct-on-demand relationship [`Iban.formatted`](#normalise-on-parse) has, just pointing
the other way.

**`checkCharacter` is a `String`, not a `Digit`.** ISO 3297 spells the value ten as `X`, so the field
is not always a digit and the honest type is the wider one. `Isbn.checkDigit` and `Gtin.checkDigit`
*are* `Digit`s, because an ISBN-13 and a GTIN both end in a real digit. The
[typing-versus-honesty balance](#typing-versus-honesty) again, resolved per field.

**Mod-11 has no transposition blind spot**, which makes this the one check-digit type in the package
without a [caveat to pin](#check-digit-blind-spots). The tests pin the opposite: three real ISSNs with
an adjacent pair differing by five, transposed, all rejected. Those are exactly the swaps the mod-10
family cannot see, so a future "simplification" to mod-10 would turn them green.

**ISSN-L and the 977 barcode are out of scope.** The linking ISSN that ties a title's print and online
numbers together is an assignment held in the ISSN Register, not a computation, and the `977` EAN-13
that carries an ISSN on a magazine adds two variant digits that are likewise not derivable. Both are
registry lookups wearing a checksum's clothing.

---

<a id="isin-value-type"></a>
## Isin: a prefix that need not be a country

**Luhn, but over an expansion, which changes the weighting.** ISO 6166 replaces every letter with
the two digits of its value (`A`=10 ... `Z`=35) and runs Luhn over the result, so `AU0000XVGZA3`
weighs eighteen characters rather than the twelve it shows. That is why `luhnCheckDigit` had to be
length-agnostic before this type could reuse it, and why the `A`=10 mapping moved out of
`iban_check_digits.dart` into `shared/`: ISO 13616 folds those values into mod-97 and ISO 6166
spells them out, but the mapping is one convention shared by two standards.

**The prefix is two letters, not a country.** `XS` is Euroclear and Clearstream, `EU` is
supranational, and both are as valid as `GB`. Gating `parse` on ISO 3166 would
[ship a clock](#registry-data-ships-a-clock) against the set of non-country prefixes, so `parse`
enforces what the standard actually fixes (two letters) and `hasCountryPrefix` *reports* the
narrower fact. Exactly the [`Bic`](#bic-value-type) split between the standard and the registry.

**Its parts stay `String`.** An NSIN is `[A-Z0-9]`, so the
[digits-only rule](#typed-digit-subparts) does not apply and `Digits` there would be a narrower type
rather than a stronger one. Same reason `Iban.fromComponents` keeps its `bban` a `String`.

---

<a id="bic-value-type"></a>
## Bic: no checksum, so the standard is the whole check

ISO 9362 defines no check digit. Every other standardised type here leans on one
([check digits, not regex](#check-digits-not-regex)); `Bic` has nothing to lean on, so what is left
is the shape plus one real lookup: positions 5-6 must be an ISO 3166-1 country. `Bic.parse` will
therefore accept a well-formed code no institution holds, the same honesty [`Uuid`](#uuid-value-type)
states about its own lack of a checksum. Naming the gap beats pretending to close it.

**The standard is wider than the registry, so the wider rule wins.** ISO 9362:2014 redefined the
first four characters as alphanumeric, and ISO 20022 retired its letters-only `AnyBICIdentifier`
pattern to follow. SWIFT, as registration authority, still issues letters only. Validating against
current practice would [ship a clock](#registry-data-ships-a-clock), so `parse` enforces the standard
and `isSwiftRegistrable` *reports* the narrower shape, which is a fact about the code rather than
grounds to refuse it.

**Eight characters folds to eleven.** A branch code of `XXX` means the primary office, which is
exactly what an eight-character BIC addresses, so the two spellings denote one party and must fold to
compare equal ([normalise on parse](#normalise-on-parse)). Folding up rather than down also fixes the
length at eleven, so `branchCode` is never null and `bic8` rebuilds the short form.

**The country list is borrowed, not carried.** `phone_numbers_parser` is already a dependency and
its `IsoCode` has 245 entries, including the `XK` SWIFT uses for Kosovo; it omits only seven
uninhabited territories with no banks. `iban_validator`'s list covers IBAN countries alone and would
reject `CHASUS33`. Borrowing keeps core free of a country table it would have to maintain, at the
cost of a finance type tracking a phone engine's data, which the README states.

**The location code is documented, not modelled.** By SWIFT convention its second character reads
`0` for a test code, `1` for a passive participant, `2` for reverse billing. ISO 9362 assigns none of
those, so an enum naming them would overclaim, and its default case worst of all. Same reasoning as
[`Uuid.version`](#uuid-value-type) staying an `int`.

---

<a id="payment-card-number-value-type"></a>
## PaymentCardNumber: a class so it can mask, and a scheme it only reports

**A class, because `toString` must not print the number.** An extension type cannot redeclare it
([extension type vs immutable class](#extension-type-representation)), so `'$card'`, a test failure
and a crash-reporter breadcrumb would each carry the whole PAN. So this one is an `@immutable` class
rendering `PaymentCardNumber(••••1111)`, with `value` the single member that hands the number back.
Defence in depth rather than a guarantee, since `value` is one interpolation away and Dart strings
cannot be wiped, but it moves the leak off the default path.

**The scheme is reported, never validated.** ISO/IEC 7812 assigns no brand ranges at all, and the
IIN-to-network table is registry data whose ranges overlap: `65` is claimed by Discover and RuPay,
`55` by Mastercard and Diners US/Canada, `60` by RuPay against Discover's `6011`. Gating `parse` on
it would [ship a clock](#registry-data-ships-a-clock), so the table carries only ranges no other
known network contests, and a contested one is left out rather than guessed at: `unknown` means
"cannot say", not "not a card".

Two getters, because one resolution does not fit. `cardScheme` answers the common case;
`cardSchemes` answers the co-brands a single value cannot express, `622126`-`622925` being a
UnionPay that Discover also accepts. `cardScheme` is `cardSchemes.singleOrNull ?? unknown`, so the
two cannot drift and there is one table. `cardSchemesOf` is static because a half-typed number has
no check digit yet and so cannot parse, while a checkout form still wants the brand at the fourth
keystroke.

**Eight digits is the floor, though nothing is issued that short.** ISO/IEC 7812 allows 8 to 19; the
shortest real PAN is a 12-digit Maestro. Enforcing the standard over current practice is the
[same rule](#registry-data-ships-a-clock) again, and Luhn already rejects most of what the wider
window admits.

**Luhn's blind spots apply**; see [check-digit blind spots](#check-digit-blind-spots).

---

<a id="gtin-value-type"></a>
## Gtin: four lengths, one number, padded to fourteen

**Every length folds to GTIN-14, and the padding cannot lie.** GS1's own guidance is to store a
GTIN of any length zero-padded to fourteen digits in one field, and that is exactly what `value`
holds, so a UPC-A and its EAN-13 spelling are one value ([normalise on parse](#normalise-on-parse)).
The fold is lossless because GS1 weights from the *right*: the added zeros carry no weight and shift
nobody else's, so the check digit that validated the short form still validates the padded one. That
property is also why the mod-10 had to be lifted out of the ISBN file first, since the old
implementation weighted from the left and so agreed with GS1 only at exactly twelve digits.

**Three getters and a `shortestForm`, because one answer does not fit.** `value` is the storage
form. `shortestForm` is the barcode form, what actually gets printed. The per-length `gtin13`,
`gtin12` and `gtin8` exist because a caller talking to a retail or logistics system needs a
*specific* length, not the shortest one: UPC-A and EAN-13 are not interchangeable at that boundary.
Each is `null` when dropping the leading digits would lose a significant one, so the nullability
answers "does this number fit that length" rather than hiding a truncation.

**No company-prefix / item-reference split.** That boundary comes from GS1's prefix registry rather
than the digits, so it [ships a clock](#registry-data-ships-a-clock). A `Gtin` reports its check
digit and nothing else structural.

**An ISBN-13 parses as a `Gtin`, deliberately.** It is a GTIN-13 in the Bookland prefix range, so
refusing it would be wrong. [`Isbn`](#isbn-value-type) is the narrower type: it additionally pins
the prefix to `978`/`979`, carves out the ISMN range, and rebuilds the ten-digit form. Parse as
whichever one you mean. Both inherit
[mod-10's blind spot](#check-digit-blind-spots).

---

<a id="imei-value-type"></a>
## Imei: printed in full, unlike a card number

**It does not mask, and that is the interesting decision.** An IMEI is personal data under GDPR (a
persistent hardware identifier), so the [`PaymentCardNumber`](#payment-card-number-value-type)
argument for a masking `toString` looks like it should apply. It does not, because the two differ in
what leaking costs. A PAN is an authentication credential: possession of the number is most of what
it takes to spend the money, so a log line is a breach. An IMEI authenticates nothing. It is printed
on the box, sits in the settings screen, and the systems that hold one (device inventory, MDM,
repair intake, insurance claims) exist to display it. A type that redacted by default would fight
its only callers, and they would reach for `value` on every line and gain nothing. So this stays an
`extension type`, free at runtime, and privacy stays where it belongs: in what the caller logs.

**The TAC is eight digits with no Final Assembly Code beside it.** Pre-2004 IMEIs were TAC (6) +
FAC (2) + serial (6); the 2004 revision folded the FAC into the TAC, and every IMEI issued since is
TAC (8) + serial (6). Since the type has no way to know which era a number came from, and the modern
reading is right for anything currently in circulation, `tac` is the eight-digit field and there is
no `fac` getter. `reportingBodyIdentifier` exposes the two leading digits, which is the one
subdivision of the TAC that has not moved.

**Sixteen digits are named as an IMEISV, not called a miscount.** An IMEISV trades the check digit
for a two-digit software version, so a sixteen-digit input is a real identifier for the same
handset, just not this one. That is the [`Isbn`](#isbn-value-type) courtesy to the ISMN range again:
telling the caller what they actually have beats telling them they cannot count. It is a message
branch on `ImeiWrongLength` rather than its own variant, because the remedy is identical.

**Luhn's blind spots come along**, so `352099001761481` and `352909001761481` both pass; see
[check-digit blind spots](#check-digit-blind-spots).

---

<a id="geo-coordinate-value-type"></a>
## GeoCoordinate: a bounded pair, not two doubles

**The bug this type exists for is a transposition, which no range check can catch.** `f(lat, lng)`
and `f(lng, lat)` have the same signature, and both arguments are plausible degrees. So the pair is
named once, at the parse boundary, and `from` / `tryFrom` take **required named** parameters. That
breaks the habit [`Date`](#date-value-type) set with positional `Date(y, m, d)`, deliberately: a
year, a month and a day are not interchangeable at a glance, whereas two degree values are. Half the
transpositions are caught anyway, because a longitude past 90 is not a latitude, which is exactly the
half that would otherwise reach production silently.

**Altitude and a CRS identifier are refused, not modelled and not dropped.** `+27.5916+086.5640+8850CRSWGS_84/`
is valid ISO 6709, and this type rejects it. Modelling altitude buys no invariant: its sign, its
units and its datum are all defined by the CRS, so a `double? altitude` would be a field the type
cannot promise anything about, and validating the CRS needs a registry we do not carry (see
[registry data ships a clock](#registry-data-ships-a-clock)). Accepting the string and discarding
the altitude is worse still, because a parse that silently loses part of its input is not a parse.
Refusing says what is true: this type is a surface coordinate.

**The canonical form is decimal degrees even though the input may be sexagesimal.** ISO 6709 uses
the *width* of the degree field as the unit selector — 2/4/6 digits for latitude, 3/5/7 for
longitude — so one point has three spellings. Folding them to one is the same move
[`Gtin`](#gtin-value-type) makes with its four lengths. The cost is that a coordinate read from
`+501234-0001042/` renders as `+50.20944444444444-000.17833333333333334/`, which is ugly and exact.
The alternative, rounding to a pretty fixed precision, would break the round-trip the canonical form
promises, so the digits stay. Rendering searches for the shortest fixed-point decimal that reads
back as the same `double` rather than using `toString`, which switches to exponential notation below
`1e-6` — and `1e-7` is a legal latitude but not a legal ISO 6709 field.

**Round-tripping needs both ends exact, and for a while neither was.** The renderer spells at most 20
fraction digits, so a degree finer than that had no exact spelling and fell back to a truncated one:
`1e-21` rendered as `+00.00000000000000000000`, which reads back as zero, and a tiny *negative*
degree rendered with the minus sign the negative-zero rule below exists to remove. Parsing had the
opposite defect: it rebuilt a decimal field by adding the fraction to the degrees, which rounds a
second time and lands up to one ulp from converting the whole field at once, so roughly one
coordinate in four hundred did not survive its own canonical form. The two fixes pair up.
`_canonical` snaps every stored degree to one the renderer can spell exactly, which is identity for
anything coarser than `1e-20` and therefore for every coordinate anyone can measure; and a plain
decimal field is now converted in a single `double.parse`. The sexagesimal path keeps its base-60
arithmetic, because those digits genuinely have to be folded, and whatever `double` falls out then
renders and reads back exactly like any other. The snap is also what lets the renderer drop its
"no exact spelling" fallback outright rather than carry an untestable branch.

**Normalising negative zero is a correctness requirement, not a cosmetic one.** This is the first
floating-point value in the package, which makes two IEEE 754 facts load-bearing that no `int`- or
`String`-backed type had to face. `-0.0 == 0.0` is true while the two need not share a hash code, so
an instance holding `-0.0` would break the Set-and-Map-key guarantee
[normalise on parse](#normalise-on-parse) makes. It also happens to be what the standard asks for,
signing the equator and the prime meridian with a plus. `NaN` needs no special case for the same
family of reasons: every comparison with it is false, so a range test written as `>= -bound &&
<= bound` rejects it for free, which is why the check is written positively rather than as
`< -bound || > bound`.

**`-180` folds onto `+180`, and a pole keeps its longitude.** Both are cases where two values name
one place, and they get opposite treatment because only one of them is two spellings of the same
thing. The standard itself says minus denotes "west longitude *or* the 180° meridian", so the
antimeridian has two spellings and one location, and RFC 5870 makes that equality normative for
`geo:` URIs — fold it. At a pole the longitude is *meaningless* rather than redundant, and zeroing it
would discard a number the caller supplied on a guess about what they meant, so it stands.

**Minutes and seconds reaching 60 fail the shape check, not a range check.** The fixed-width scheme
is what makes the grammar unambiguous, and the digit range `00`-`59` is part of that width rather
than a bound on a part, so `+5060+00000/` reports `GeoCoordinateNotIso6709`. This keeps the failure
vocabulary at three variants, one per remedy: fix the format, fix the latitude, fix the longitude.
The same reasoning is why `+46+2/` must be refused rather than read leniently — an unpadded
longitude in a fixed-width format is not a typo the parser can see, it is a *different location*, and
a lenient parser hands back a plausible wrong answer instead of an error.

**A sole member still earns `lib/src/geography/`.** No existing sector fits a coordinate, and the
public API is flat regardless because `minted.dart` re-exports everything, so the folder costs
nothing and is where the next spatial type (Plus Code, MGRS) lands.

---

<a id="mac-address-value-type"></a>
## MacAddress: two widths, four notations, and no registry

**The type is not called `Eui48`, because an EUI-48 is a narrower thing than a 48-bit MAC address.**
The IEEE Registration Authority's
[guidelines for EUI, OUI and CID](https://standards.ieee.org/wp-content/uploads/import/documents/tutorials/eui.pdf)
retire the term `MAC-48` and warn that `EUI-48` is *not* its replacement, because an EUI-48 "only
refers to individual, universally/globally unique network addresses". A broadcast, multicast or
locally-administered address is a MAC address and is not an EUI-48, so a type named for the narrower
term would refuse most of what its name promises. RFC 9542 §1.1 says the same. This is the
[`Day` test](#date-value-type) again, applied to a name rather than a field.

**Both widths are kept, and neither is converted, because the conversion is deprecated in its
entirety.** The same RA document states that "mapping an EUI-48 to an EUI-64 is deprecated", for both
the `FF-FE` and `FF-FF` fillers, since an address assigned under MA-M or MA-S can collide once
widened. It does not reverse either: a genuine EUI-64 may legitimately carry `FF-FE` in octets 3-4,
so no `toEui48()` could tell an encoded address from a native one. That kills the tempting analogy
with [`Isbn`](#isbn-value-type), whose 978 fold *is* a bijection, and with
[`Gtin`](#gtin-value-type), where padding is lossless. Accepting both widths costs nothing and
touches none of it, and an 802.15.4 or Thread address is a MAC address, so a type named `MacAddress`
that refused it would under-deliver. The cost is that `octets.length` is not a constant, which is why
this was settled before the type shipped rather than retrofitted: adding the second width later would
be a soft break for anyone who assumed six.

**The canonical form is colon-separated lower-case, which knowingly collides with IEEE Std 802
Clause 8.1.** That clause reads a *colon* separator as the bit-reversed representation, a different
value: IEEE's own worked example has `AC-DE-48-12-7B-80` in hexadecimal representation equal to
`35:7B:12:48:DE:01` bit-reversed. Taking the colon form as canonical anyway is a considered break,
not an oversight. RFC 9911 §3 calls lower-case colon the canonical representation, `ether_ntoa` and
essentially every tool emit it, [`Uuid`](#uuid-value-type) already lower-cases its hex, and IEEE
802.1's own YANG work has recorded that near-universal practice "seems to technically violate
subclause 8.1" and asked for the bit-reversal reading to move to an informative annex as historic.
`ieee802` renders the standard's hyphenated upper-case form for anyone who needs it.

**`prefix24`, not `oui`, because the assignment boundary is not in the address.** The IEEE issues
three block sizes (RFC 9542 §2.1, Table 1): MA-L at 24 bits, MA-M at 28, MA-S at 36. The RA states
that "the MA-M does not include assignment of an OUI", and that an OUI-36 assignee "shall not
truncate the OUI-36 to use as an OUI", since the RA hands the same base prefix to many organisations.
So for an MA-M or MA-S address the first 24 bits identify nobody, and telling the cases apart needs
a lookup in three registries. RFC 9542 §2.1.2 adds a second limit: with the local bit set, "the holder
of an OUI has no special authority" over those bits at all. A getter named `oui` would therefore
promise what the data cannot support, the same defect [`Isni`](#isni-value-type) avoids by reporting
the ORCID block rather than gating on it. Vendor lookup is out for the usual reason on top of that:
the registry is a 4 MB CSV, i.e. [a clock](#registry-data-ships-a-clock).

**The bits need no reversal, though they look as if they should.** I/G and U/L are defined by
transmission order, which is least-significant-bit-first on Ethernet, while hex is written
most-significant-first. They coincide, because "the first bit transmitted, of each octet, on the LAN
medium is the least significant bit of that octet", so a plain mask on the octet's integer value is
correct. The second hex digit alone therefore fixes both bits, which is what the type's test table
walks end to end.

**Deliberately not modelled**, each because it would state more than the address does: EUI-48 to
EUI-64 conversion in either direction; RFC 4291's "Modified EUI-64" (an IETF construct, itself
superseded by RFC 7217 and RFC 8064); IEEE 802c's SLAP quadrants, since RFC 9542 §2.1.1 notes the
SLAP is optional with "no automated way to determine" whether a network runs it, so an enum would
dress a nominal bit pattern as a fact about the wire; vendor lookup; the bit-reversed colon notation;
and an `unspecified` constant for `00:00:00:00:00:00`, which is a real Xerox MA-L address whose
"unspecified" meaning is a per-protocol convention rather than an IEEE reservation.

**Input is strict where the wild is loose.** glibc's `ether_ntoa` omits leading zeros, so
`1:2:3:4:5:6` is real output somewhere, and it is rejected here: it matches no standard's grammar,
and a parser that guessed would be hand-writing octets the input did not contain. The four accepted
notations each get their own anchored alternative in one regex, which is what refuses a spelling that
mixes two separators.

---

<a id="hostname-value-type"></a>
## Hostname: strict on purpose, in three directions

**ASCII only, because punycode is not IDNA.** The tempting shortcut is to depend on a punycode
package and fold `bücher.example` to `xn--bcher-kva.example` on parse. RFC 5890 §2.3.2.1 does not
allow it: an A-label needs punycode validity *plus* IDNA2008 validity, NFC, and the Bidi and Context
rules, and "if and only if a string meeting the above requirements can be decoded into a U-label is
it an A-label". The RFC has a name for what you get otherwise, a **fake A-label**. pub.dev carries
punycode implementations and no IDNA one, so encoding here would advertise a conformance nothing in
the dependency tree can back. Refusing says the true thing, and an already-encoded A-label parses
for free, being ordinary letters, digits and hyphens. Same call as
[`prefix24`](#mac-address-value-type) declining the name `oui`.

**A hostname, not a DNS name.** RFC 1123 is LDH: letters, digits, hyphen. RFC 2181 later liberalised
*DNS names* to carry essentially any octet, which is why `_acme-challenge.example.com`, DKIM
selectors and SRV records exist and work. Those are not hostnames, and a type that accepted them
could not promise its value is usable wherever a host is expected. So the underscore is refused, and
because that refusal will surprise people, the failure says `an underscore makes this a DNS name,
not a hostname` rather than lumping it in with a stray character. The permissive counterpart is its
own issue rather than a flag on this one.

**Never an address.** RFC 1123 §2.1 settles what looks like an open question: "a valid host name can
never have the dotted-decimal form #.#.#.#, since at least the highest-level component label will be
alphabetic". The dotted-quad advice in that same section is about what a *resolver* should accept
from a user, not about what a host name is. Enforcing it needs care, though: read literally, "the
highest-level label is alphabetic" would refuse `server1`. The rule that actually holds is RFC
3696's, that a top-level label is never *all*-numeric, which refuses `192.168.1.1` and admits
`server1`.

**253, not 255.** RFC 1035 §2.3.4 caps a name at 255 octets, but that is the wire form, which spends
a length octet per label and a null for the root. Presentation form is therefore two shorter, and
253 is what a string can hold. Both numbers are correct about different things, which is why the
type names the limit it enforces.

**The trailing dot folds rather than surviving.** RFC 3696 §2 calls `a.b.c` and `a.b.c.` equivalent
and requires applications to accept the latter, so this is two spellings of one name and gets the
treatment [`Bic`](#bic-value-type) gives its 8- and 11-character forms. `fqdn` rebuilds the explicit
spelling. A bare `.` is left alone rather than stripped, so it fails as an empty label instead of
quietly becoming the empty string.

**Six failure variants, where three is the house average.** Not vocabulary inflation: RFC 1123
genuinely stacks six independent rules, and each one leaves the caller a different thing to do.
Punycode it, fix a character, fix a label, shorten a label, shorten the name, or reach for an
address type. Two of the six branch their message on the payload, the trick
[`Imei`](#imei-value-type) uses to name a 16-digit input as an IMEISV rather than call it a
miscount.

**`Uri` is not this, measured rather than assumed.** `Uri.parse` accepts `-bad.com`, `bad-.com`,
`a..b.com`, `999.999.999.999` and a 64-character label, and percent-encodes `bücher.example` into
`b%C3%BCcher.example`, which is not what DNS wants. It case-folds and little else, which is the gap
this type fills.

---

<a id="ip-address-value-type"></a>
## IpAddress: a wrapped engine, but not a wrapped grammar

**The engine does the arithmetic; minted does the grammar.** [`ipaddr`](https://pub.dev/packages/ipaddr)
was picked on the usual bar (pure Dart, MIT, zero dependencies, `platform:web`, current) and it
implements RFC 5952 compression correctly, including the rule most hand-rolled versions miss: `::`
must not shorten a *single* zero field. What it does not do is validate. Its octet and hextet gates
are a bare `int.tryParse`, which accepts a sign and trims whitespace, so `192.168.+1.1`,
`192.168.-0.1` and `192.168. 1.1` are all addresses as far as it is concerned. So the split is: the
engine expands `::`, renders RFC 5952 and will do the netmask maths for `Cidr`, and minted owns the
character-level grammar in front of it. Wrapping a package does not have to mean inheriting its
leniency, and the wrapper was translating its throws into a `ParseOutcome` anyway.

**A leading zero is refused, not read, and that one is a security decision.** `inet_aton` reads `010`
as octal 8; almost everything else reads decimal 10. Python's `ipaddress` accepted it until 3.9.5,
and CVE-2021-29921 exists because one component filtering `010` and another connecting to it
disagree about which host was meant. Refusing costs nothing, since no correct writer of an address
pads it.

**One type for both families, with the family reported.** Same call as
[`MacAddress`](#mac-address-value-type) makes for its two widths: one type, never converted, a getter
saying which you hold, and the two never equal. Two types would let the compiler refuse
`v4Network.contains(v6Address)`, which one type can only answer `false` at runtime. That is the
accepted cost of not tripling the surface, and it is documented where it bites rather than left to be
discovered.

**IPv4-mapped addresses keep their mixed spelling**, `::ffff:192.0.2.1`, which RFC 5952 §5 asks for
on that well-known prefix. The engine helps in neither direction: it cannot parse the mixed form at
all, and renders the mapped range as plain hextets. So minted folds the IPv4 tail into two hextets on
the way in and restores it on the way out. The mapped test is on the address *value*, not its
text: `0:0:0:0:ffff:0:0:0` also renders with a leading `::ffff:` and is not mapped, so a string check
would mis-render it as `::ffff:0.0.0.0`.

**Ordering packs to a number.** Comparing the canonical text would put `192.0.2.10` before
`192.0.2.9`, since `1` sorts before `9`. So `compareTo` orders by family, then by the address as one
integer, which is the order anyone sorting a firewall list expects.

**`isLoopback` and `isPrivate` ship; a vendor-style lookup does not.** RFC 1918, RFC 4193's
`fc00::/7`, `127.0.0.0/8` and `::1` are fixed in their RFCs rather than registry-shaped, so they carry
no [clock](#registry-data-ships-a-clock), and they are the two questions people currently answer with
a `startsWith('192.168.')`. Anything needing an arbitrary range is `Cidr.contains`, which composes
instead of growing a getter per block.

**What `Digit` and `Digits` are not doing here, since the question comes up.** An octet is a value,
not digit text, so `fromOctets` takes a `Uint8List` like [`MacAddress`](#mac-address-value-type) and
`Uuid` do. Using `Digits` as the internal strictness gate would reject the signs and whitespace above,
but so does one regex, and a layer catching nothing the simpler layer catches is the layer to cut.
The bounded-int types are no better a fit: an octet is 0-255, a hextet 0-65535, a prefix length
0-32 or 0-128, a port 0-65535, all bounded at *both* ends, where a non-negative int is bounded only
below. Dogfooding pays here through composition instead: `Cidr` taking an `IpAddress`.

---

<a id="cidr-value-type"></a>
## Cidr: a block that masks, not a string that starts with

**The bug this type exists for is `startsWith`.** An allow-list holding `'10.0.0.0/8'` as a string
gets tested with a prefix match, and a prefix match says `100.0.0.1` is inside it. Containment is a
question about bits, and the only way to answer it is to mask both sides and compare, which is what
this type does and what a `String` cannot.

**Host bits are refused, not masked.** `192.168.1.5/24` fails rather than becoming `192.168.1.0/24`.
Masking is what most tooling does and it would match the normalise-on-parse pattern used everywhere
else here, but it loses to the rule [`GeoCoordinate`](#geo-coordinate-value-type) already states for
altitude: a parse that silently loses part of its input is not a parse. The caller wrote a host
address, and quietly returning a different value than they typed is how a firewall rule ends up
meaning something nobody reviewed. The failure carries the block they most likely meant, so the
remedy is in the error rather than left as an exercise. The address-with-prefix concept is a
genuinely different type, which Python calls `ip_interface`, and can follow if anyone wants it.

**It holds an [`IpAddress`](#ip-address-value-type), and that is the whole point.** The earlier
shape rule would have made this an extension type over `10.0.0.0/8`, slicing an address back out of
its own text on every call. Holding the parsed address means the network address cannot be
malformed, `contains` cannot be handed something that merely looks like one, and the mask is already
applied: because parsing guarantees the host bits are clear, `network.octets` *is* the masked
network part, so containment is one comparison rather than two maskings. See [compose from modelled
parts](#compose-from-modelled-parts) for the general rule this was the first type to follow.

**The engine does nothing here, and that is worth recording.** `ipaddr` earns its place inside
[`IpAddress`](#ip-address-value-type), where it expands `::` and renders RFC 5952. Its network types
have no containment test at all, and the one its README shows is `addresses.contains(…)`, a scan
over a lazy iterable: 16.7 million allocations for a `/8`, and no termination at all for a v6 block.
Netmask-from-prefix and the host-bits check are elementary bit maths on octets this package already
exposes, so `Cidr` adds no dependency surface of its own.

**`lastAddress`, not `broadcast`.** IPv6 has no broadcast at all; it uses multicast. `ipaddr` and
Python both call the top of a block its broadcast address, which is a misnomer inherited from IPv4
and one this package need not repeat, for the same reason `prefix24` declines the name
[`oui`](#mac-address-value-type). `netmask` and `hostmask` are absent for a different reason: nobody
writes a v6 netmask, and `contains` makes both unnecessary.

**One notation in, one out.** `address/prefixLength` and nothing else, so a dotted netmask
(`/255.255.255.0`, which the engine would accept) and a bare address with no prefix are both
refused. The prefix goes through the same digits-only gate as the address, since `ipaddr`'s
`_makePrefix` is another bare `int.tryParse` and would take `/+24`, `/ 24` and `/-0`. A leading zero
on the prefix *is* accepted and folds to the plain number, unlike a leading zero in an address:
`/024` carries none of the octal ambiguity that makes `010` dangerous in an octet.

**A family mismatch answers `false` rather than refusing to compile.** That is the accepted cost of
[one address type for both families](#ip-address-value-type). Two types would have let the compiler
reject `v4Block.contains(v6Address)` outright; one type can only answer it at runtime. Documented on
`contains` rather than left to be discovered.

---

<a id="constraint-types"></a>
## Constraint types: a range, not a standard

**A second category, not value types with a relaxed contract.** A constraint type is a pure range
over a number: no checksum, no notation, no standard. They live under `lib/src/quantities/`, a sector
chosen by contract rather than by domain, because `conformance_test.dart` tells one from a value type
**by path**: "is a constraint type" is not something the AST reveals the way `isEnum` is. A `Port`
filed under `network/` would silently opt out of the check.

**No `parse(String)` door.** Decimal notation is how numbers are written, not a published format for
"a non-negative integer", so a parse door would invent a text form and then owe it forever. The rule,
*a numeric type gets `parse(String)` only where a standard defines its text form*, is also why
[`Date`](#date-value-type) keeps its door without needing an exemption.

**`tryFrom` alone, and no `from`.** The obvious shape was both, matching [`Weekday`](#weekday-enum).
Rejected on reversibility: adding `from` later is a minor bump, removing it later is a major one, and
the no-implicit-throws work already schedules every `from` with a nullable sibling for deletion.
Shipping a door with a known removal date costs more than not shipping one.

**No failure vocabulary, because there is nothing to say.** One invariant per type means a failure
enum would carry a single variant meaning "out of range", which is what `null` already means. With no
throwing door there is nothing to carry it either; [`WeekdayFailure`](#per-type-failures) exists only
because `Weekday.from` throws.

**Two types, not one.** `Uint` (`>= 0`) and `NaturalNumber` (`> 0`) differ by a single value, and
that value is the point: an empty cart is a real count, a page size of zero is not. One type would
push the zero check back to every call site, which is the hand-checking this package deletes.

**The names are a compromise, and the dartdoc carries the fix.** `Uint` promises C semantics it does
not have, and `NaturalNumber` lands on a split convention (ISO 80000-2 counts `0` among the naturals;
school arithmetic does not). Both were chosen for familiarity over self-description, with the exact
boundary stated in each dartdoc rather than spelled into a clunkier name. The rejected pair was
`NonNegativeInt` / `PositiveInt`.

**The fixed widths are separate types, not factories.** `Uint.w8(200)` was the tempting spelling and
it does range-check correctly, but every result is still a `Uint`, so nothing stops a byte landing in
a nibble slot; the analyzer stays silent. As separate types it rejects that, and rejects implicit
widening in both directions, so a `Uint4` needs `Uint8.tryFrom(nibble.value)` to become a byte. The
verbosity is the guarantee working. (`Uint.4(…)` is not spellable at all: a Dart member name cannot
start with a digit.)

**A width is not a domain, which is a rule about use rather than an argument against the types.**
`Uint16` says how many bits a value fits in, not what it means, so two unrelated domains of the same
width are interchangeable: a port and an IPv6 hextet are both `0`-`65535`. Reach for a `UintN` for an
actual machine field; a concept with a bound of its own gets its own named type, which may check
against a width but is never an alias for one.

**No `Uint64`.** Dart ints are JS doubles on the web, so the honest ceiling is 2^53-1 and a type
advertising 2^64-1 could not keep the promise its name makes. The family stops at 32.

---

<a id="what-not-covered"></a>
## What `minted` deliberately does not cover

`minted` targets the gap where no clean Dart value type exists. It does not re-model things the
Dart stdlib or a strong existing package already handles well:

- **Stdlib already covers:** URLs/URIs (`Uri`), instants and durations (`DateTime` / `Duration`),
  big integers (`BigInt`); in Flutter, `Color`, `Locale`, `TimeOfDay`.
- **Strong existing packages cover (wrap or reuse, don't reimplement):** money/decimals (`money2`,
  `decimal`, `rational`), SemVer (`pub_semver`), formatting and ISO code *lists* (`intl`,
  `sealed_countries`, `sealed_currencies`), IANA time zones (`timezone`), hashes (`crypto`).

Apparent overlaps that are actually gaps. `DateTime` models an *instant*, not a plain calendar date,
and Dart has no `LocalDate`, so [`Date`](#date-value-type) fills that. The `uuid` package *generates*
into a `String` rather than being a value type, so [`Uuid`](#uuid-value-type) types an existing one.
And IP addresses are **not** covered by the stdlib for this package's purposes, which is what
[`IpAddress`](#ip-address-value-type) exists for. `InternetAddress` is
`dart:io`, so it is unavailable on the web, which a pure-Dart web-safe package cannot build on.

Where `minted` builds *on* such a package it wraps rather than reinvents: a pure-Dart, web-safe engine
sits in core, and only an adapter to another ecosystem goes in a companion (see
[packaging](#packaging-core-and-companions)). The README carries the current per-type comparison, and
the [issue tracker](https://github.com/LahaLuhem/minted/issues) holds the gap types still to land.
