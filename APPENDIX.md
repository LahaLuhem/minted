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
- [Iso8601Duration: components, not a scalar](#iso8601-duration-value-type)
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
- [Geohash: a cell, not a point](#geohash-value-type)
- [MacAddress: two widths, four notations, and no registry](#mac-address-value-type)
- [Hostname: strict on purpose, in three directions](#hostname-value-type)
- [DnsName: permissive, but not infinitely so](#dns-name-value-type)
- [IpAddress: a wrapped engine, but not a wrapped grammar](#ip-address-value-type)
- [Cidr: a block that masks, not a string that starts with](#cidr-value-type)
- [Port: a domain that borrows a width](#port-value-type)
- [Constraint types: a range, not a standard](#constraint-types)
- [Percentage: the unit is the whole point](#percentage-constraint-type)
- [Probability: bounded, and both ends belong](#probability-constraint-type)
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
heavy dependency does not go here; it goes in an adapter package (see
[packaging](#packaging-core-and-companions)). Every package's dependency list is a promise to its
downstream users, so each stays as short as the validation honestly requires.

---

<a id="ci-sdk-toolchain"></a>
## The format gate runs Flutter's Dart, everything else runs Dart stable

**Split along style versus correctness.** `dart format` is the only check whose output must agree
with the maintainer's machine character for character, so that job takes its Dart from Flutter, the
channel [`.fvmrc`](./.fvmrc) names. Analyze, test, the dependency validator and the example stay on
Dart stable through the [`setup-dart` composite](./.github/actions/setup-dart/action.yml).

**What forced it:** Dart stable runs ahead of Flutter's bundled Dart, and the formatter changed
between them. `sdk: stable` gave CI 3.13.0 against a local 3.12.2, so a green tree met a red gate
that reformatted fifteen files the pull request had never touched. The decisive property is that a
format failure must be *reproducible*: whatever CI rejects, `dart format .` locally has to be able to
fix, which neither Dart stable nor a pinned literal promises once it drifts from the machine the code
is written on.

**Elsewhere the newer SDK is the point.** Those jobs run Dart stable, which is what
[`pubspec.yaml`](./packages/minted/pubspec.yaml)'s constraint admits and what a downstream Dart-only user is on.
The known cost is that the analyzer is version-sensitive too, so a Dart-stable-only diagnostic would
be fixed slightly blind; explicit rules in [`analysis_options.yaml`](./analysis_options.yaml) stop
new lints switching themselves on, and if it ever stops being tolerable the format job's recipe moves
into the composite.

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
- The only ways in are `parse` and the assembly factories (both return a
  [`ParseOutcome`](#parse-outcome)), and `tryParse` (returns `T?`). All run the same full check, and
  none of them throws.
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
up the zero-cost representation, so an extension type stays right wherever the value has no inner
structure worth naming.

**Where the audit landed, and why each type sits where it does.** `Isbn` and `Imei` keep their
`String` representation and hand back `Digits` from their digit-segment getters, which is the whole
benefit (the round trip type-checks) without the two costs of holding one: hand-written equality,
and `print` rendering `Digits(978…)` instead of the identifier. The rest are correctly extension
types over text, each for its own reason:

- `Iban`'s `bban`, `Isin`'s `nsin` and `Bic`'s codes are alphanumeric, and there is no alphanumeric
  type to hold. Minting one was declined: see [the door table](#parse-outcome).
- `Hostname` and `DnsName` labels have no type either, because a label's validity is **positional**.
  `Hostname` refuses an all-numeric *last* label, so a valid label at one index is invalid at
  another, and no per-label type can express that.
- `Email.domain` is not always a hostname. An RFC 5321 address literal (`jane@[192.0.2.1]`) and an
  internationalised domain are both valid addresses whose domain a `Hostname` refuses, so the getter
  stays text and [`domainAsHostname`](#hostname-value-type) offers the partial narrowing.
- `IpAddress.octets` stays a `Uint8List`, which already enforces `0`-`255` by construction, so
  `List<Uint8>` would catch nothing while taxing every arithmetic use with `.value`.
- `Gtin`, `Issn` and `Isni` expose no digit-segment getter at all: their public surface is render
  helpers, and a check character can be `X`, which a `Digits` cannot hold.

---

<a id="typed-digit-subparts"></a>
## Typed digits: `Digit` and `Digits`

The parse-don't-validate guarantee normally stops at the whole value (`Iban`, `PhoneNumber`).
Where a validated whole exposes a part that is *only* decimal digits, that part is typed as digits
rather than a raw `String`, so "these are digits" is a fact of the type instead of an assumption
each caller re-checks. Neither `Digit` nor `Digits` is a domain entity from a standard; they are
the building blocks the standard types are cut from.

**They travel both ways, and that is what makes the round trip compose.** `Isbn.prefix` and
`Imei.tac` hand back a `Digits`, and `Isbn.fromComponents` and `Imei.fromComponents` take one, so
`Imei.fromComponents(tac: imei.tac, serialNumber: imei.serialNumber)` type-checks. It did not, while
the getters returned `String` and the parameters took `Digits`: the two halves of one type disagreed
about what its parts were. Parts that are genuinely alphanumeric keep `String`, because `Digits`
there would be a narrower type rather than a stronger one, and no alphanumeric type exists to hold
them.

**A `Digits` is not text, and interpolating one says so.** It hand-writes `toString`, so `'$prefix'`
renders `Digits(978)`. Nothing diagnoses that (interpolation takes any `Object`), so rendered output
reaches for `.asString`. This is the same delegation cost that keeps these types `String`-backed
rather than `Digits`-backed: an extension type over `Digits` would make `print(isbn)` render
`Digits(9780306406157)`.

**Building one from text is the caller's job.** There is no `Digits.parse`, because decimal notation
is not a published format for "a digit sequence", so a door there would invent one. Inside the
package `shared/encoding/digit_values.dart` decodes a code-unit range straight into values, which is
how a validated whole hands back a digits-only part without allocating a substring.

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
*identity* equality, so `Digits.tryFrom([1, 2])` would never equal another `Digits.tryFrom([1, 2])`;
the
class hand-writes structural `==`/`hashCode` over the bytes (its first use of `package:meta`, for
`@immutable`). Encapsulation: the `Uint8List` is private, so a denser backing (nibble-packed BCD at
two digits per byte, or tighter) can replace it behind the same `Iterable<Digit>` / `operator []` /
`asString` interface without touching callers. Packing is deferred on purpose; it only pays off at
a volume identifiers rarely reach, and the unpacked bytes read as the digits under a debugger.

---

<a id="why-typed-format-exception"></a>
## Why the thrown type is an `Error`

Nothing in the package throws at input: every fallible door reports its failure in its return type.
The one throw left is [`ParseOutcome.getOrThrow`](#parse-outcome), which a caller types
deliberately, and it raises `MintedFormatError`.

**An `Error`, not an `Exception`.** Reaching it means someone asserted a value was valid and was
wrong, which is a bug in their source rather than a condition to branch on. That is what Dart's
`Error` means (`RangeError`, `StateError`, `ArgumentError`), and it is why `on FormatException` no
longer catches it. Earlier versions extended `FormatException` for stdlib consistency, which made
sense while the assembly factories threw on bad input; once they stopped, the only thing that
argument protected was catch-as-control-flow.

**It carries the typed [`MintedFailure`](#per-type-failures)** and renders `Invalid <typeName>:
<message>` from it, so a caller can switch on the cause or log the text. That `typeName` is an
explicit string rather than a `'$T'`, because the value types erase to their representation at
runtime and `'$T'` would render `String`, not `Iban`. It carries no `source`: the outcome has the
failure but never the text that produced it, so inventing one would be a lie.

A `throw` rather than an `assert`, since `assert` is stripped in release and this guards the type's
core guarantee (see [CODESTYLE class structure](./CODESTYLE.md#class-structure)).

---

<a id="claim-in-source"></a>
## A throw is for a claim you made in source, and you have to type it

The line is **who is responsible for the failure**, and the answer decides who writes the throw.

Every door reports: `parse` takes text you did not control, and an assembly factory takes parts you
believe in, but in both cases the caller may be wrong, so both return a `ParseOutcome` and the
compiler insists on a decision.

**An earlier version of this had the assembly factories throw**, reasoning that
`Iban.fromComponents(countryCode: 'GB', bban: …)` *is* a claim made in source, so a violation is a
bug rather than a branch. The claim half of that is still true; what was wrong was letting the door
make it on the caller's behalf. A signature reading `Iban fromComponents(...)` promises totality and
then blows up, and the caller never opted in. Now they spell it: `fromComponents(...).getOrThrow()`
is the same assertion, made visible, in eleven characters. Prevent-by-design beats an exception
trickling through call sites that never asked for one.

This is still the line every comparable system draws, only with the crossing made explicit: Rust
separates `Result` from `panic!`, Haskell separates `Either` from `error`, and ribs ships
`Either.catching` for crossing it deliberately. `getOrThrow` is this package's crossing.

---

<a id="parse-outcome"></a>
## Why a bespoke `ParseOutcome`, not `Either`

`ParseOutcome<F extends MintedFailure, T>` is a sealed two-arm type in core, with no new dependency.
It is deliberately `Either`-shaped so FP-style code reads natively, but named for the domain rather
than `Left` / `Right`, because the package is general-purpose.

**The door table**, which governs what any new member returns. Two rules decide every row: *a door
that can fail says so in its return type*, and *a type gets a `parse(String)` door only where a
standard defines its text form.*

| Door | Example | Returns |
|------|---------|---------|
| Parse text | `Iban.parse(String)` | `ParseOutcome<F, T>` |
| Parse text, cheaply | `Iban.tryParse(String)` | `T?` |
| Assemble from parts | `Isbn.fromComponents`, `Uuid.fromBytes`, `Date.of` | `ParseOutcome<F, T>` |
| Range-check a primitive | `Digit.tryFrom(int)`, `Uint.tryFrom(int)` | `T?` |
| Assert against an outcome | `Isbn.parse('…').getOrThrow()` | `T`, throws `MintedFormatError` |
| Cannot fail | `Digits.of(Iterable<Digit>)`, `Date.now()` | `T` |

The last row matters as much as the others: never wrap a total function in an outcome. And nothing
grows a *sixth* kind, because a per-type throwing door is only `parse`'s signature with a throw
bolted on: `getOrThrow` lives on the sealed base, so one method serves every value type.

**A door returns `T?` only where there is no vocabulary to discard.** A range check has one
invariant, so `null` says everything a failure could, which is why the constraint types carry none.
Everywhere a `XFailure` exists, the fallible doors return it; the alternative, deciding per door by
counting how many variants are currently reachable, would make *enriching* a vocabulary a breaking
change.

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
tiny in-repo helper, not a BDD framework. [`test/support/bdd.dart`](./packages/minted/test/support/bdd.dart) is
about 25 lines of `feature` / `scenario` / `scenarioOutline` over `package:test`, with the
assertions still written in `package:checks`.

A real Gherkin runner was evaluated and turned down on the merits, not on availability. An earlier
`bdd_framework` dev-dependency was dropped for pulling in `flutter_test` (which breaks `dart test`
off Flutter), but the pure-Dart `gherkin` package *does* resolve and run Flutter-free here. It was
still rejected, for four reasons independent of any version:

- **No audience for the payoff.** Gherkin earns its keep when non-technical stakeholders read and
  write `.feature` files. This package's consumers are Dart developers, and the specification is
  already the published standard plus the dartdoc plus the structural
  [`conformance_test.dart`](./packages/minted_conformance/test/conformance_test.dart).
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
## Packaging: one package per domain, engines beside the types that wrap them

No consumer should resolve a dependency for a type they never touch. Dart declares dependencies per
package, not per library, so the moment any file in a package imports something, it lands in every
consumer's lockfile. Tree-shaking is no answer: measured, a program importing all of `minted` and
using only `Date` compiles byte-identical to hello-world, yet the lockfile still lists all seven
dependencies. Dead code is free; a dependency-graph entry is not.

One package therefore cannot hold optional heavy libraries, which is what v3 splits:

- **Each domain is a package, and its engine goes with it.** `email_validator` and
  `phone_numbers_parser` are in `minted_contact`, `iban_validator` and `country_code` in
  `minted_finance`, `ipaddr` in `minted_network`. The engine is the parser or registry the type
  needs to exist, so it belongs wherever that type does.
- **Core carries only what every domain speaks**: the outcome vocabulary and the numeric
  primitives, on `collection` and `meta`. A chronology consumer resolves three packages where the
  single package cost seven.
- **Adapters stay separate**, as they always would have: `fpdart`, `hive`, a Flutter form-field
  validator. Each becomes `minted_fpdart` and friends, on core plus its one integration dependency.
- **Zero-dependency integrations can be opt-in libraries** rather than packages. JSON, where
  `fromJson` is just `parse`, needs nothing extra, so `package:minted/json.dart` would force
  nothing on anyone.

All of it lives in one repo, a pub workspace since the run-up to v3. Separate repositories were the
earlier plan; one tree won because a release across eight repos is worse than a release picker in
one, and because a type and its tests should move together.

The cost is real and was accepted: seven publish surfaces, and helpers used by more than one
package become `package:minted/internal.dart`, which carries no semver promise but cannot break
within a major.

**The cross-package suites need a host that is never published.**
[`failure_contract_test.dart`](./packages/minted_conformance/test/failure_contract_test.dart) imports
all seven siblings, and every sibling already depends on core, so hosting it in `minted` would point
a dev-dependency arrow back from core to its own dependents. Locally that resolves by path and looks
fine; on pub.dev it deadlocks the first publish of either side, because core cannot go up until
`minted_chronology` is up and `minted_chronology` cannot go up until core is. `publish_to: none`
breaks the cycle, since a package that never reaches pub.dev may depend on anything. The
[cutover order](./scripts/README.md) is the softer version of the same constraint, and the
sibling-constraint preflight exists because that one already bit.

**Keeping it a workspace member, rather than moving the suites to the workspace root, is a separate
decision that coverage settles.** `melos exec` visits members only, and `format_coverage
--in=packages` reads only what lands under `packages/`, so a suite at the root would be collected by
neither. These suites cover seven other packages' `lib/` while `minted_conformance` owns no `lib` of
its own, which makes that scoping the whole of their coverage contribution. The inverse follows too:
a suite whose coverage nobody attributes has no reason to be a member.

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

The floor lives in [`pubspec.yaml`](./packages/minted/pubspec.yaml)'s `sdk:` constraint and tracks what the package
actually consumes: extension types need ≥ 3.3, static dot shorthands ≥ 3.10, the `new` constructor
shorthand ≥ 3.13. The cost is reach, since a project on an older SDK can't depend on `minted`.
Acceptable for a fresh package, and because a floor can only be raised without a breaking change,
starting current avoids churn later. Record any bump here.

**Primary (declaring) constructors went stable in 3.13 and are still not used**, for a new reason.
`public_member_api_docs`, which this package enables, treats the implicit primary constructor as an
undocumented public member and reports it at the class name, where there is no declaration to attach
a `///` to. Verified: const, non-const and zero-parameter forms are all flagged, while the old form
with a documented constructor is clean. Satisfying it costs an `// ignore:` per class (and
`document_ignores` is on, so that needs its own justification, more noise than the docstring it
replaced) or dropping the lint package-wide. It has a history of firing on constructors with nowhere
to document ([linter#3655](https://github.com/dart-lang/linter/issues/3655),
[linter#284](https://github.com/dart-lang/linter/issues/284)), so this is a known pattern, not a
fresh bug. The other half does work: `dart doc` carries a `///` on a primary-constructor parameter
through to a field page just like a documented field. Revisit if the lint learns about them.

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
wrong answer, which is the opposite of what the type is for. `implements` costs more, not less: about
twenty members written by hand, each facing the same problem.

**Composing a `Duration` for the exact part was the closer call.** Weeks down to seconds are all
fixed-length, so `years`, `months` and one `Duration` would replace eight fields and drop the
component enum, roughly 50 lines. It was declined because a fraction of a month is not a fixed
`Duration`, so `P0.5Y` and `P0.5M` become inexpressible unless those two fields turn into doubles,
and `P2W` collapses into `P14D` without a flag to hold the form. The components model keeps the
fidelity; the saving was not worth trading it for.

**`toDuration` takes a required named `from`.** A month is 28 to 31 days, so the anchor is what makes
the question answerable at all, and a named parameter makes it impossible to supply by accident.
Calendar components resolve first, clamping the day the way `2026-01-31` plus a month gives
`2026-02-28`.

**The week form is exclusive because ISO 8601 says so.** `PnW` is an alternative to
`PnYnMnDTnHnMnS`, not a component of it, so `P1Y2W` is refused rather than read as 54 weeks. Same
reasoning as [checking the real standard](#check-digits-not-regex) elsewhere: accepting input the
standard does not define is as wrong as refusing input it does.

**Zero spells itself.** Components that are absent or zero collapse, which would leave bare `P`, and
`P` is not a duration. The canonical form emits `PT0S`, so it round-trips like every other type's.

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
`iban_check_digits.dart` into `shared/encoding/`: ISO 13616 folds those values into mod-97 and ISO 6166
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

<a id="geohash-value-type"></a>
## Geohash: a cell, not a point

**The bug is the round trip.** A geohash names a rectangle, and a `String` cannot say whether you
hold the rectangle or a point in it, so code decodes one to a single lat/lng, treats that as *the*
location, and the position moves by up to a cell's width. Naming the accessor `centre` is the fix.
Secondary and more common: `toLowerCase()` is not validation, the alphabet having dropped `a`, `i`,
`l` and `o`.

**No length cap, which is [`Bic`](#bic-value-type)'s rule reaching the opposite answer.** Both
*validate what the standard fixes*: ISO 9362 fixes eight or eleven characters, and nothing readable
in CTA-5009-A fixes a ceiling. Twelve is where implementations stop, not where the standard does, so
refusing thirteen would refuse a cell this type represents exactly. `centre` documents where honesty
ends instead: beyond about 23 characters a `double` runs out of mantissa and it stops moving,
measured rather than derived.

**`from` returns its value, not a `ParseOutcome`, the family's first door to do so.** Typing
`precision` as [`NaturalNumber`](#constraint-types) makes a bad one unrepresentable rather than
reportable, and with a `GeoCoordinate` opposite it nothing is left to refuse, so an outcome would be
[wrapping a total function](#parse-outcome). That also makes it the first assembly door that can be a
*constructor*, which `prefer_constructors_over_static_methods` demands once the outcome goes. The
cost is real: constraint types expose only `tryFrom`, so call sites read `NaturalNumber.tryFrom(5)!`
and pull in `package:minted`.

**Lossy on purpose, unlike the two rules that forbid loss.**
[`GeoCoordinate`](#geo-coordinate-value-type) refuses altitude and [`Cidr`](#cidr-value-type) refuses
host bits, both on "a parse that silently loses input is not a parse". Here `precision` sizes the
loss and `centre` reads it back, so nothing is silent.

**No `compareTo`.** The alphabet is ASCII-ascending on purpose, so plain string order already is
geohash order, which is what makes a prefix range query work. Neighbour and parent traversal are
simply not built yet; the seam problem they solve is real.

**The south-west corner is unreachable through `from`.** `GeoCoordinate` folds `-180` onto `+180`, so
`(-90, -180)` encodes to `pbpbpb`; the all-zero cell parses fine, its centre just inside it. Pinned
by a test, because the fold is right for a coordinate and only surprising if you expected the grid to
have a reachable corner.

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
not a hostname` rather than lumping it in with a stray character. The permissive counterpart shipped
as [`DnsName`](#dns-name-value-type), a second type rather than a flag on this one.

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

<a id="dns-name-value-type"></a>
## DnsName: permissive, but not infinitely so

**RFC 2181 §11 licenses the charset restriction rather than forbidding it.** It says the DNS imposes
only length limits, and that applications using DNS data may add constraints suited to their
purposes. Picking a charset is therefore the clause the standard provides, not a defiance of it. The
invention would be claiming an RFC *requires* the charset.

**Literal any-octet was rejected on the representation, not on taste.** A Dart `String` is UTF-16,
so a type over one cannot honestly promise RFC 2181's octet freedom: it would advertise a
conformance the representation cannot hold, the same objection that made
[`Hostname`](#hostname-value-type) refuse to fake an A-label. It could not safely lower-case either.

**Leading-underscore-only was the tempting middle, and it invents a prohibition.** RFC 8552 §1.1
says an underscored node name begins with an underscore and stops there: it never defines what may
follow, nor rules one out elsewhere in a label. Turning "the convention puts one here" into "one
anywhere else is an error" would make the *permissive* type refuse `a_b.example.com`, which occurs.
So the charset is LDH plus underscore, and `isUnderscored` **reports** an RFC 8552 attribute leaf
rather than gating on one, the way [`Port`](#port-value-type) reports its range.

**Two rules are dropped, not relaxed.** RFC 1123's hyphen-edge and all-numeric-label rules are about
*host names* and RFC 2181 has neither, so `-bad.example.com` and `192.168.1.1` both parse here.
Worth stating precisely, because the numeric rule only ever inspected the **last** label:
`4.3.2.1.in-addr.arpa` was always a valid `Hostname`, `arpa` being alphabetic. Reverse DNS never
needed this type; underscored names did.

**Case-folding survives because the charset is bounded.** RFC 1035 §2.3.3 makes DNS comparison
case-insensitive, so lower-casing matches `Hostname`. On arbitrary octets "lower-case" has no single
meaning, which is the second argument for bounding the charset.

**The conversion is asymmetric, and both directions live here.** `fromHostname` is total and
constructs directly, its input being already normalised and strictly inside these rules;
`tryToHostname` is a parse. Both sit on `DnsName` because `Hostname` shipped first and stays unaware
of it, the same call [`Probability`](#probability-constraint-type) made about `Percentage`.

**The shared DNS rules moved to `network/standards/dns_names.dart`** when this type landed. The
63/253 limits, the root-dot fold and the ASCII gate were about to exist twice, and the strict and
permissive types drifting on a limit is the failure that file guards against.

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

<a id="port-value-type"></a>
## Port: a domain that borrows a width

**It borrows [`Uint16`](#constraint-types)'s bound instead of restating it.** A port is `0`-`65535`,
exactly a 16-bit field, so `Port.tryFrom` delegates and adds no check of its own. The alternative was
a local `65535`, which is the duplication `IpAddress`'s octet bound was already folded into `Uint8`
for. Note this only works because the ranges are *identical*: `Digit` declined the same trick over
`Uint4`, since `0`-`9` sits strictly inside `0`-`15` and the nibble would have caught nothing.

**It `implements Uint16` rather than aliasing it.** The subtype relation is real, since every port is
a valid 16-bit value, and it buys the one-directional conversion: a `Port` goes where a `Uint16` is
wanted, never the reverse. An alias would have gone further and made them interchangeable, which is
the mistake [a width is not a domain](#constraint-types) warns about: an IPv6 hextet is `0`-`65535`
too, and it is not a port.

**Not a `Uint16` representation.** Holding one would make `.value` a `Uint16`, so reading the number
becomes `port.value.value`, against the contract's rule that `.value` *is* the canonical form. The
representation stays an `int`; only the validation is borrowed.

**Port `0` is accepted, and named rather than refused.** It is a real member of the range, and
`bind(0)` asking the OS for a free port is ordinary. Rejecting it would have cost the exact-`Uint16`
alignment above and pushed callers into modelling "any port" separately, for a value the type can
simply describe. `isWildcard` does the describing, since RFC 6335 gives `0` no name of its own,
listing it among the reserved values "at the edges of each range".

**`range` reports, it does not gate.** The RFC 6335 bands are an IANA assignment policy, not a
validity rule, so a `PortRange` is read back the way `MacAddress` reads its I/G and U/L bits. Gating
on it would refuse ports that work.

**It lives in `network/`, which is what forced the constraint-type list.** Filing it by domain broke
the path-based detection described [below](#constraint-types), and the test now names its constraint
types instead. The type's home should follow the domain, not the test.

---

<a id="constraint-types"></a>
## Constraint types: a range, not a standard

**A second category, not value types with a relaxed contract.** A constraint type is a number with a
constraint on it and no standard defining its text form: no checksum, no notation. Usually a range;
[`Percentage`](#percentage-constraint-type) constrains the unit instead.

**The category is named, not derived from the directory.** `conformance_test.dart` lists them in
`_constraintTypes`, because "is a constraint type" is not something the AST reveals the way `isEnum`
is. Deciding it by path was the first attempt and it forced the wrong filing: `Port` is a network
concept, and burying it in `quantities/` to satisfy a test would have put the tooling ahead of the
domain. A name list costs one line per type and leaves filing to the domain. It fails safe too, since
omitting a name makes the test demand parse doors rather than quietly relax the contract.

**No `parse(String)` door.** Decimal notation is how numbers are written, not a published format for
"a non-negative integer", so a parse door would invent a text form and then owe it forever. The rule,
*a numeric type gets `parse(String)` only where a standard defines its text form*, is also why
[`Date`](#date-value-type) keeps its door without needing an exemption.

**`tryFrom` alone, and no `from`.** The obvious shape was both, matching [`Weekday`](#weekday-enum).
Rejected on reversibility: adding `from` later is a minor bump, removing it later is a major one, and
the no-implicit-throws work already schedules every `from` with a nullable sibling for deletion.
Shipping a door with a known removal date costs more than not shipping one.

**No failure vocabulary, because there is nothing to say.** One invariant per type means a failure
enum would carry a single variant meaning "out of range", which is what `null` already means. The
same reasoning caught up with `Digit`, `Digits` and `Weekday` in v2: once their throwing doors went,
their vocabularies had no producer and went too.

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
a nibble slot; the analyzer stays silent. As separate types it rejects that, which is the point.
(`Uint.4(…)` is not spellable at all: a Dart member name cannot start with a digit.)

**Widening is deferred, not impossible.** A `Uint4` currently needs `Uint8.tryFrom(nibble.value)` to
become a byte, which is friction in the one direction that cannot fail. One `implements` clause per
type removes it: `Uint2 implements Uint4` up through `Uint32 implements Uint`, with
`NaturalNumber implements Uint` alongside. Verified to give free widening while still rejecting every
narrowing, every unbounded-to-fixed hop, and byte-to-natural. Held until #33's `Port` supplies a first
real caller rather than a guess at one.

**A width is not a domain, which is a rule about use rather than an argument against the types.**
`Uint16` says how many bits a value fits in, not what it means, so two unrelated domains of the same
width are interchangeable: a port and an IPv6 hextet are both `0`-`65535`. Reach for a `UintN` for an
actual machine field; a concept with a bound of its own gets its own named type, which may check
against a width but is never an alias for one.

**No `Uint64`.** Dart ints are JS doubles on the web, so the honest ceiling is 2^53-1 and a type
advertising 2^64-1 could not keep the promise its name makes. The family stops at 32.

**Neither `binary` nor `fixnum` could stand in.** [`binary`](https://pub.dev/packages/binary) has the
right shape and even the same `static Uint8? tryFrom(int)`, but that is one door out of seven: in a
release build `Uint8(999)` wraps to `231` and `fromUnchecked(999)` yields a `Uint8` holding `999`,
because `debugCheckFixedWithInRange` is assert-only and "in release mode, these assertions are always
disabled and cannot be enabled". Re-exporting it would ship four unvalidated public doors, one of them
the default constructor. [`fixnum`](https://pub.dev/packages/fixnum) is a different job entirely:
`Int32` / `Int64` only, no unsigned type at all, and wrapping arithmetic is its documented feature
rather than a hazard. Neither carries a `Uint2` or `Uint4`.

---

<a id="percentage-constraint-type"></a>
## Percentage: the unit is the whole point

**It stretches the [constraint-type](#constraint-types) category on purpose.** Every other member is
a range over a number; this one's only invariant is finiteness, and what it pins down is the *unit*.
The half of the category that decides the shape still holds: no standard defines a text form for a
percentage, so there is no `parse(String)` door.

**Deliberately unbounded.** `0` to `100` is the obvious range and it is wrong, because 250% growth
and -12% churn are real values a bound would refuse. That leaves `NaN` and the infinities as the
only things to reject, which makes "an unbounded Percentage is just a double with a label" a fair
challenge at review. The label is the entire point: `15` versus `0.15` for the same proportion is
plausible both ways and checkable at no call site.

**`.value` holds the percent, for arithmetic reasons rather than taste.** `.value` *is* the
canonical form, so the stored unit is the one that has to render cleanly, and the two conventions
are not symmetric:

| stored          | derived | result               |
|-----------------|---------|----------------------|
| fraction `0.29` | `× 100` | `28.999999999999996` |
| fraction `0.58` | `× 100` | `57.99999999999999`  |
| percent `29`    | `/ 100` | `0.29`, exactly      |
| percent `58`    | `/ 100` | `0.58`, exactly      |

`x / 100` rounds to the nearest double of the true value, which is the double the literal gives;
`f * 100` compounds the error already in `f`. Store the fraction and `.value` renders
`57.99999999999999` for something a human wrote as 58%.

**`tryFromFraction` shifts the decimal rather than multiplying**, for that same reason: it re-reads
the shortest round-tripping decimal two places over via `toStringAsExponential`, so `0.29` lands on
`29`. The non-finite guard runs first, since a `NaN` has no exponent to bump.

**Two doors, where every other constraint type has one.** The bare door is the percent because the
name states the unit; the fraction door is spelled out so a caller holding a ratio cannot get it
wrong. One door would have put `Percentage.tryFrom(ratio * 100)` at the call site, the exact
multiply the type exists to delete. Not the `from` case [constraint types](#constraint-types)
refused, because a second input *unit* carries no removal date the way a redundant throwing door
does.

**`double`, not a fixed-point `int`.** Fixed point was the tempting answer to `0.1 + 0.2`, and three
things defuse it. Constraint types expose no arithmetic, so nobody sums a `Percentage`. The percent
convention already makes the common case exact: `10.0 + 20.0` is `30.0` where `0.1 + 0.2` is not.
And fixed point must pick a precision, so it either refuses `1/3` as a percentage or rounds it
silently, and with no failure vocabulary only the silent round is available. It would also make
`.value` read `1500` for 15%, a worse ambiguity than the one being fixed. Exact decimal arithmetic
stays [`decimal`'s job](#what-not-covered).

**`of` multiplies before it divides.** 7% of 350 is `24.5` as `quantity * value / 100` and
`24.500000000000004` as `quantity * (value / 100)`, because dividing first rounds twice.

**The negative zero is cleared for printing only.** `-0.0` already equals `0.0` and hashes alike, so
equality and lookup need nothing; it is `toString` that would otherwise render `-0.0` for a churn
figure that came out flat. Same treatment as [`GeoCoordinate`](#geo-coordinate-value-type).

---

<a id="probability-constraint-type"></a>
## Probability: bounded, and both ends belong

**The only member of the group with a real range**, so it is the one that exercises what
[constraint types](#constraint-types) decided about range failures. The answer holds: one invariant,
so `null` says everything a failure enum could, and there is none.

**Both ends are included, and the open interval was the live alternative.** An impossible event has
probability `0` and a certain one `1`; that is the definition, not an edge case, and an empirical
`0/n` or an underflowing softmax lands on `0` legitimately. The `(0, 1)` reading has a real
constituency in Cromwell's rule (never assign a *prior* of exactly 0 or 1), but that is a modelling
opinion about priors rather than what a probability is, and a type that enforced it would refuse
correct input. [`isImpossible`](#probability-constraint-type) and `isCertain` report the ends the
same way [`Port`](#port-value-type) accepts `0` and names it `isWildcard`: the rule that a
classification reports and does not gate.

**One door, where [`Percentage`](#percentage-constraint-type) needs two.** The `0`-`1` range states
the convention, so there is no `15`-versus-`0.15` question left to ask and no second entry point to
disambiguate. This is the clearest evidence the two types are different shapes rather than one type
spelled twice.

**The conversion is asymmetric, which is the argument for both types.** Every probability is a
percentage, so `toPercentage` is total. Not every percentage is a probability, since an unbounded
`Percentage` covers 250% growth, so `tryFromPercentage` is partial. Both live on `Probability`:
`Percentage` shipped first and stays unaware of it, and putting the partial direction on `Percentage`
would split one pair across two files.

**A `NaN` falls out for free**, because the bound is written as `>= 0 && <= 1` rather than
`< 0 || > 1`. Same trick as [`GeoCoordinate`](#geo-coordinate-value-type)'s `_isWithin`. A `-0.0`
passes that test, so it reaches the representation and gets cleared by `positiveZeroed` for the
rendered form.

**`complement` is closed but not involutive, and that is worth knowing.** `1 - value` never leaves
`0`-`1`, verified over a million samples, so it needs no door and cannot fail. But `1 - (1 - x)` is
not `x` in IEEE: it holds for `0.25` and `0.5`, and fails for `0.1`, `0.2`, `0.3`, `0.15` and `0.29`,
about a third of ordinary values. Nothing fixes that short of a representation the package already
[rejected for `Percentage`](#percentage-constraint-type), so it is documented and asserted in the
tests rather than papered over.

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
