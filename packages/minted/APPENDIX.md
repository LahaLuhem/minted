# APPENDIX — `minted`

Design rationale for the types this package ships. Family-wide rationale lives in the
[workspace APPENDIX][appendix-md], code style in [CODESTYLE.md][codestyle-md]. Link by the explicit
`<a id="…">` anchors and keep them stable across renames.

<!-- TOC start -->

- [Why the thrown type is an `Error`](#why-typed-format-exception)
- [A throw is for a claim you made in source, and you have to type it](#claim-in-source)
- [Why a bespoke `ParseOutcome`, not `Either`](#parse-outcome)
- [Failures are per type, because standards are](#per-type-failures)

<!-- TOC end -->

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
core guarantee (see [CODESTYLE class structure][class-structure]).

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
the *engine* versus *adapter* line in [hard rule 7][hard-rules].

**FP interop is three lines in the consumer's own app**, not a companion package:

```dart
extension RibsOutcome<F extends MintedFailure, T> on ParseOutcome<F, T> {
  Either<F, T>       get either    => fold(Either.left, Either.right);
  ValidatedNel<F, T> get validated => fold(Validated.invalidNel, Validated.validNel);
}
```

**Why no third state.** Folding the assembly-factory failure in as a third variant, so nothing ever
throws, crosses the [claim-in-source](#claim-in-source) line, loses the stack trace exactly where it
is the only useful diagnostic, and is viral upward: every function building a `Date` would return
the three-state type. Java's checked exceptions, same failure mode.

**Why the constructors are public.** `ParseOutcome` protects no invariant, since building a
`ParseSuccess(iban)` requires already holding an `Iban`, which only parsing produces. The sealed
base and `final` arms still stop anyone adding a third state, and public `const` constructors buy
consumer test fixtures for nothing.

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
handles family-level variation everywhere else: `Iban.checkDigits`, `Email.mailtoUri` and
`Uuid.bytes` have nothing in common either.

**A variant earns its place by changing what the user does next.** "Checksum failed" means *you
mistyped, look again*; "unknown country" means *we do not support this, stop*; "too short" means
*keep typing*. Three remedies, three variants. "Bad character at index 7" versus "at index 9" is one
remedy, so one variant.

**The engine sets the ceiling, and we do not guess past it.** `email_validator` exposes a single
`bool`, so `Email` gets exactly one variant; a heuristic guess at "invalid domain" would be a
fabricated diagnosis wearing a type name, and honestly silent beats confidently wrong. `PhoneNumber`
is nearly the same story, since only one of `phone_numbers_parser`'s five codes is ever thrown.
`Iban` is the opposite extreme, handed a five-way diagnosis for free.

**Sealed or enum, decided by when the payload is known.** Enum where every variant's data is a
declaration-time constant or absent; sealed where any variant carries something derived from the
input (`IbanInvalidLength(expected, actual)`, `DateDayOutOfRange`'s leap-aware bound). The second
prong is about *timing*, not shape: an enhanced enum's payload is fixed at declaration.

**Why `tryParse` still returns `T?`.** Replacing it with the outcome would kill `??`, `?.`,
`whereType<Iban>()` and collection-`if` for every caller who only ever wanted the null, and deriving
one door from the other costs nothing.

[appendix-md]: https://github.com/LahaLuhem/minted/blob/main/APPENDIX.md
[class-structure]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md#class-structure
[codestyle-md]: https://github.com/LahaLuhem/minted/blob/main/CODESTYLE.md
[hard-rules]: https://github.com/LahaLuhem/minted/blob/main/.ai/AGENTS.md#hard-rules
