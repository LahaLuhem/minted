# APPENDIX — `minted`

Design rationale: the "why" behind decisions that the code and the hard rules alone don't explain.
This file holds what spans the family; a decision about one type lives with the package that ships
it, listed under [per-package rationale](#per-package-rationale) below. Hard rules and workflow live
in [`.ai/AGENTS.md`](./.ai/AGENTS.md); code style in [`CODESTYLE.md`](./CODESTYLE.md). Each heading
carries an explicit `<a id="…">` anchor; link by anchor, and keep anchors stable across renames.

<!-- TOC start -->

- [Per-package rationale](#per-package-rationale)
- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#ai-files-symlinked)
- [Pure-Dart package, no Flutter dependency](#pure-dart-not-flutter)
- [The format gate runs Flutter's Dart, everything else runs Dart stable](#ci-sdk-toolchain)
- [Parse, don't validate](#parse-dont-validate)
- [Extension type vs immutable class](#extension-type-representation)
- [Compose from modelled parts, don't re-derive them](#compose-from-modelled-parts)
- [Normalise on parse](#normalise-on-parse)
- [Check the real standard, not a regex shape](#check-digits-not-regex)
- [Registry data ships a clock](#registry-data-ships-a-clock)
- [Behavioural tests: a helper, not a framework](#behavioural-tests-helper)
- [Public API funnelled through `lib/minted.dart`](#public-api-via-single-export-file)
- [Packaging: one package per domain, engines beside the types that wrap them](#packaging-core-and-companions)
- [British spelling in the public API](#spelling)
- [SDK floor](#sdk-floor)
- [What `minted` deliberately does not cover](#what-not-covered)

<!-- TOC end -->

---

<a id="per-package-rationale"></a>
## Per-package rationale

Decisions about individual types live with the package that ships them, so each one is
readable on its own and reaches its consumers on pub.dev:

- [`minted`](./packages/minted/APPENDIX.md)
- [`minted_constraints`](./packages/minted_constraints/APPENDIX.md)
- [`minted_chronology`](./packages/minted_chronology/APPENDIX.md)
- [`minted_finance`](./packages/minted_finance/APPENDIX.md)
- [`minted_geography`](./packages/minted_geography/APPENDIX.md)
- [`minted_identifiers`](./packages/minted_identifiers/APPENDIX.md)
- [`minted_network`](./packages/minted_network/APPENDIX.md)

---

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

The organising principle, after Alexis King's essay of the same name. A function that *validates*
takes a `String`, checks it, and hands the same `String` back; every later consumer has to trust
that the check happened and re-check if unsure. A function that *parses* takes a `String` and
returns a **different type** that can only exist if the input was well-formed. The validity
becomes a fact of the type system, checked once, carried everywhere.

That is what `Uri` does for URLs and `int.parse` does for integers, and it is what every `minted`
type does for its domain. The mechanics that enforce it:

- The primary constructor is **private** (`._`). No caller can build an instance directly.
- The only ways in are `parse` and the assembly factories (both return a
  [`ParseOutcome`][parse-outcome]), and `tryParse` (returns `T?`). All run the same full check, and
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
Genuinely multi-field values ([`Date`][date-value-type]) have no single representation to wrap.
Single-valued ones still take a class when an inherited `Object` member misbehaves:
[`Digits`][typed-digit-subparts] needs structural `==` that `Uint8List` will not give, and
[`PaymentCardNumber`][payment-card-number-value-type] needs a `toString` that does not print the
card. Same test, different member. No `Equatable` dependency either way: handwritten equality is a
few honest lines and the core stays dependency-light.

---

<a id="compose-from-modelled-parts"></a>
## Compose from modelled parts, don't re-derive them

**The shape question is which parts exist as types, not how many primitives the value spells.** An
earlier version of the rule in `CODESTYLE.md` said a value spelled by one `String` takes an
extension type and a value with several parts takes a class. That reads the wrong signal.
`10.0.0.0/8` is one string, so the old rule made `Cidr` an extension type that would slice an
address back out of its own text on every call. The part it is slicing out is an
[`IpAddress`][ip-address-value-type], a type this package already has, with a canonical form and a
parse gate of its own. Holding one is both safer and cheaper than re-deriving it.

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

- `Iban`'s `bban`, `Isin`'s `nsin` and `Bic`'s codes are alphanumeric, and now hold
  [`AsciiAlphanumerics`][constraints-package]. Minting that type was declined once, on a call-site
  count over `lib/` that read zero; the count was the wrong test for a type whose job is the public
  surface.
- `Hostname` and `DnsName` labels have no type either, because a label's validity is **positional**.
  `Hostname` refuses an all-numeric *last* label, so a valid label at one index is invalid at
  another, and no per-label type can express that.
- `Email.domain` is not always a hostname. An RFC 5321 address literal (`jane@[192.0.2.1]`) and an
  internationalised domain are both valid addresses whose domain a `Hostname` refuses, so the getter
  stays text and [`domainAsHostname`][hostname-value-type] offers the partial narrowing.
- `IpAddress.octets` stays a `Uint8List`, which already enforces `0`-`255` by construction, so
  `List<Uint8>` would catch nothing while taxing every arithmetic use with `.value`.
- `Gtin`, `Issn` and `Isni` expose no digit-segment getter at all: their public surface is render
  helpers, and a check character can be `X`, which a `Digits` cannot hold.

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

The most repeated decision in the family, hoisted here so every type's section can point at it
instead of re-deriving it. **A validation rule built on registry data is correct on release day and
quietly wrong afterwards**, because the registry moves and a published package does not. That is
worse than under-validating: rejecting a real value, or confidently mis-rendering one, costs the
caller more than saying less would have.

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
outcome under a descriptive name. Where a type normalises on parse, the canonical form doubles as
that outcome (a string means "accepted and normalised to this", `null` means "rejected"), folding
acceptance, rejection, and normalisation into one table. How-to in
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
[cutover order](./tool/README.md) is the softer version of the same constraint, and the
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
`public_member_api_docs`, which this package enables, reports the implicit primary constructor as an
undocumented public member at the class name, where there is no declaration to hang a `///` on.
Verified across const, non-const and zero-parameter forms; the old form with a documented
constructor is clean. The ways out are an `// ignore:` per class, which `document_ignores` then
makes you justify (more noise than the docstring it replaced), or dropping the lint package-wide. It
has fired on constructors with nowhere to document before
([linter#3655](https://github.com/dart-lang/linter/issues/3655),
[linter#284](https://github.com/dart-lang/linter/issues/284)), so this is a known pattern rather
than a fresh bug. The other half works: `dart doc` carries a `///` on a primary-constructor
parameter through to a field page. Revisit if the lint learns about them.

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
and Dart has no `LocalDate`, so [`Date`][date-value-type] fills that. The `uuid` package *generates*
into a `String` rather than being a value type, so [`Uuid`][uuid-value-type] types an existing one.
And IP addresses are **not** covered by the stdlib for this package's purposes, which is what
[`IpAddress`][ip-address-value-type] exists for. `InternetAddress` is `dart:io`, so it is
unavailable on the web, which a pure-Dart web-safe package cannot build on.

Where `minted` builds *on* such a package it wraps rather than reinvents: a pure-Dart, web-safe engine
sits in core, and only an adapter to another ecosystem goes in a companion (see
[packaging](#packaging-core-and-companions)). Each package's README carries the comparison for its
own types, and the [issue tracker](https://github.com/LahaLuhem/minted/issues) holds the gap types
still to land.

[constraints-package]: ./packages/minted_constraints/APPENDIX.md#constraints-package
[date-value-type]: ./packages/minted_chronology/APPENDIX.md#date-value-type
[hostname-value-type]: ./packages/minted_network/APPENDIX.md#hostname-value-type
[ip-address-value-type]: ./packages/minted_network/APPENDIX.md#ip-address-value-type
[parse-outcome]: ./packages/minted/APPENDIX.md#parse-outcome
[payment-card-number-value-type]: ./packages/minted_finance/APPENDIX.md#payment-card-number-value-type
[typed-digit-subparts]: ./packages/minted_constraints/APPENDIX.md#typed-digit-subparts
[uuid-value-type]: ./packages/minted_identifiers/APPENDIX.md#uuid-value-type
