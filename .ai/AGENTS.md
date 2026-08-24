# AGENTS.md — `minted`

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code, …) working in
this repo. Claude-Code-specific guidance lives in [CLAUDE.md](./CLAUDE.md).

## Project goal

A family of packages of well-modelled **value types** ("domain primitives") for entities that are
routinely left as raw `String` / `int` even though they carry real validation or normalisation
rules, usually from a published standard (ISO / RFC / ITU / GS1): email, IBAN, card numbers, ISBN,
and so on.

The organising principle is **parse, don't validate**: each type is constructible only through a
parsing factory, so any instance that exists is guaranteed well-formed, the same way `Uri`
guarantees a valid URL. This is the direct antidote to primitive obsession. Rationale:
[rationale][apx-parse-dont-validate].

Pure Dart, so it works in Flutter apps, Dart servers, and CLIs alike. Consistency is the headline
feature: identical method names and the same failure model across every type.

## Stack

- **Dart**, at the `sdk:` constraint every `pubspec.yaml` carries, on the channel `.fvmrc` names.
  Raise the floor only when a new stable language feature is actually consumed. What the floor buys,
  and why primary (declaring) constructors stay unused despite being stable:
  [rationale][apx-sdk-floor], which is also where a bump gets recorded.
- **`dart test`** for tests; **`dart --no-version-check analyze .`** for pedantic static analysis
  (pedantic mode is intentional). No Flutter dependency, no platform channels.
- **CI runs two SDKs on purpose.** The `dart format` gate in `repo.yml` takes its Dart from Flutter
  (the channel `.fvmrc` names) because formatter output is version-sensitive; every other job uses
  [`.github/actions/setup-dart`](../.github/actions/setup-dart/action.yml) on Dart stable, which is
  what downstream Dart-only users have. Route a new job through the composite unless it compares
  formatter output. Why: [rationale][apx-ci-sdk-toolchain].
- **`dependency_validator`** guards each package's dependency set, per package, and is what caught
  core still declaring engines after their types moved out. `dart_dependency_validator.yaml` scopes
  it to the published surface and skips the example.
- **Container-based linters** (`actionlint` for workflows, `rumdl` for Markdown, `ryl` for YAML)
  run from the [`linterpol`](https://github.com/LahaLuhem/linterpol) Docker image, not local
  installs, so Docker is the only requirement. The check set and image
  tag live in one manifest, [`.github/lint-checks.json`](../.github/lint-checks.json); `repo.yml`
  fans a CI matrix out over it and `tool/release.dart`'s preflight loops the same file, so the two
  can't drift. **Adding a linter is one entry in that manifest**, no workflow or script edit.
  Per-tool config tuned to the repo lives in `.rumdl.toml` and `.yamllint.yaml`.
- **CHANGELOG and the `version:` field are owned by [`tool/release.dart`](../tool/release.dart)**
  (via `cider`). Do not run `cider` by hand and do not edit `CHANGELOG.md` or `version:` directly.
  The `cider:` block in `pubspec.yaml` is static config (URLs, link templates) and is hand-editable.
- **Published to pub.dev.** `.pubignore` controls the tarball; `.editorconfig` is the source of
  truth for text-file conventions (line width 100, LF, UTF-8).

## Repo layout

A [pub workspace](https://dart.dev/tools/pub/workspaces): one resolution, one root `pubspec.lock`.
The root holds tooling, docs and CI but no Dart code; each package is a directory under `packages/`.

```text
minted/                              Workspace root
├── pubspec.yaml                     `workspace:` member list; publish_to: none, no version
├── analysis_options.yaml            Strict-mode + opinionated lints; members inherit by proximity
├── .fvmrc / .editorconfig           Local SDK channel / text-file formatting
├── .rumdl.toml / .yamllint.yaml     Markdown + YAML lint config
├── .github/                         Workflows + lint-checks.json, the shared lint manifest
├── tool/                            release.dart, the release flow, + its README
│   └── src/                         parsing/ versioning/ io/ flow/, plus options + abort
├── test/tool/                       The tooling's suite, mirroring src/; the root's only Dart tests
│   └── integration/                 `integration`-tagged; a real release against a throwaway remote
├── README.md                        Family index; the GitHub landing page
├── APPENDIX.md                      Family-wide design rationale (anchor-keyed); per-type
│                                    rationale lives in each package's own APPENDIX.md
├── CODESTYLE.md                     Library-package code style
├── context7.json                    Doc-indexer config for context7.com
├── .ai/                             This file + CLAUDE.md (symlinked to repo root)
└── packages/                        One directory per package
    ├── minted/                      Core: outcomes only. Deps: collection, meta
    ├── minted_chronology/           Date, Month, Weekday, Iso8601Duration
    ├── minted_conformance/          Private (publish_to: none); the cross-package suites
    ├── minted_constraints/          Digit(s), the Uint tower, Char, Letter(s), Ascii* (+ characters)
    ├── minted_contact/              Email, PhoneNumber (+ email_validator, phone_numbers_parser)
    ├── minted_finance/              Iban, Bic, Isin, PaymentCardNumber (+ iban_validator, country_code)
    ├── minted_geography/            GeoCoordinate
    ├── minted_identifiers/          Uuid, Isbn, Issn, Isni, Imei, Gtin
    └── minted_network/              IpAddress, Cidr, Hostname, DnsName, MacAddress, Port (+ ipaddr)
```

```text
packages/minted/                     Core. A sibling has the same shape, minus shared/
├── APPENDIX.md                      This package's own design rationale; ships in the tarball
├── lib/
│   ├── minted.dart                  Public entry; `export 'src/…'` only
│   ├── internal.dart                Cross-package plumbing for the siblings. NOT public API
│   └── src/
│       └── shared/                    Cross-package only; a sibling's own helpers travel with it
│           ├── outcomes/             What a parse hands back, and the only public part of shared/
│           │   ├── parse_outcome.dart          ParseOutcome + ParseSuccess / ParseFailure
│           │   ├── minted_failure.dart         The MintedFailure supertype
│           │   └── minted_format_error.dart    Typed Error, raised only by getOrThrow (see APPENDIX)
│           ├── encoding/             Characters ↔ numbers, bytes, bits
│           │   ├── digit_values.dart           ASCII '0'-'9' ↔ 0-9, both directions
│           │   └── hex_bytes.dart              Hex text ↔ bytes, both directions
│           ├── normalisation/        Canonical form in, canonical form out
│           │   └── normalisation.dart          Separator patterns, compaction, the pad characters
│           └── check_digits/         One file per algorithm, all private
│               └── luhn_check_digit.dart      ISO/IEC 7812-1 Annex B mod-10: finance + identifiers
├── test/                            `dart test` units; mirrors lib/src/, uses official vectors
│   └── support/                     bdd.dart et al; each package carries its own copy
├── example/
│   └── minted_example.dart          Single-file, pure-Dart, runnable via `dart run`
├── pubspec.yaml                     Deps + cider config + topics + `resolution: workspace`
├── dart_dependency_validator.yaml   Scopes dependency_validator (excludes example/)
├── .pubignore                       Files excluded from `pub publish`
├── CHANGELOG.md                     Pipeline-owned; appears on pub.dev
├── MIGRATION.md                     Version-to-version upgrade guide; ships in the tarball
├── README.md                        pub.dev landing page
└── LICENSE                          Per-package copy, so pub.dev detects it on this package
```

**Commands run from the root; a member's tests run from the member.** One `dart pub get` at the root
resolves every member, and `dart analyze .` / `dart format .` cover the whole workspace in one pass.
`dart test` does not: it tests the package it stands in, so a member's suite needs
`cd packages/minted`. The root has a suite of its own, covering the release tooling under `tool/`
only. Anything that reads a single pubspec — `cider`, `dart pub publish`, `dependency_validator` —
needs the member directory too, via `cd` or `dart pub -C packages/minted`.

**Melos wraps that split, so prefer `dart run melos run <script>`** — each script already knows
whether it belongs at the root or per-package. They live under the `melos:` key of the root
`pubspec.yaml`; `dart run melos run` lists them. Script runner only: versioning and publishing stay
with cider and `tool/release.dart`.

**A domain is a package.** Its types sit flat in that package's `lib/src/`, its failures in
`failures/`, its helpers in job-named subfolders. Two exceptions: core carries `shared/` for what
every sibling speaks, and `minted_constraints` sorts its primitives into `numerics/`, `quantities/`
and `text/`, being a category rather than a domain.
`test/` mirrors `lib/src/` in each package.

Internals go in a *subfolder* named for the job: `outcomes/` (the only public part of `shared/`,
what a parse hands back), `encoding/` (characters to numbers, bytes, bits), `normalisation/`,
`standards/` (fixed data a standard defines), `check_digits/` (one file per algorithm).

**Which package a helper lives in depends on how many use it.** Two or more, core's `shared/`,
reached through `package:minted/internal.dart`; exactly one, inside that package under the same job
name. `luhn_check_digit.dart` is core's (finance and identifiers both run it);
`iban_check_digits.dart` is `minted_finance`'s (only `Iban` does). That keeps core to what is
genuinely cross-package, and keeps `internal.dart` small, since everything in it is frozen for a
major. `conformance_test.dart` sweeps every package and excludes `failures/`, `shared/` and the
helper subfolders by path segment.

**A *constraint type* is a constrained primitive with no standard text form**, so it declares
`tryFrom` and neither parse door. Usually a range over a number; `Percentage` constrains the *unit*
instead and bounds nothing but finiteness, and a constraint on a `String` qualifies on the same
terms. `quantities/` holds most of them, but the category is not the directory: `Port` lives in
`network/` because it belongs there by domain. The category is a convention, not a structural check:
`conformance_test.dart` deliberately requires no door to *exist*, only that nothing lies about what
it can do. Rationale:
[rationale][apx-constraint-types].

**A type's failure vocabulary goes in its package's `failures/`, never in the value-type file**, one
file per type (`finance/failures/iban_failure.dart` holds `IbanFailure` and its variants). The
vocabularies grow to rival the types themselves, and the split on disk is what lets
`conformance_test.dart` tell a value type from a failure by path rather than by inferring it from
the AST. No `part` / `part of`: sealed variants only have to share a *file*, so a plain import
suffices, and anything a failure needs from its value type belongs in a helper subfolder instead
(which is why
[`iso_date_format.dart`](../packages/minted_chronology/lib/src/normalisation/iso_date_format.dart)
exists, in
`minted_chronology` because only it uses it).

**Check-digit algorithms get one file per *algorithm***, in the `check_digits/` of whichever root
the rule above picks, and reach what they share (`shared/encoding/digit_values.dart`, ASCII decimal
decoding) by plain import, never `part`.
That file sits in `shared/encoding/` rather than inside `check_digits/` because it was never
check-digit-specific:
`Digits` decodes with it too (from `minted_constraints`, through `internal.dart`), and once a second
caller appeared from outside the directory, keeping it in there would have meant a primitive
importing `check_digits/` for something that is not a check digit. It carries both directions
(`decimalValue`, `decimalCodeUnit`) even though no algorithm needs the encoder, because rendering
does. Separate libraries is the whole point: Dart privacy is library-scoped, so parts would leak
every `_` constant across every algorithm, and mod-97's modulus of 97 has no business being visible
to the next one.
Each file keeps its own constants and its own character map private to itself.

**A constant that two files both need goes in a helper subfolder, but only when it is the same
*concept*.** `cosmeticSeparators` was five identical copies of one normalisation rule, and
`ismnRange` was duplicated between `Isbn` and its own failure (a failure may not import its value
type, so a subfolder is the only place it can live: `minted_identifiers`, since no other package
reads it). Coincidental equality is not duplication and must stay put: `Iban`
and `Issn` both have a `_groupSize` of 4, but IBAN groups repeatedly every four where ISSN splits
once after four, and two of the check-digit moduli are both 10 for unrelated standards. Hoisting
those would couple facts that are free to move independently. Sharing a top-level constant also
means dropping its `_`, since a leading underscore is library-private in Dart; privacy then comes
from `lib/src/` and from not re-exporting it.

**Per algorithm, not per standard**, because standards share arithmetic: GS1's mod-10 validates both
GTIN and ISBN-13, and one weighted mod-11 serves ISO 2108's ISBN-10 and ISO 3297's ISSN, differing
only in the leading weight, which falls out of the body length. So a file is named for the algorithm
where two standards share one (`mod11_check_character.dart`) and for the standard where it is the
only user (`iban_check_digits.dart`). A second copy of an algorithm that is provably identical is a
bug waiting to be fixed twice; generalise it first, as its own behaviour-preserving commit, then
build the new type on it.

The example is a single file resolved against the root package: there is no `example/pubspec.yaml`
or `example/pubspec.lock`, so nothing Flutter-specific and no `--no-example` scoping.
`dart analyze .` and the release flow treat the whole tree uniformly.

## Hard rules

1. **Every value type follows the same contract.** Private primary constructor (`._`), no public
   constructor ever; `static ParseOutcome<F, T> parse(String)` carrying the type's own failure;
   `static T? tryParse(String)` derived from it; assembly factories (`fromComponents`, `from`, …)
   that return that same outcome; value equality; a canonical string form; a failure vocabulary in
   the package's `failures/`; per-type render helpers. One carve-out: an assembly door whose every
   parameter already carries its own invariants cannot fail, so it returns the value directly and may
   be a named factory (`Geohash.from`). **No door throws.** A door that can fail says
   so in its return type, and `ParseOutcome.getOrThrow` is the one place a caller opts into a throw,
   raising `MintedFormatError`. This is the package's identity, not a preference.
   Full spec: [`CODESTYLE.md#value-type-contract`](CODESTYLE.md#value-type-contract); rationale in
   [rationale][apx-per-type-failures] and
   [rationale][apx-claim-in-source].
2. **`minted` is the core and the lowest package; every other package is a sibling that depends on
   it.** A consumer takes `minted` plus one or more siblings. What gets extracted *into* core is
   shareable **plumbing** (`decimalValue`), not whole public features (`NaturalNumber`); where only
   part of a file is shared, split the file and move only that part. A sibling depending on another
   sibling is a last resort. Rationale:
   [rationale][apx-constraints-package].
3. **The public API lives only in `lib/minted.dart`**, which re-exports from `lib/src/`. Don't make
   users import `package:minted/src/…`. Shared internals go in `lib/src/shared/`.
4. **Validate the real standard, including check digits** (IBAN mod-97, Luhn, ISBN/EAN/ISSN). A
   regex that only checks the shape is a bug. See
   [`APPENDIX.md#check-digits-not-regex`](APPENDIX.md#check-digits-not-regex).
5. **No `print()` in library code.** `avoid_print` is a warning in `analysis_options.yaml`.
6. **No `dynamic` escape hatches.** `strict-casts`, `strict-inference`, `strict-raw-types` are all
   on. In particular, never `as T` a `tryParse` result to launder nullability.
7. **Public symbols carry `///` dartdoc** explaining the guarantee and the normalisation, not the
   mechanical *what*. `public_member_api_docs` is on.
8. **Pure Dart, no Flutter dep, dependency-light core.** Every dependency is a promise to all
   downstream users. A core value type may carry the pure-Dart, web-safe *engine* it is built on
   (`email_validator`, `iban_validator`, `phone_numbers_parser`); *adapter* integrations to other
   ecosystems (`fpdart`, Hive, Flutter form validators) go in companion packages, never in core.
   See [rationale][apx-packaging-core-and-companions].
9. **Semver, strictly.** Any change to a public signature, a deletion, or a behavioural change of
   a documented contract (including a normalisation change) is breaking. `cider` enforces the
   version-bump discipline.
10. **`CHANGELOG.md` is bot-owned. Do not edit any section, including `## Unreleased`.** Release
   headers are written by [`tool/release.dart`](../tool/release.dart); the `## Unreleased` buffer
   is appended to by [`.github/workflows/changelog.yml`](../.github/workflows/changelog.yml) from
   the merged PR title (governed by its `sem-*` label). Same prohibition on the `version:` field.

## PR conventions

Enforced by [`.github/workflows/pr-conventions.yml`](../.github/workflows/pr-conventions.yml).

- **Branch name** — `<type>/#<issue>-<slug>`, `<type>` one of `feature`, `bugfix`, `chore`,
  `refactor`, `acceptance-test-issues`, `hotfix`. Example: `feature/#7-add-iban`.
- **Exactly one `sem-*` label per PR.** Selects the changelog category for the post-merge
  automation:

  | Label           | Cider type   | When to use                                    |
  |-----------------|--------------|------------------------------------------------|
  | `sem-add`       | `added`      | New public symbol / type                       |
  | `sem-change`    | `changed`    | Behavioural or signature change                |
  | `sem-deprecate` | `deprecated` | Public symbol marked for future removal        |
  | `sem-remove`    | `removed`    | Previously-public symbol dropped               |
  | `sem-bugfix`    | `fixed`      | Defect repair, no signature change             |
  | `sem-security`  | `security`   | Security-relevant fix                          |
  | `sem-skip`      | (skip)       | Internal-only change (CI, docs, tests, …)      |

  The PR title becomes the changelog line verbatim; phrase it as a release-note bullet.
- **PR body must not be empty**, **no merge commits in the PR range** (rebase to integrate `main`),
  **commit subjects ≤ 82 characters**.

## Style

Full guide: [`CODESTYLE.md`](CODESTYLE.md). The lint posture is deliberately strict. Top
rules to keep in working memory:

- Type-annotate every public symbol; `final` by default for fields and locals.
- Nullability is explicit (no `as T` on a `T?`).
- 100-column line width; blank lines separate logical chunks within a method.
- No magic numbers in `lib/` code; a type's constants live on that type, shared ones under
  `lib/src/shared/`.
- Public symbols carry `///` dartdoc explaining *why* and *what guarantee*.
- British spelling in prose and identifiers, except names fixed by the SDK (`toJson`, `compareTo`).

## Guidelines for any AI agent

- **Always ask before making technical choices.** When a task admits more than one reasonable
  approach (a type's normalisation rules, whether something is core or a companion, whether a
  symbol is public, adding a dependency), stop and ask: present the options with trade-offs, say
  which you'd pick and why, then wait. Small choices compound.
- **Mark recommendations with `★`.** Prefix your preferred option in every set with `★` so the
  user can scan and reply by echoing or overriding (e.g. "★ for 1–4, change 5 to B"). A later
  "do these" about that set means the `★` subset, not every entry; the unstarred ones were listed
  to be weighed, not actioned. Ask if the wording is genuinely ambiguous.
- **Document new user-facing features in the README** in the same change. Rationale and trade-offs
  go in `APPENDIX.md`; the README is the user-facing entry point.
- **Read `analysis_options.yaml` before writing code.** The lint posture is far stricter than the
  Dart default; code that fails lint won't pass review.
- **Surface semver implications loudly.** If a change touches anything re-exported from
  `lib/minted.dart`, call out whether it's patch / minor / major before the diff lands.
- **Use official standard test vectors.** For any check-digit or standardised type, tests must
  include the published valid vectors plus corrupted variants that must be rejected.
- **Prefer an existing package over a custom solution.** Before hand-rolling validation, data, or a
  grammar (country tables, checksum-plus-registry logic), look for a package that already solves it
  and wrap it behind the value type, as core does with `email_validator` and `iban_validator`. Vet
  the candidate before adopting: pure Dart and web-safe, permissive licence, and current *data* (the
  last commit, open issues, and whether it covers recent additions to the standard), not just
  download count. A popular package with a stale registry is worse than a newer one that tracks the
  standard. Exception: a trivial, fixed algorithm with no data (a Luhn or mod-11 check) belongs in
  `lib/src/shared/`, not a micro-dependency, so the dependency-light core stays honest.
- **Refactor first when a change needs a better shape.** Do the enabling, behaviour-preserving
  refactor as its own step before building on top. Public-API breakage is semver-significant and
  slow to walk back once published, so surface the refactor and get sign-off before anything that
  touches the public API or adds a dependency.
- **The user manages git state; some tracked files won't show in `git status`.** The user may mark
  tracked files so their local edits are hidden from `git status` (typically
  `git update-index --skip-worktree` / `--assume-unchanged`). They are tracked, not gitignored, so
  a file you just edited can be genuinely changed on disk yet absent from `git status` and from
  `dart pub publish --dry-run`'s modified-files list. Don't be alarmed and don't try to re-stage or
  "fix" it: the user handles staging and committing. Trust the file contents you wrote, not
  `git status`, as the record of your change.

[apx-ci-sdk-toolchain]: ../APPENDIX.md#ci-sdk-toolchain
[apx-claim-in-source]: ../packages/minted/APPENDIX.md#claim-in-source
[apx-constraint-types]: ../packages/minted_constraints/APPENDIX.md#constraint-types
[apx-constraints-package]: ../packages/minted_constraints/APPENDIX.md#constraints-package
[apx-packaging-core-and-companions]: ../APPENDIX.md#packaging-core-and-companions
[apx-parse-dont-validate]: ../APPENDIX.md#parse-dont-validate
[apx-per-type-failures]: ../packages/minted/APPENDIX.md#per-type-failures
[apx-sdk-floor]: ../APPENDIX.md#sdk-floor
