# AGENTS.md — `minted`

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code, …) working in
this package. Claude-Code-specific guidance lives in [CLAUDE.md](./CLAUDE.md).

## Project goal

A library of well-modelled **value types** ("domain primitives") for entities that are routinely
left as raw `String` / `int` even though they carry real validation or normalisation rules,
usually from a published standard (ISO / RFC / ITU / GS1): email, IBAN, card numbers, ISBN, and
so on.

The organising principle is **parse, don't validate**: each type is constructible only through a
parsing factory, so any instance that exists is guaranteed well-formed, the same way `Uri`
guarantees a valid URL. This is the direct antidote to primitive obsession. Rationale:
[`APPENDIX.md#parse-dont-validate`](../APPENDIX.md#parse-dont-validate).

Pure Dart, so it works in Flutter apps, Dart servers, and CLIs alike. Consistency is the headline
feature: identical method names and the same failure model across every type.

## Stack

- **Dart ≥ 3.12** (constraint in `pubspec.yaml`, version pinned in `.fvmrc`). 3.12 gets extension
  types (≥ 3.3) and static dot shorthands (≥ 3.10) as stable features. Primary (declaring)
  constructors are *not* used: they are still an experiment in 3.12, and a published package can't
  rely on an experiment flag. See [`APPENDIX.md#sdk-floor`](../APPENDIX.md#sdk-floor). Bump the
  floor only when a new stable language feature is actually consumed, and record why in APPENDIX.
- **`dart test`** for tests; **`dart --no-version-check analyze .`** for pedantic static analysis
  (pedantic mode is intentional). No Flutter dependency, no platform channels.
- **`dependency_validator`** guards the dependency set; `dart_dependency_validator.yaml` scopes it
  to the published surface and skips the example.
- **`shellcheck`** (shell scripts) and **`actionlint`** (workflows) run from the
  [`linterpol`](https://github.com/LahaLuhem/linterpol) Docker image, not a local install, so only
  Docker is needed. `scripts/release.sh` preflight runs both; CI runs them in `repo.yml`.
- **CHANGELOG and the `version:` field are owned by [`scripts/release.sh`](../scripts/release.sh)**
  (via `cider`). Do not run `cider` by hand and do not edit `CHANGELOG.md` or `version:` directly.
  The `cider:` block in `pubspec.yaml` is static config (URLs, link templates) and is hand-editable.
- **Published to pub.dev.** `.pubignore` controls the tarball; `.editorconfig` is the source of
  truth for text-file conventions (line width 100, LF, UTF-8).

## Repo layout

```
minted/
├── lib/
│   ├── minted.dart                  Public entry; `export 'src/…'` only
│   └── src/
│       ├── email.dart               Email  (extension type)
│       ├── iban.dart                Iban   (extension type + mod-97)
│       ├── …                        One self-contained file per type
│       └── shared/
│           ├── minted_format_exception.dart   Typed FormatException (see APPENDIX)
│           └── check_digits.dart              Luhn / mod-97 / mod-11 / GS1 helpers (private)
├── test/                            `dart test` units; mirrors lib/src/, uses official vectors
├── example/
│   └── minted_example.dart          Single-file, pure-Dart, runnable via `dart run`
├── analysis_options.yaml            Strict-mode + opinionated lints
├── dart_dependency_validator.yaml   Scopes dependency_validator (excludes example/)
├── pubspec.yaml                     Deps + cider config + topics
├── .pubignore                       Files excluded from `pub publish`
├── .fvmrc / .editorconfig           Local SDK pin / text-file formatting
├── CHANGELOG.md                     Pipeline-owned; appears on pub.dev
├── README.md                        pub.dev landing page
├── APPENDIX.md                      Design rationale (anchor-keyed)
├── CODESTYLE.md                     Library-package code style
└── .ai/                             This file + CLAUDE.md (symlinked to repo root)
```

The example is a single file resolved against the root package: there is no `example/pubspec.yaml`
or `example/pubspec.lock`, so nothing Flutter-specific and no `--no-example` scoping. `dart analyze .`
and the release flow treat the whole tree uniformly.

## Hard rules

1. **Every value type follows the same contract.** Private primary constructor (`._`), no public
   constructor ever; `static T? tryParse(String)` (null on invalid); `static T parse(String)`
   (throws `MintedFormatException`); value equality; a canonical string form; per-type render
   helpers. This is the package's identity, not a preference. Full spec:
   [`CODESTYLE.md#value-type-contract`](../CODESTYLE.md#value-type-contract).
2. **The public API lives only in `lib/minted.dart`**, which re-exports from `lib/src/`. Don't make
   users import `package:minted/src/…`. Shared internals go in `lib/src/shared/`.
3. **Validate the real standard, including check digits** (IBAN mod-97, Luhn, ISBN/EAN/ISSN). A
   regex that only checks the shape is a bug. See
   [`APPENDIX.md#check-digits-not-regex`](../APPENDIX.md#check-digits-not-regex).
4. **No `print()` in library code.** `avoid_print` is a warning in `analysis_options.yaml`.
5. **No `dynamic` escape hatches.** `strict-casts`, `strict-inference`, `strict-raw-types` are all
   on. In particular, never `as T` a `tryParse` result to launder nullability.
6. **Public symbols carry `///` dartdoc** explaining the guarantee and the normalisation, not the
   mechanical *what*. `public_member_api_docs` is on.
7. **Pure Dart, no Flutter dep, dependency-light core.** Every dependency is a promise to all
   downstream users. A core value type may carry the pure-Dart, web-safe *engine* it is built on
   (`email_validator`, `iban_validator`, `phone_numbers_parser`); *adapter* integrations to other
   ecosystems (`fpdart`, Hive, Flutter form validators) go in companion packages, never in core.
   See [`APPENDIX.md#packaging-core-and-companions`](../APPENDIX.md#packaging-core-and-companions).
8. **Semver, strictly.** Any change to a public signature, a deletion, or a behavioural change of
   a documented contract (including a normalisation change) is breaking. `cider` enforces the
   version-bump discipline.
9. **`CHANGELOG.md` is bot-owned. Do not edit any section, including `## Unreleased`.** Release
   headers are written by [`scripts/release.sh`](../scripts/release.sh); the `## Unreleased` buffer
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

Full guide: [`../CODESTYLE.md`](../CODESTYLE.md). The lint posture is deliberately strict. Top
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
  user can scan and reply by echoing or overriding (e.g. "★ for 1–4, change 5 to B").
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
