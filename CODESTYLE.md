Library-package code style. Project facts (goal, stack, repo layout, hard rules) live in
[`.ai/AGENTS.md`](./.ai/AGENTS.md); design rationale lives in [`APPENDIX.md`](./APPENDIX.md).

The lint posture is deliberately strict (see [`analysis_options.yaml`](./analysis_options.yaml)).
The house style values explicit types, no ambient mutability, small focused types, and a
single consistent shape across every value type in every package.

Each heading below carries an explicit `<a id="…">` anchor. Link by anchor, not by heading
text, so renames don't break callers.

<!-- TOC start -->

- [Type safety & nullability](#type-safety)
- [Naming](#naming)
- [Formatting](#formatting)
- [Constants & magic numbers](#constants)
- [Class structure](#class-structure)
- [The value-type contract](#value-type-contract)
- [Idioms](#idioms)
- [Comments & dartdoc](#dartdoc)
- [DCM rules (applied by hand)](#dcm-rules)
- [Test style](#test-style)
- [Documentation conventions (Markdown)](#documentation-conventions)
- [Shell scripts](#shell-scripts)

<!-- TOC end -->

<a id="type-safety"></a>
## Type safety & nullability

- **Type-annotate every public symbol.** Inference is fine on locals
  (`omit_local_variable_types` is on); public surfaces are not the place to rely on it.
- **`final` by default for fields and locals.** `prefer_final_fields`, `prefer_final_locals`,
  `prefer_final_in_for_each` are all on. Parameters are not required to be `final`, consistent
  with `avoid_final_parameters` and `parameter_assignments` (which forbids the actual bad
  behaviour: mutating a parameter inside the body).
- **Nullability is explicit.** Use `T?` everywhere a value can be missing. `cast_nullable_to_non_nullable`
  is on, so `as T` on a `T?` fails lint. In this package the canonical "value can be missing"
  path is `tryParse`, which returns `T?`; never reach for a cast to launder that nullability away.
- **No Java ceremony.** No getter-only abstract base classes, no `AbstractFooFactory`, no
  interface-per-class. Use extension types, immutable classes, sealed classes, records, and
  enums where they add clarity, not weight.

The `dynamic`-escape-hatch ban and the `print()`-in-library ban are contracts, not style; they
live under [*Hard rules* in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules).

---

<a id="naming"></a>
## Naming

- **Capitalise standard acronyms as words in type names.** Effective-Dart and the
  `camel_case_types` lint want `Iban`, `Bic`, `Isbn`, `Ean`, `Gtin`, `Mac`, not `IBAN` / `BIC`.
  Two-letter acronyms stay fully capitalised (`ID`, `IO`). This is the one place the package
  deliberately does not spell the standard out: the type name is the well-known identifier.
- **Expand abbreviations everywhere else.** In code, comments, docstrings, and messages,
  spell novel domain terms out (`checkDigits`, not `chkDig`; `countryCode`, not `cc`).
  Widely-known protocol initialisms inside prose (HTTP, DNS, RFC, ISO) stay as-is.
- **Local variables carry a concise type-suffix.** A reader without IDE inlay-hints can't see
  an inferred type; the name has to do that work. When a domain type exists, the suffix is the
  type name (`parsedIban`, not `parsed`; `candidateDigits`, not `candidate`). Callback and
  comparator parameters are exempt and stay single-word (`input`, `digit`, `(a, b)`), because
  the call site already pins the type.
- **In a multi-stage pipeline, name each callback parameter for what the value has *become*.**
  The exemption above rests on the type being recoverable at the call site; in a chain the type
  never changes, so what a reader cannot recover is which filters have already run
  (`candidateRange` → `placeableRange` → `claimingRange` in `PaymentCardNumber.cardSchemesOf`).
  Well worth the small noise, and reuse the surrounding dartdoc's words where it has them.

```dart
// Prefer:
final normalisedInput = input.trim().toUpperCase();
final countryCode = normalisedInput.substring(0, 2);

// Over:
final s = input.trim().toUpperCase();
final cc = s.substring(0, 2);
```

---

<a id="formatting"></a>
## Formatting

- **Wrap text-file content at 100 columns.** [`.editorconfig`](./.editorconfig) is authoritative;
  Markdown, Dart, and YAML share the same cap. The formatter's `page_width: 100` in
  `analysis_options.yaml` matches it; keep them aligned if either moves. Dartdoc `///` prose is the
  exception: the formatter never reflows comments, so soft-wrap it roughly, for smooth break-less
  reading, rather than hard-capping at 100.
- **Blank lines separate logical chunks within a method.** Group the guard checks, the
  normalisation, the validation, and the return with one blank line between groups, so a reader
  can scan past chunks they don't need.
- **Prefer expression bodies** (`prefer_expression_function_bodies`) and **single quotes**
  (`prefer_single_quotes`). Parsing factories are frequently one expression; write them as one.

---

<a id="constants"></a>
## Constants & magic numbers

- **No magic numbers in `lib/` code.** Pull constants to named `static const`s with a
  descriptive identifier: `Iban` length bounds, the Luhn radix, ISO table sizes, and so on.
- **Keep a type's own constants on that type.** A check-digit modulus or a fixed field width
  belongs as a `static const` on the type that uses it, close to where it is read. Genuinely
  cross-package constants (shared radices, a shared alphabet) go in core's `lib/src/shared/`; one
  that only a single package reads goes in that package's own helper subfolder (AGENTS.md, repo
  layout). Before introducing a new constant, check whether a shared one already exists.

---

<a id="class-structure"></a>
## Class structure

- **Fields, then constructors, then other members.** A reader scans the state shape first, then
  how to construct it, then how to use it. Unnamed constructor first, then named/factory
  (matches `sort_unnamed_constructors_first`); static members (including `tryParse` / `parse`)
  after the instance members. This applies to both shapes: extension types and immutable classes.
- **`assert` for dev-time errors, `throw` for runtime ones.** A constraint a caller can see
  violated during development (a private helper handed a negative index) belongs in `assert`:
  stripped in release, zero runtime cost. Parsing untrusted input is a genuine runtime condition,
  so a failed parse is a `throw` (see [the value-type contract](#value-type-contract)), never an
  `assert`. Prefer init-list asserts (`prefer_asserts_in_initializer_lists`,
  `prefer_asserts_with_message` are both on).
- **Multi-part value types override `toString`.** An immutable class returns
  `'ClassName(field1: value1, field2: value2)'`. The default `Instance of 'ClassName'` is hostile
  in logs and test failures. Extension types are the exception and cannot do this: see the next
  section.

---

<a id="value-type-contract"></a>
## The value-type contract

This is the headline convention: every type in the package presents the **same** surface, so a
consumer learns one shape and applies it everywhere. Rationale is in
[`APPENDIX.md#parse-dont-validate`](./APPENDIX.md#parse-dont-validate).

**Two representations, one contract.** The deciding question is **not how many primitives the value
spells, but whether its parts are already types this package models**. Where they are, hold them:
composing from types that carry their own invariants is safer than re-deriving those invariants out
of text on every accessor, and it is what makes a part impossible to pass in the wrong slot. `Digits`
sets the pattern by being an `Iterable<Digit>` rather than an extension type over its characters, and
`Cidr` follows it by holding an `IpAddress` and a prefix length rather than slicing `10.0.0.0/8`
apart on demand. Reach for an extension type when the value has **no inner structure worth naming**.
Rationale: [`APPENDIX.md#compose-from-modelled-parts`](./APPENDIX.md#compose-from-modelled-parts).

- **No modelled parts → extension type** over the one primitive, zero runtime cost, private
  primary constructor:

  ```dart
  extension type const Iban._(String value) {
    /// null when [input] is not a well-formed IBAN (length, country, mod-97 check).
    static Iban? tryParse(String input) => parse(input).getOrNull();

    /// The value, or the [IbanFailure] saying which check it failed. Never throws.
    static ParseOutcome<IbanFailure, Iban> parse(String input) {
      final normalised = unspacedUpperCase(input);
      final failure = _failureFor(normalised);

      return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalised));
    }

    String get countryCode => value.substring(0, 2);
    // … further sub-part getters and render helpers …
  }
  ```

- **Modelled parts, or several parts → immutable class** holding them, private primary
  constructor, hand-written `==` / `hashCode` / `toString`:

  ```dart
  @immutable
  final class GeoCoordinate {
    final double latitude;
    final double longitude;

    const GeoCoordinate._(this.latitude, this.longitude);

    static GeoCoordinate? tryParse(String input) => parse(input).getOrNull();
    static ParseOutcome<GeoCoordinateFailure, GeoCoordinate> parse(String input) { /* ISO 6709 */ }

    String get iso6709 => /* canonical string form */;

    @override
    bool operator ==(Object other) =>
        other is GeoCoordinate && other.latitude == latitude && other.longitude == longitude;
    @override
    int get hashCode => Object.hash(latitude, longitude);
    @override
    String toString() => 'GeoCoordinate(latitude: $latitude, longitude: $longitude)';
  }
  ```

  This one ships: [`lib/src/geography/geo_coordinate.dart`](./packages/minted_geography/lib/src/geo_coordinate.dart)
  is the sketch filled in, so keep the two in step.

**A second reason to reach for a class, independent of the parts: a delegated `Object` member would
be wrong for the type.** The delegation an extension type gives you is a feature only while the
inherited behaviour is the wanted one. `Digits` needs structural `==` that its `Uint8List` will not
give, and `PaymentCardNumber` needs a `toString` that does not print the card. Rationale:
[`APPENDIX.md#payment-card-number-value-type`](./APPENDIX.md#payment-card-number-value-type).

**The rule is about the parts a caller sees, not the representation.** `Isbn` and `Imei` are
`String`-backed and hand back `Digits` from their digit-segment getters, which is what makes the
round trip compose without either type giving up its zero-cost representation or its `print` form.
Every other shipped type is correctly an extension type over text: `Iban`'s `bban`, `Isin`'s `nsin`
and `Bic`'s codes are alphanumeric with no type to become; `Hostname` and `DnsName` labels have none
either, since a label's validity depends on its position; `Email.domain` is not always a hostname
(an address literal and an IDN are both valid); and `IpAddress.octets` is a `Uint8List`, which
already enforces `0`-`255`. Rationale for each:
[`APPENDIX.md#compose-from-modelled-parts`](./APPENDIX.md#compose-from-modelled-parts).

**Non-negotiable across both shapes:**

1. **Private constructor** (`._`). There is no public way to build an instance except
   through parsing, so any instance that exists is well-formed. Never add an *unvalidated* public
   constructor; it would break the guarantee the whole package sells. (*Primary constructor* has
   named a Dart language feature since 3.13, which this package does not use, so this rule is about
   privacy, not syntax. See [`APPENDIX.md#sdk-floor`](./APPENDIX.md#sdk-floor).) A validated named
   factory (`fromComponents`, `fromBody`) that assembles caller-supplied parts and runs the same
validation before `._` is fine: it's a parsing entry point keyed on parts, not a raw constructor, so
the guarantee holds.
2. **`static ParseOutcome<F, T> parse(String input)`** is the primary door and never throws: it
   returns the value or the type's own [`MintedFailure`](./APPENDIX.md#per-type-failures). It does
   the work; the other two derive from it.
3. **`static T? tryParse(String input)`** is `parse(input).getOrNull()`, so the two can't diverge.
   It stays nullable because `??`, `?.` and `whereType` are worth a dedicated path.
4. **No door throws.** Assembly factories (`fromComponents`, `fromBody`, `fromBytes`, `Date.of`)
   return the same `ParseOutcome` as `parse`, so a caller sees in the signature that the parts can
   be refused. `ParseOutcome.getOrThrow` is the single door that throws, and only because a caller
   typed it: that is them asserting, and a violated assertion raises `MintedFormatError`, an `Error`
   because it is a bug in their source rather than input to handle. Rationale:
   [`APPENDIX.md#claim-in-source`](./APPENDIX.md#claim-in-source).
   **Their parameters take the package's own types, not raw primitives.** A part that is only ever
   decimal digits is a `Digits`; a part that is genuinely alphanumeric, like an IBAN's `bban`, stays
a `String`, because `Digits` there would be the wrong type rather than a stronger one. That also
makes the round trip compose: `Imei.fromComponents(tac: imei.tac, …)` type-checks, because the
getter hands back what the factory takes. Rationale:
   [`APPENDIX.md#typed-digit-subparts`](./APPENDIX.md#typed-digit-subparts).
   **A `Digits` reads as `Digits(978)` when interpolated**, not `978`, since it hand-writes
`toString`. Interpolating one is silent (no diagnostic), so reach for `.asString` in any rendered
output.
5. **Value equality.** Extension types inherit it from the representation for free (see below);
   classes hand-write `==` + `hashCode` over their parts. No `Equatable` dependency.
6. **A canonical string form.** `.value` for extension types (the representation), a named getter
   (`.iso6709`, `.formatted`) for classes.
7. **A failure vocabulary**, in the sector's `failures/` directory: one type per value type,
   implementing `MintedFailure`, sized to what its standard can actually distinguish.

**Classifications are not value types.** A closed set a value type *hands back* (`Weekday`,
`UuidVariant`, `PhoneNumberType`) is a plain `enum`, not a contract-bearing type: it is derived from
something that already parsed rather than parsed from text, so it gets named cases and an exhaustive
`switch` instead of `parse` / `tryParse`. Add `from` / `tryFrom` when callers need to build one from
a primitive, and a failure type only if one of those throws. `conformance_test.dart` holds the line
both ways: a class or extension type without both doors fails, and so does an enum that declares
either. Rationale: [`APPENDIX.md#weekday-enum`](./APPENDIX.md#weekday-enum).

**Constraint types are not value types either.** The rule that separates them is about standards,
not numbers:

> A numeric type gets a `parse(String)` door only where a **standard** defines its text form.

`Date` keeps `parse` because ISO 8601 defines `YYYY-MM-DD`. A constrained number has no such
standard, so a parse door would invent one, whether the constraint is a range (`Uint`, `Port`) or a
unit (`Percentage`, which bounds nothing but finiteness). They declare `tryFrom` and neither parse
door, and `conformance_test.dart` names them in `_constraintTypes`. One invariant each leaves
nothing a failure could say that `null` doesn't, so they carry none. A type still files by domain:
`Port` sits in `network/`, not `quantities/`. Rationale:
[`APPENDIX.md#constraint-types`](./APPENDIX.md#constraint-types).

**Normalise on parse.** `tryParse` converts input to a single canonical form before constructing
(trim, case-fold the parts the standard says are case-insensitive, strip separators). Because
extension-type equality is representation equality, this is what makes
`Iban.tryParse('gb82 west …') == Iban.tryParse('GB82WEST…')` true. Document each type's
normalisation in its dartdoc. See [`APPENDIX.md#normalise-on-parse`](./APPENDIX.md#normalise-on-parse).

**Extension-type facts you must design around** (verified against the analyzer, not assumed):

- You **cannot** redeclare `toString`, `==`, or `hashCode` on an extension type; they always
  delegate to the representation. For a `String`-backed type this is a feature: `print(iban)`
  shows the IBAN, and equality is canonical-string equality. Do not fight it; do not try to
  make an extension type print `Iban(...)`. Where you genuinely need the member the delegation
  denies you, that is the signal to reach for a class, per the carve-out above.
- An `implements` clause only accepts **supertypes of the representation**. `implements Comparable<String>`
  is legal for a `String`-backed type; `implements Comparable<Iban>` is not. If you need ordering,
  expose a plain `int compareTo(T other)` method rather than the `Comparable` interface.
- At runtime the instance **is** the representation (`iban is String` is true). There is no
  runtime type discrimination between an `Iban` and a plain `String`. This is why serialization
  is explicit and opt-in (a `fromJson` that calls `parse`), never reflection-based.

**Check the real standard, not a shape.** Where a standard defines a checksum (IBAN mod-97, card
Luhn, ISBN/EAN/ISSN check digits), validate it. A regex that only checks the shape is a bug, not
a simplification. See [`APPENDIX.md#check-digits-not-regex`](./APPENDIX.md#check-digits-not-regex).

---

<a id="idioms"></a>
## Idioms

<a id="idioms-uri-construction"></a>
### `Uri.https(…)` / `Uri.http(…)` over `Uri.parse(…)` for known URLs

For a compile-time-known URL, use the named constructor and pass path / query as separate
arguments. Component-wise construction makes host, path, and query visible at a glance and
short-circuits the typos `Uri.parse` silently accepts. `Uri.parse` stays the right tool for
runtime input (a user-supplied string, a value being parsed).

```dart
// Prefer:
Uri(scheme: 'mailto', path: value)            // Email.mailtoUri
Uri.https('example.com', '/path', {'q': '1'})
// Over:
Uri.parse('https://example.com/path?q=1')
```

<a id="idioms-unmodifiable-collections"></a>
### `List.unmodifiable(…)` over `UnmodifiableListView(…)`

Default to `List.unmodifiable(…)` (and `Set`/`Map` equivalents) for exposing an immutable
collection, e.g. an embedded ISO table or a type's set of known values. The constructor copies
(snapshot semantics); the `…View` only wraps, so anyone still holding the underlying list can
mutate it and the view silently follows. Reach for `UnmodifiableListView` only when you
specifically want a read-through view of private mutable state.

<a id="idioms-fixed-length-lists"></a>
### `toList(growable: false)` when the length is already final

A list built from a finished iterable and never appended to is fixed-length, so say so:
`toList(growable: false)`, not `toList()`. Same reasoning as the neighbouring rules, the type
states a fact about the value. `add` on one throws `UnsupportedError`, which turns a wrong
assumption into a failure at the mutation rather than a silent extra element.

Measured on this SDK (2000 elements, 20k repetitions, AOT), creation is about 16% cheaper: a
growable list carries a wrapper around its backing array and can over-allocate. Indexing is
indistinguishable, so this is about intent first and allocation second.

```dart
// Prefer:
final members = packages.map(_memberDir).toList(growable: false)..sort();

// Over (nothing appends to it, and `sorted()` hands back a growable list):
final members = packages.map(_memberDir).sorted();
```

`sort()` stays available: it assigns elements without resizing, which a fixed-length list allows.
Keep `toList()` where the collection genuinely grows afterwards, e.g. a recorder that accumulates.
Where the collection is *returned* and callers should not mutate it at all, prefer
[`List.unmodifiable`](#idioms-unmodifiable-collections), which also blocks `[i] =`.

<a id="idioms-collection-type-by-semantics"></a>
### Pick the collection type by semantics, not by habit

An embedded table whose order is never consulted and whose rows are unique is a `Set`, not a
`List`, even when the access pattern is a predicate scan rather than `contains` (so the `Set` buys
nothing at lookup). The type states the two facts, and a `const` `Set` turns a duplicated row into
`equal_elements_in_const_set` at compile time, where a `List` would quietly scan it twice. Records
are legal elements: they carry structural equality without overriding `==`, so the const-set
restriction doesn't apply. `Isbn._booklandPrefixes` and `PaymentCardNumber._schemeRanges` are both
`Set`s on that reasoning.

<a id="idioms-collection-literals"></a>
### Collection-`for` / collection-`if` over `Iterable.map(…).toList()`

When building a literal collection (an embedded code table, a set of test vectors), a literal
with embedded control flow reads as data and drops the `<T>` annotations the literal context
already infers. Keep `.map(...)` for genuine pipelines.

**The tell is whether the collection survives.** A literal that exists only to be `.join`ed or
folded away on the next line was never data: it is a pipeline wearing a literal's brackets, and it
materialises a list nobody reads.

```dart
// bad: built, then thrown away one call later
String get formatted => [
  for (var start = 0; start < _length; start += _groupSize)
    value.substring(start, start + _groupSize),
].join(' ');

// good
String get formatted => Iterable.generate(
  _length ~/ _groupSize,
  (group) => value.substring(group * _groupSize, (group + 1) * _groupSize),
).join(' ');
```

A literal handed to a constructor that needs a `List` (`Uint8List.fromList([for …])`) is the other
case and stays: there the collection *is* the result.

<a id="idioms-functional-pipelines"></a>
### Functional pipelines over imperative loops for lookup and transform

When the code *maps around data* (find one, select many, transform, reduce), prefer a functional
pipeline (`firstWhereOrNull`, `where`, `map`, `fold`, `any` / `every`, several from
[`package:collection`](https://pub.dev/packages/collection)) over a hand-written `for` loop. The
pipeline reads as the data's journey, top to bottom; the loop hides it in accumulate-and-return
bookkeeping.

```dart
// Prefer:
return IsoCode.values.firstWhereOrNull((code) => code.name == upperRegion);

// Over:
for (final code in IsoCode.values) {
  if (code.name == upperRegion) return code;
}
return null;
```

This complements, rather than contradicts, the two neighbouring rules: build a *literal*
collection with a collection-`for` (not `map(…).toList()`), and do *side effects* with a plain
`for` loop (never `forEach` with a closure, `avoid_function_literals_in_foreach_calls`). The
pipeline is for the lookup / transform case, where it makes the types' path clearest.

**Generate by index; reduce lazily.** Two shapes of this rule are worth naming, because the
imperative version is the tempting default. For a value *derived by index*, reach for
`Iterable.generate(count, (i) => …)` over a `for (var i = …; i++)` loop with a mutable cursor. For a
*transform reduced to one result*, let `.map(…)` feed the reducer (`.join()`, `.fold(…)`, `.any(…)`)
rather than filling a list and reducing that. Both stay lazy: no intermediate collection is
allocated, there is no cursor or accumulator to track, and each element reads as a pure function of
its input.

```dart
// Prefer (lazy, no intermediate list; each group is a pure function of its index):
String _grouped(Uint8List bytes) => Iterable.generate(
  _groupByteBoundaries.length - 1,
  (group) => hexDigits(
    bytes.getRange(_groupByteBoundaries[group], _groupByteBoundaries[group + 1]),
  ),
).join('-');

// Over (a mutable cursor and an accumulator list built only to be joined):
String _grouped(Uint8List bytes) {
  final groups = <String>[];
  var offset = 0;
  for (final length in _groupByteLengths) {
    groups.add(hexDigits(bytes.sublist(offset, offset + length)));
    offset += length;
  }
  return groups.join('-');
}
```

The terminal decides it. When the pipeline ends in a *reduction* to one value (`join`, `fold`,
`any`), it never materialises a collection, so it beats building one. When the result genuinely
*is* a materialised collection (`Uint8List.fromList([for …])`, an embedded table), the
collection-`for` stays: it is the direct literal form, and a `generate(…).toList()` /
`map(…).toList()` only bolts on a `.toList()` that reads awkwardly and saves nothing (the collection
is built either way). So `hexBytes` (which returns a `Uint8List`) keeps its collection-`for`, while
`Uuid.fromBytes` (which reduces to a `String`) uses the lazy pipeline.

**Read that carve-out narrowly: it covers a *literal*, where every element is written out and
nothing is derived.** The moment the elements come from *selecting or projecting* another
collection, the chain wins even though the terminal materialises. Each step then names one
transformation, and nothing is built until the end.

```dart
// Prefer (each step one transformation, its parameter named for what survived the last;
// nothing is built until the terminal):
return Set.unmodifiable(
  _schemeRanges
      .where((candidateRange) => candidateRange.digits <= input.length)
      .map((placeableRange) => placeableRange.scheme),
);

// Over (the filter buried in an `if`, and the set filled element by element):
return Set.unmodifiable({
  for (final range in _schemeRanges)
    if (range.digits <= input.length) range.scheme,
});
```

How far to split the chain is a judgement call, not a rule: sometimes one predicate per `where`
reads best, sometimes several conditions belong in one. Take whichever is cleaner and quieter.

**Group at the source, don't flatten and re-split.** The pipeline should build the final shape
directly. `Uuid.fromBytes` groups the *bytes* and hex-encodes each group, rather than hex-encoding
everything into one 32-character string and slicing that back apart: the flat string would exist
only to be taken apart again, and `getRange` keeps each group lazy.

<a id="idioms-parts"></a>
### `part` / `part of` only when structurally needed

Legitimate uses: sealed-class cases across files (Dart requires the same library for sealed
subtypes), code-generation outputs (`*.g.dart`). Avoid it for general organisation; imports are
explicit, and parts leak `_private` symbols across files. Each value type is one file under
`lib/src/`, with its failure vocabulary in a sibling `failures/` file, and neither needs `part`: a
sealed hierarchy kept whole in one file already shares a library. Where a failure looks like it
needs `part` to reach its value type's privates, move the shared piece to `shared/` instead.

<a id="idioms-dot-shorthands"></a>
### Static dot shorthands (Dart 3.10+, so stable at the floor)

Where the context type is known, drop the leading type name; the analyzer resolves the member
from the parameter, return, or variable type. This covers enum values in patterns and argument
slots, and named constructors / static factories in a return or context slot.

```dart
// enum value in a switch arm — context type is the wrapped engine's error enum (Iban._failureFor):
return switch (validationResult.error) {
  .emptyInput || .tooShort => const IbanTooShort(),
  .invalidCharacters => const IbanInvalidCharacters(),
  // … one arm per error the engine reports
};

// enum value in a record field of a typed const table, and in a `??` slot (PaymentCardNumber):
static const _schemeRanges = <_SchemeRange>[(scheme: .visa, digits: 1, from: 4, to: 4)];
CardScheme get cardScheme => cardSchemes.singleOrNull ?? .unknown;
```

Skip it where the context type isn't obvious without re-reading, or where it hurts readability.
When a prefix disappears from a file entirely, drop it from any `show` clauses too. Note this is
stable at the floor; primary (declaring) constructors are a separate feature, stable since 3.13 but
still not used, because `public_member_api_docs` cannot be satisfied on one (see
[`APPENDIX.md#sdk-floor`](./APPENDIX.md#sdk-floor)).

---

<a id="dartdoc"></a>
## Comments & dartdoc

Public symbols carry `///` dartdoc that explains *why* and *what guarantee*, not the mechanical
*what*: the type already says that. `public_member_api_docs` is on (see
[hard rule 4 in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules)). For every type, document its
normalisation and **link** the standard it enforces (with the clause or edition where it helps),
preferring a freely-readable URL (an RFC); where the standard is paywalled (ISO), link a reliable
free reference. The link lives in the dartdoc, which renders on pub.dev and travels with the type,
not a central table.

**Aim for one or two lines.** A guideline, not a cap: an explanation that earns its length keeps it,
and a decision a reader would otherwise question is worth the sentence. What doesn't earn it is
restating the signature, or rationale that belongs in [`APPENDIX.md`](./APPENDIX.md) behind a
one-line pointer. Surplus lines are noise the next reader pays for and they bury the comment that
mattered, so trim the neighbours whenever you edit a file.

Gloss a component whose standard term is jargon with its common-usage alias, so the getter is
self-explaining: `Email.localPart` notes it's the mailbox name (often a username), `Iban.bban` the
bank-specific part. Skip the gloss where the term is already plain (`domain`, `countryCode`).

### `@docImport` for dartdoc-only references

When a file needs a symbol only for `[Name]` references in dartdoc, use Dart's dartdoc-only
directive rather than a real `import`; a regular import declares a runtime dependency and makes
the import graph lie.

```dart
/// @docImport 'iban.dart';
library;
```

---

<a id="dcm-rules"></a>
## DCM rules (applied by hand)

`dart analyze` does not run these, but the project treats them as non-negotiable:

- **`no-empty-block`** — every block must contain code or a `// TODO(handle): …` explaining the
  gap. Empty `catch` clauses are excused.
- **`newline-before-return`** — separate a block-final `return` from a preceding non-return
  statement with one blank line. Inline guards (`if (cond) return null;`) do not need it.
- **`prefer-commenting-analyzer-ignores`** — every `// ignore:` needs an adjacent `//`
  explanation (dartdoc `///` does not count).

---

<a id="test-style"></a>
## Test style

- **`package:test` with `package:checks`.** Assertions use `checks` (`check(x).equals(…)`,
  `.isNull()`, `.throws<…>()`), matching every suite in the package; not `package:matcher`'s
  `expect`.
- **Behavioural framing comes from a local helper, not a framework.**
  [`test/support/bdd.dart`](./packages/minted/test/support/bdd.dart) is a small Gherkin vocabulary over
  `package:test`: `feature` (a `group`), `scenario` (a single test), and `scenarioOutline` (one
  test per example row). Why no BDD framework:
  [`APPENDIX.md#behavioural-tests-helper`](./APPENDIX.md#behavioural-tests-helper).
- **Prefer an examples table over scattered literals.** For parse / normalise behaviour, drive a
  `scenarioOutline` from a `Map<String, Row>` where the key names the case and the record `Row`
  groups the input parameters with the expected outcome. Keeping the values together, rather than
  spread across separate tests and loop lists, is the whole point.
- **Let the canonical form double as the outcome.** For a type that normalises on parse, have the
  row carry the expected `.value` (or `null` for rejected input). One assertion,
  `check(parsed?.value).equals(row.canonical)`, then covers acceptance, rejection, and
  normalisation together.
- **One case per row, named by what makes it interesting.** Each row becomes its own `test`, so its
  name shows in the output and is selectable with `dart test -n`. Name rows `'the domain is
  lower-cased'`, not by the raw input.
- **Standard test vectors still apply.** The [value-type contract](#value-type-contract) is
  unchanged: standardised types include the official valid vectors plus corrupted variants that
  must be rejected.
- **Test what we built, not the dependencies.** Assume the wrapped validators (`email_validator`,
  `iban_validator`, `phone_numbers_parser`) validate correctly; that's their job. Spend the tests on
  our seams: normalisation, assembly, check-digit *generation*, the failure model (the exception's
  message *and* `source`), and edge cases. Cover failure paths and messages, not just happy-path
  acceptance: a positive-only suite once hid that every parse error read `Invalid String`
  (extension-type erasure of `'$T'`).
- **`conformance_test.dart` stays structural.** It enforces the contract via the analyzer AST, not
  behaviour, so it stays plain `group` / `test`; don't wrap it in the behavioural helper.

---

<a id="documentation-conventions"></a>
## Documentation conventions (Markdown)

- **APPENDIX.md is the source of truth for rationale.** Hard rules, pitfalls, and workflow stay
  in `.ai/AGENTS.md` and `.ai/CLAUDE.md`; the "why we do it this way" essays live in
  [`APPENDIX.md`](./APPENDIX.md).
- **Explicit `<a id="…">` anchors** sit above every APPENDIX and CODESTYLE heading. Link via the
  anchor, not the heading text. Anchor stability is load-bearing: when renaming a heading, keep
  the existing anchor, or `rg` the repo and update every caller in the same change.
- **Bare `dart` in command examples, never `fvm dart`.** FVM is a local implementation detail
  (`.fvmrc` pins the SDK). Docs stay tool-agnostic so external contributors aren't forced into
  FVM; scripts under `scripts/` handle the FVM-vs-PATH resolution themselves.
- **Trim prose to the load-bearing sentence.** The code-comment bar applies to README, APPENDIX and
  this file too: say the thing, then stop. No restating a point in three phrasings, no caveats
  nobody asked for. An APPENDIX entry earns more room than a comment, not a licence to ramble.
- **Never restate a value a source file owns.** Point at the file instead: "the `sdk:` constraint in
  `pubspec.yaml`", not "`^3.13.0`"; "the channel `.fvmrc` names", not "stable". A copied literal
  drifts silently the moment the source moves, which is how APPENDIX came to claim `^3.12.0` after
  the floor had already gone up. Prose owns the *reason* for a value; the file owns the value.
  Facts about a release ("the `new` shorthand needs ≥ 3.13") are not pins and stay, since Dart's
  history doesn't move.
- **British spelling in prose and identifiers** (`normalise`, `canonicalise`, `behaviour`), with
  one carve-out: names fixed by the SDK or a dependency stay as they are (`toJson`, `compareTo`,
  `hashCode`). See [`APPENDIX.md#spelling`](./APPENDIX.md#spelling).

---

<a id="shell-scripts"></a>
## Shell scripts

- **`shellcheck` is the lint contract** for `scripts/*.sh`, mirroring `dart analyze` for Dart. It
  runs from the [`linterpol`](https://github.com/LahaLuhem/linterpol) Docker image
  (`docker run --rm -v "$PWD:/work:ro" ghcr.io/lahaluhem/linterpol:latest shellcheck scripts/*.sh`),
  so the only local requirement is Docker, plus `jq` for the `scripts/release.sh` preflight, which
  reads the manifest with it. That preflight and `.github/workflows/repo.yml` both enforce it; they
  read the check set (shellcheck, actionlint, rumdl, ryl) and the image tag from one manifest,
  [`.github/lint-checks.json`](.github/lint-checks.json), so neither can drift from the other.
- **Prefer `# shellcheck disable=SC<code>` + a one-line "why" over refactoring for simple cases.**
  Refactor when the warning points at a real bug; reach for the directive when the code is correct
  and ShellCheck is just over-conservative. Always pair the directive with a comment.
