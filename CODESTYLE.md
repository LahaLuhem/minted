Library-package code style. Project facts (goal, stack, repo layout, hard rules) live in
[`.ai/AGENTS.md`](./.ai/AGENTS.md); design rationale lives in [`APPENDIX.md`](./APPENDIX.md).

The lint posture is deliberately strict (see [`analysis_options.yaml`](./analysis_options.yaml)).
The house style values explicit types, no ambient mutability, small focused types, and a
single consistent shape across every value type in the package.

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
  `analysis_options.yaml` matches it; keep them aligned if either moves.
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
  cross-cutting constants (shared radices, a shared alphabet) go under `lib/src/shared/`. Before
  introducing a new constant, check whether a shared one already exists.

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

**Two representations, one contract.**

- **Single primitive (one `String`/`int`) → extension type**, zero runtime cost, private
  primary constructor:

  ```dart
  extension type const Iban._(String value) {
    /// null when [input] is not a well-formed IBAN (length, country, mod-97 check).
    static Iban? tryParse(String input) {
      final normalised = _normalise(input);
      if (!_isWellFormed(normalised)) return null;

      return Iban._(normalised);
    }

    /// throws [MintedFormatException] when [input] is invalid.
    static Iban parse(String input) =>
        tryParse(input) ?? (throw MintedFormatException.of<Iban>(input, 'failed structure or mod-97 check'));

    String get countryCode => value.substring(0, 2);
    // … further sub-part getters and render helpers …
  }
  ```

- **Multiple parts (or computed sub-parts) → immutable class**, private primary constructor,
  hand-written `==` / `hashCode` / `toString`:

  ```dart
  @immutable
  final class GeoCoordinate {
    const GeoCoordinate._(this.latitude, this.longitude);

    static GeoCoordinate? tryParse(String input) { /* ISO 6709 */ }
    static GeoCoordinate parse(String input) =>
        tryParse(input) ?? (throw MintedFormatException.of<GeoCoordinate>(input, 'not ISO 6709'));

    final double latitude;
    final double longitude;

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

**Non-negotiable across both shapes:**

1. **Private primary constructor** (`._`). There is no public way to build an instance except
   through parsing, so any instance that exists is well-formed. Do not add a public constructor,
   ever; it would break the guarantee the whole package sells.
2. **`static T? tryParse(String input)`** returns `null` on invalid input. No throwing.
3. **`static T parse(String input)`** throws [`MintedFormatException`](./APPENDIX.md#why-typed-format-exception)
   (never a bare `Exception`, never `assert`). Implement it as `tryParse(input) ?? (throw …)` so
   the two never diverge.
4. **Value equality.** Extension types inherit it from the representation for free (see below);
   classes hand-write `==` + `hashCode` over their parts. No `Equatable` dependency.
5. **A canonical string form.** `.value` for extension types (the representation), a named getter
   (`.iso6709`, `.formatted`) for classes.

**Normalise on parse.** `tryParse` converts input to a single canonical form before constructing
(trim, case-fold the parts the standard says are case-insensitive, strip separators). Because
extension-type equality is representation equality, this is what makes
`Iban.parse('gb82 west …') == Iban.parse('GB82WEST…')` true. Document each type's normalisation in
its dartdoc. See [`APPENDIX.md#normalise-on-parse`](./APPENDIX.md#normalise-on-parse).

**Extension-type facts you must design around** (verified against the analyzer, not assumed):

- You **cannot** redeclare `toString`, `==`, or `hashCode` on an extension type; they always
  delegate to the representation. For a `String`-backed type this is a feature: `print(iban)`
  shows the IBAN, and equality is canonical-string equality. Do not fight it; do not try to
  make an extension type print `Iban(...)`.
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

<a id="idioms-collection-literals"></a>
### Collection-`for` / collection-`if` over `Iterable.map(…).toList()`

When building a literal collection (an embedded code table, a set of test vectors), a literal
with embedded control flow reads as data and drops the `<T>` annotations the literal context
already infers. Keep `.map(...)` for genuine pipelines.

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

<a id="idioms-parts"></a>
### `part` / `part of` only when structurally needed

Legitimate uses: sealed-class cases across files (Dart requires the same library for sealed
subtypes), code-generation outputs (`*.g.dart`). Avoid it for general organisation; imports are
explicit, and parts leak `_private` symbols across files. In this package each value type is one
self-contained file under `lib/src/`, so `part` should be rare.

<a id="idioms-dot-shorthands"></a>
### Static dot shorthands (Dart 3.10+; stable at the 3.12 floor)

Where the context type is known, drop the leading type name; the analyzer resolves the member
from the parameter, return, or variable type. This covers enum values in patterns and argument
slots, and named constructors / static factories in a return or context slot.

```dart
// enum value in a switch arm — context type is CardBrand:
CardBrand _brand(String digits) => switch (digits) {
  _ when digits.startsWith('4')  => .visa,
  _ when digits.startsWith('34') => .amex,
  _                              => .unknown,
};
```

Skip it where the context type isn't obvious without re-reading, or where it hurts readability.
When a prefix disappears from a file entirely, drop it from any `show` clauses too. Note this is
a stable feature at the 3.12 floor; primary (declaring) constructors are a separate, still-
experimental feature and are not used (see [`APPENDIX.md#sdk-floor`](./APPENDIX.md#sdk-floor)).

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
  [`test/support/bdd.dart`](./test/support/bdd.dart) is a small Gherkin vocabulary over
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
- **British spelling in prose and identifiers** (`normalise`, `canonicalise`, `behaviour`), with
  one carve-out: names fixed by the SDK or a dependency stay as they are (`toJson`, `compareTo`,
  `hashCode`). See [`APPENDIX.md#spelling`](./APPENDIX.md#spelling).

---

<a id="shell-scripts"></a>
## Shell scripts

- **`shellcheck` is the lint contract** for `scripts/*.sh`, mirroring `dart analyze` for Dart. It
  runs from the [`linterpol`](https://github.com/LahaLuhem/linterpol) Docker image
  (`docker run --rm -v "$PWD:/work:ro" ghcr.io/lahaluhem/linterpol:latest shellcheck scripts/*.sh`),
  so the only local requirement is Docker. Both `scripts/release.sh` preflight and
  `.github/workflows/repo.yml` enforce it; the same image also runs `actionlint` over the workflows.
- **Prefer `# shellcheck disable=SC<code>` + a one-line "why" over refactoring for simple cases.**
  Refactor when the warning points at a real bug; reach for the directive when the code is correct
  and ShellCheck is just over-conservative. Always pair the directive with a comment.
