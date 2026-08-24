# APPENDIX — `minted_constraints`

Design rationale for the types this package ships: the "why" behind decisions the code and its
dartdoc alone don't explain. Family-wide rationale (parse-don't-validate, the failure model,
packaging, the shared rules every type leans on) lives in the [workspace APPENDIX][appendix-md];
code style in [CODESTYLE.md][codestyle-md]. Each heading carries an explicit `<a id="…">` anchor;
link by anchor, and keep anchors stable across renames.

<!-- TOC start -->

- [Typed digits: `Digit` and `Digits`](#typed-digit-subparts)
- [minted_constraints: a package for the primitives](#constraints-package)
- [Constraint types: a range, not a standard](#constraint-types)
- [Percentage: the unit is the whole point](#percentage-constraint-type)
- [Probability: bounded, and both ends belong](#probability-constraint-type)

<!-- TOC end -->

---

<a id="typed-digit-subparts"></a>
## Typed digits: `Digit` and `Digits`

The parse-don't-validate guarantee normally stops at the whole value (`Iban`, `PhoneNumber`). Where
a validated whole exposes a part that is *only* decimal digits, that part is typed as digits rather
than a raw `String`, so "these are digits" is a fact of the type instead of an assumption each
caller re-checks. Neither `Digit` nor `Digits` is a domain entity from a standard; they are the
building blocks the standard types are cut from.

**They travel both ways, and that is what makes the round trip compose.** `Isbn.prefix` and
`Imei.tac` hand back a `Digits`, and `Isbn.fromComponents` and `Imei.fromComponents` take one, so
`Imei.fromComponents(tac: imei.tac, serialNumber: imei.serialNumber)` type-checks. It did not, while
the getters returned `String` and the parameters took `Digits`: the two halves of one type disagreed
about what its parts were. Parts that are genuinely alphanumeric take
[`AsciiAlphanumerics`](#constraints-package) rather than `Digits`, which there would be a narrower
type rather than a stronger one.

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

`Digits` (a sequence) is where the representation matters. The obvious `List<Digit>` is a trap: the
element type erases, so `List<Digit>` *is* `List<int>` at runtime, one pointer-sized word per digit,
roughly eight times the bytes of the string it came from. So `Digits` is backed by a `Uint8List`:
one byte per digit, and a real `Uint8Array` on the web (where a `String` would be two-byte UTF-16).
`dart:ffi`'s fixed-width types are not an option: they are native-ABI markers for C interop, not
web-safe, and no C ABI has a sub-byte scalar, so there is nothing to pack against there.

`Digits` is an `@immutable` class, not an extension type, for two reasons. Value equality: an
extension type's `==` delegates to its representation and can't be overridden, and `Uint8List` uses
*identity* equality, so `Digits.tryFrom([1, 2])` would never equal another `Digits.tryFrom([1, 2])`;
the class hand-writes structural `==`/`hashCode` over the bytes (its first use of `package:meta`,
for `@immutable`). Encapsulation: the `Uint8List` is private, so a denser backing (nibble-packed BCD
at two digits per byte, or tighter) can replace it behind the same `Iterable<Digit>` / `operator []`
/ `asString` interface without touching callers. Packing is deferred on purpose; it only pays off at
a volume identifiers rarely reach, and the unpacked bytes read as the digits under a debugger.

---

<a id="constraints-package"></a>
## minted_constraints: a package for the primitives

**Why a package and not more of core.** `Char` and `Letter` are grapheme-based and need
[`package:characters`](https://pub.dev/packages/characters). Core keeps its `collection` + `meta`
diet, and a consumer wanting typed primitives takes one package without ever meeting `ParseOutcome`:
measured, nothing in `numerics/` or `quantities/` imported the outcome machinery. The cost is a
major, since core cannot re-export a sibling (that edge is a cycle pub refuses), so the moved types
left `package:minted/minted.dart`. Breakage is a fact to state, not an argument to decide with.

**`Char` is one grapheme cluster, not one code unit or code point.** A skin-toned thumbs-up is two
code points, a flag two, a joined family five, and each fills one slot, so `length == 1` refuses all
three. It also *admits* half a surrogate pair, which is why `Char` carries an explicit
unpaired-surrogate guard: `characters` counts a lone surrogate as one grapheme too. Control
characters and CRLF are single graphemes and stay admitted, since excluding them would invent a rule
the concept lacks.

**Two letter families, because one type cannot do both jobs.** A Danish initial is `Ø` and a Polish
one `Ł`, so `AsciiLetter` cannot serve human text; `[A-Za-z]` is exactly what ISO 9362 and the IBAN
registry fix, so `Letter` cannot serve the codes. Unprefixed means Unicode throughout.

**The plurals are extension types over `String`, where [`Digits`](#typed-digit-subparts) is an
`Iterable`.** An `int` cannot hold `007`, and `Isbn.tryParse('0306406152')` is a real ISBN whose
body starts with a zero, so digits need a sequence, and a `Uint8List` gives reference equality. A
`String` has neither problem, and each element is one grapheme or one code unit, so concatenation is
reversible: measured, `'a' + ZWJ + 'b'` stays two graphemes, UAX #29 joining across ZWJ only for
emoji. Text should print and compare as text; `Digits` should not.

**The singular narrowings are declared, the plural ones are not.** `AsciiLetter implements
AsciiAlphanumeric, Letter` and up the chain, so a letter passes wherever a character is wanted.
`AsciiLetters` is equally a `Letters`, but nothing wants BIC-code letters where initials are
expected, and declaring it would force a covariant redeclare of the element getter. Adding a
supertype later is not breaking. Note the analyser cannot check any of this: matching
representations make **any** `implements` structurally legal, so `Letters implements Letter`
compiled fine and was a lie caught by a test.

**Typing the finance parts closed a path rather than adding a check.** `Iban.fromComponents` used to
take a `String` BBAN, so junk reached `alphanumericValue` and its `-1` fallback. With
`AsciiAlphanumerics` on the door that input is unrepresentable, and `Isin`'s checksum already ran
after its charset gate, so the fallback became an `assert`.

---

<a id="constraint-types"></a>
## Constraint types: a range, not a standard

**A second category, not value types with a relaxed contract.** A constraint type is a primitive
with a constraint on it and no standard defining its text form: no checksum, no notation. Usually a
range; [`Percentage`](#percentage-constraint-type) constrains the unit instead. *Primitive*, not
*number*: the constraint need not be arithmetic, and [`Char`](#constraints-package) restricts a
`String` to one character on the same terms.

**The category is prose, not a structural check.** Nothing enforces it: `conformance_test.dart`
deliberately requires no door to *exist*, only that nothing lies about what it can do. Detecting the
category by directory was the first attempt and [`Port`][port-value-type] broke it: a network
concept buried in `quantities/` to satisfy a test puts tooling ahead of domain. So the category is
documented here, and filing follows the domain.

**No `parse(String)` door.** Decimal notation is how numbers are written, not a published format for
"a non-negative integer", so a parse door would invent a text form and then owe it forever. The
rule, *a type gets `parse(String)` only where a standard defines its text form*, is also why
[`Date`][date-value-type] keeps its door without needing an exemption.

**`tryFrom` alone, and no `from`.** The obvious shape was both, matching [`Weekday`][weekday-enum].
Rejected on reversibility: adding `from` later is a minor bump, removing it later is a major one,
and the no-implicit-throws work already schedules every `from` with a nullable sibling for deletion.
Shipping a door with a known removal date costs more than not shipping one.

**No failure vocabulary, because there is nothing to say.** One invariant per type means a failure
enum would carry a single variant meaning "out of range", which is what `null` already means. The
same reasoning caught up with `Digit`, `Digits` and `Weekday` in v2: once their throwing doors went,
their vocabularies had no producer and went too.

**Most implement their representation, which is the read side of the same bargain.** An opaque
constraint type taxes every read: `digit.value + 1`, and a re-check whenever a constrained value
meets a door wanting the primitive. `implements int` removes that and keeps every guarantee, checked
rather than assumed: a raw `int`, a sibling constraint type and a `List<int>` are each still refused
where the constrained type is wanted, and `digit + 1` yields a plain `int`, so arithmetic cannot
re-enter the type. Additive rather than breaking, the workspace having compiled unchanged when it
landed; the one edge is inference, `[digit, 7]` moving from `List<Object>` to `List<int>`.

**Two exceptions, both where an inherited member would read as a lie.** `Percentage` holds `15` for
fifteen percent, so `percentage * 200` would compute `3000` while reading as fifteen percent of 200.
`Char`, `Letter` and `Letters` guarantee characters where `length` counts code units, which for one
emoji is `2`. The five `Ascii*` types escape it, code units and characters coinciding there, and
only `AsciiChar`, `AsciiLetters` and `AsciiAlphanumerics` declare it, the other two inheriting
through the narrowing lattice.

**Two types, not one.** `Uint` (`>= 0`) and `NaturalNumber` (`> 0`) differ by a single value, and
that value is the point: an empty cart is a real count, a page size of zero is not. One type would
push the zero check back to every call site, which is the hand-checking this package deletes.

**The names are a compromise, and the dartdoc carries the fix.** `Uint` promises C semantics it does
not have, and `NaturalNumber` lands on a split convention (ISO 80000-2 counts `0` among the
naturals; school arithmetic does not). Both were chosen for familiarity over self-description, with
the exact boundary stated in each dartdoc rather than spelled into a clunkier name. The rejected
pair was `NonNegativeInt` / `PositiveInt`.

**The fixed widths are separate types, not factories.** `Uint.w8(200)` was the tempting spelling and
it does range-check correctly, but every result is still a `Uint`, so nothing stops a byte landing
in a nibble slot; the analyzer stays silent. As separate types it rejects that, which is the point.
(`Uint.4(…)` is not spellable at all: a Dart member name cannot start with a digit.)

**Widening is deferred, not impossible.** A `Uint4` currently needs `Uint8.tryFrom(nibble)` to
become a byte, which is friction in the one direction that cannot fail. One `implements` clause per
type removes it: `Uint2 implements Uint4` up through `Uint32 implements Uint`, with `NaturalNumber
implements Uint` alongside. Verified to give free widening while still rejecting every narrowing,
every unbounded-to-fixed hop, and byte-to-natural. Held until #33's `Port` supplies a first real
caller rather than a guess at one.

**A width is not a domain, which is a rule about use rather than an argument against the types.**
`Uint16` says how many bits a value fits in, not what it means, so two unrelated domains of the same
width are interchangeable: a port and an IPv6 hextet are both `0`-`65535`. Reach for a `UintN` for
an actual machine field; a concept with a bound of its own gets its own named type, which may check
against a width but is never an alias for one.

**No `Uint64`.** Dart ints are JS doubles on the web, so the honest ceiling is 2^53-1 and a type
advertising 2^64-1 could not keep the promise its name makes. The family stops at 32.

**Neither `binary` nor `fixnum` could stand in.** [`binary`](https://pub.dev/packages/binary) has
the right shape and even the same `static Uint8? tryFrom(int)`, but that is one door out of seven:
in a release build `Uint8(999)` wraps to `231` and `fromUnchecked(999)` yields a `Uint8` holding
`999`, because `debugCheckFixedWithInRange` is assert-only and "in release mode, these assertions
are always disabled and cannot be enabled". Re-exporting it would ship four unvalidated public
doors, one of them the default constructor. [`fixnum`](https://pub.dev/packages/fixnum) is a
different job entirely: `Int32` / `Int64` only, no unsigned type at all, and wrapping arithmetic is
its documented feature rather than a hazard. Neither carries a `Uint2` or `Uint4`.

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
stays [`decimal`'s job][what-not-covered].

**`of` multiplies before it divides.** 7% of 350 is `24.5` as `quantity * value / 100` and
`24.500000000000004` as `quantity * (value / 100)`, because dividing first rounds twice.

**The negative zero is cleared for printing only.** `-0.0` already equals `0.0` and hashes alike, so
equality and lookup need nothing; it is `toString` that would otherwise render `-0.0` for a churn
figure that came out flat. Same treatment as [`GeoCoordinate`][geo-coordinate-value-type].

---

<a id="probability-constraint-type"></a>
## Probability: bounded, and both ends belong

**The only member of the group with a real range**, so it is the one that exercises what [constraint
types](#constraint-types) decided about range failures. The answer holds: one invariant, so `null`
says everything a failure enum could, and there is none.

**Both ends are included, and the open interval was the live alternative.** An impossible event has
probability `0` and a certain one `1`; that is the definition, not an edge case, and an empirical
`0/n` or an underflowing softmax lands on `0` legitimately. The `(0, 1)` reading has a real
constituency in Cromwell's rule (never assign a *prior* of exactly 0 or 1), but that is a modelling
opinion about priors rather than what a probability is, and a type that enforced it would refuse
correct input. [`isImpossible`](#probability-constraint-type) and `isCertain` report the ends the
same way [`Port`][port-value-type] accepts `0` and names it `isWildcard`: the rule that a
classification reports and does not gate.

**One door, where [`Percentage`](#percentage-constraint-type) needs two.** The `0`-`1` range states
the convention, so there is no `15`-versus-`0.15` question left to ask and no second entry point to
disambiguate. This is the clearest evidence the two types are different shapes rather than one type
spelled twice.

**The conversion is asymmetric, which is the argument for both types.** Every probability is a
percentage, so `toPercentage` is total. Not every percentage is a probability, since an unbounded
`Percentage` covers 250% growth, so `tryFromPercentage` is partial. Both live on `Probability`:
`Percentage` shipped first and stays unaware of it, and putting the partial direction on
`Percentage` would split one pair across two files.

**A `NaN` falls out for free**, because the bound is written as `>= 0 && <= 1` rather than `< 0 || >
1`. Same trick as [`GeoCoordinate`][geo-coordinate-value-type]'s `_isWithin`. A `-0.0` passes that
test, so it reaches the representation and gets cleared by `positiveZeroed` for the rendered form.

**`complement` is closed but not involutive, and that is worth knowing.** `1 - value` never leaves
`0`-`1`, verified over a million samples, so it needs no door and cannot fail. But `1 - (1 - x)` is
not `x` in IEEE: it holds for `0.25` and `0.5`, and fails for `0.1`, `0.2`, `0.3`, `0.15` and
`0.29`, about a third of ordinary values. Nothing fixes that short of a representation the package
already [rejected for `Percentage`](#percentage-constraint-type), so it is documented and asserted
in the tests rather than papered over.

[appendix-md]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md
[codestyle-md]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md
[date-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_chronology/APPENDIX.md#date-value-type
[geo-coordinate-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_geography/APPENDIX.md#geo-coordinate-value-type
[port-value-type]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_network/APPENDIX.md#port-value-type
[weekday-enum]: https://github.com/LahaLuhem/minted/blob/main/packages/minted_chronology/APPENDIX.md#weekday-enum
[what-not-covered]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md#what-not-covered
