Claude-Code-specific guidance. Read [AGENTS.md](./AGENTS.md) and
[CODESTYLE.md](../CODESTYLE.md) first: they hold the project facts, the hard rules and the code
style. Design rationale is in [APPENDIX.md](../APPENDIX.md).

## Role & context

You're assisting with **minted**: a pure-Dart package of well-modelled value types (email, IBAN,
card numbers, …) built on "parse, don't validate", so every instance is guaranteed well-formed.
Treat the user as technical and direct. Everything here ships to pub.dev, so a break is expensive
and slow to walk back. An unpublished version stays reserved for 7 days.

## Communication

- **Concise.** No "here's what I just did" recap. The diff speaks.
- **Explain the *why*** when recommending. The *what* is in the diff.
- Reference code as `file.dart:42` (markdown links if you can).
- Flag breaking-API or lint-violation implications loudly and early.

## Technical choices: always ask first

- **Do not silently pick between reasonable alternatives.** Whenever a task admits more than one
  defensible approach (a type's normalisation rules, whether a helper belongs on the type or in
  `lib/src/shared/`, whether a symbol is public, core vs companion, adding a dependency), **stop
  and ask.** List the options with trade-offs, say which you'd pick and why, then wait.
- **"Small" choices count.** The bar isn't "is this architecturally significant", it's "could a
  reasonable maintainer disagree with my pick". If yes, ask.
- **Mark your recommendation with `★`** so the user can scan and reply by echoing or overriding.
- **Exception:** obvious single-answer fixes (typo, clear bug with one correct patch, lint error).
  Just do them.

## Tool preferences

- **Read / Edit / Grep / Glob** over `cat` / `sed` / `grep` / `find`. Always.
- **Bash** only for things without a dedicated tool: `dart`, `git`. The user's shell aliases
  `dart` to the toolchain serving the `.fvmrc` channel, so invoke plain `dart`.
- **Lint with `dart --no-version-check analyze .`**, because pedantic mode is the contract. Don't
  substitute plain `dart analyze` and ignore what it surfaces.
- **Agent tool** for wide / open-ended searches or to keep large output out of context.

## Scope awareness

Paths below are relative to whichever package under `packages/` you are in. The repo root is the
workspace: docs, CI config, and the release tool with its own suite.

- **Public-API edits** (a package's barrel, or anything it re-exports) are pub.dev-visible. Flag
  whether the change is patch, minor or major under semver before it lands. Adding a public
  constructor to a value type is not just semver-significant, it breaks the package's core
  guarantee: don't.
- **`lib/src/` edits** are private, so refactor freely as long as the public re-exports hold.
- **`test/` edits** are local, no publish impact.
- **`analysis_options.yaml` edits** affect every file, so surface a lint-posture change loudly and
  write the reason into `APPENDIX.md`.
- **`pubspec.yaml` dependency edits** land in every downstream user's transitive closure, so treat
  them as public-API-class. Opinionated deps belong in a companion package, not core.

## Auto-memory conventions for this project

- **`project` memories:** scope and constraints the user states aloud ("ship v0.1 with these 6
  types", "raising the SDK floor to 3.10 on date Y"). Convert relative dates to absolute.
- **`feedback` memories:** corrections and validated non-obvious choices. Include **Why** and
  **How to apply**.
- **`reference` memories:** external pointers (the pub.dev page, the context7 project, standard
  specs, GitHub issues). Not internal code paths, which live in AGENTS.md.
- **Do NOT save** Dart file paths, lint-rule lists, or the API surface. All of it is derivable from
  the repo or APPENDIX.md. Before acting on a memory, check the named file or symbol still exists.

## Plan before editing when

- The change touches the public API, meaning a package's barrel or anything it re-exports. Even
  adding a type or a method affects semver and downstream users.
- You're adding or removing a dependency in `pubspec.yaml`.
- You're changing `analysis_options.yaml`. Lint posture is project-wide, so any toggle wants a
  written reason in APPENDIX.

For a single-file, single-concern change inside `lib/src/`, just do it.

The release flow (`CHANGELOG.md`, `version:` in `pubspec.yaml`) is **not** in this list: both are
pipeline-owned (see *Forbidden* below). Don't plan or make a CHANGELOG edit or a version bump.

## Commit / PR etiquette

- **Never commit without being asked.** Not after a fix, not as a "checkpoint". Leave changes in
  the working tree, suggest a message, let the user land it.
- **Never push without being asked.** Especially not to `main`.
- **Never `--amend`** unless asked. Create a new commit instead.
- **Never `--no-verify`**, **never `git add -A`**. Stage named paths.
- When asked for a commit: show `git status` + `git diff`, draft the message, wait for approval.
  Match existing commit style (short imperative subject).

## Forbidden / confirm-first actions

- **Never** `dart pub publish`. Publishing is effectively one-way (pub.dev reserves the version for
  7 days after retraction). Releases go through `tool/release.dart`, which the user runs manually.
- **Never** run `cider` commands or manually edit `CHANGELOG.md` (including `## Unreleased`) or the
  `version:` field. Those belong to `tool/release.dart` and the changelog automation, and a manual
  edit gets reordered or overwritten. If the user wants a release, suggest
  `dart run tool/release.dart <bump>` but don't run it: it pushes to `origin/main` and triggers
  publish. The `cider:` block in `pubspec.yaml` is static config, hand-editable.
- **Never** edit `pubspec.lock` directly (it's `dart pub get`'s output).
- **Never** delete files under `.fvm/`, `.dart_tool/`, or `pubspec.lock` without approval.
- **Destructive git** (`reset --hard`, `push --force`, `branch -D`, `clean -fd`) → ask first.

## Definition of done

- `dart run melos run analyze` clean (pedantic mode).
- `dart run melos run format` clean.
- `dart run melos run test` green, including the official standard test vectors for any
  standardised type.
- New / changed types honour the [value-type contract](../CODESTYLE.md#value-type-contract):
  private constructor, `tryParse` + `parse`, `MintedFormatError`, value equality, canonical
  string form, documented normalisation.
- DCM rules applied by hand (`dart analyze` doesn't run them): `no-empty-block`,
  `newline-before-return`, `prefer-commenting-analyzer-ignores`, plus blank lines segmenting
  logical chunks in methods.
- Lint clean via the linterpol image. Config lives in `.github/lint-checks.json`, `.rumdl.toml`
  and `.yamllint.yaml`. Run all 3, and start Docker if it's down rather than handing the work
  over unverified:

  ```bash
  docker run --rm -v "$PWD":/work -w /work ghcr.io/lahaluhem/linterpol:latest sh -c 'actionlint && rumdl check . && ryl .'
  ```

- `dart pub publish --dry-run` clean if the change is publish-relevant. Do not bump the version or
  edit the CHANGELOG to make it pass. `tool/release.dart` owns those.
- Public API additions carry `///` dartdoc and are reflected in the README.
- **A local green is not a CI green.** After a push, read the run: `gh run list --limit 3`, then
  `gh run view --job <id> --log`.
- **When CI breaks on an innocent diff, diff the runs.** Compare the last green job log against the
  red one for what each resolved: `Download action repository` SHAs behind moving tags, runner and
  SDK versions. Read the upstream source at that tag before working around it, rather than inferring
  from release dates.
- Explicitly call out what you did NOT verify.
