# CLAUDE.md — `minted`

Claude-Code-specific guidance. Project facts, stack, hard rules, and AI-agent guidelines live in
[AGENTS.md](./AGENTS.md); the full code-style guide lives in [`./CODESTYLE.md`](./CODESTYLE.md);
design rationale lives in [`./APPENDIX.md`](./APPENDIX.md). Read AGENTS.md and CODESTYLE.md first.

## Role & context

You're assisting with **minted**: a pure-Dart package of well-modelled value types (email, IBAN,
card numbers, …) built on "parse, don't validate", so every instance is guaranteed well-formed.
Treat the user as technical and direct. The package is intended for pub.dev, so changes are
visible to every downstream user; breakage is expensive and slow to walk back (unpublished
versions stay reserved for 7 days).

## Communication

- **Concise.** No "here's what I just did" recap; the diff speaks.
- **Explain the *why*** when recommending. The *what* is in the diff.
- Reference code as `file.dart:42` (markdown links if you can).
- Flag breaking-API or lint-violation implications loudly and early.

## Technical choices — always ask first

- **Do not silently pick between reasonable alternatives.** Whenever a task admits more than one
  defensible approach (a type's normalisation rules, whether a helper belongs on the type or in
  `lib/src/shared/`, whether a symbol is public, core vs companion, adding a dependency), **stop
  and ask.** List the options with trade-offs, say which you'd pick and why, then wait.
- **"Small" choices count.** The bar isn't "is this architecturally significant"; it's "could a
  reasonable maintainer disagree with my pick". If yes, ask.
- **Mark your recommendation with `★`** so the user can scan and reply by echoing or overriding.
- **Exception:** obvious single-answer fixes (typo, clear bug with one correct patch, lint error).
  Just do them.

## Tool preferences

- **Read / Edit / Grep / Glob** over `cat` / `sed` / `grep` / `find`. Always.
- **Bash** only for things without a dedicated tool: `dart`, `git`. The user's shell aliases
  `dart` to the toolchain serving the `.fvmrc` channel; invoke plain `dart`.
- **Lint with `dart --no-version-check analyze .`** — pedantic mode is the contract. Don't
  substitute plain `dart analyze` and ignore what it surfaces.
- **Agent tool** for wide / open-ended searches or to keep large output out of context.

## Scope awareness

Paths below are relative to a package under `packages/` (today only `packages/minted/`); the repo
root is the workspace, which holds tooling and docs but no Dart code.

- **Public-API edits** (anything in `lib/minted.dart` or re-exported from it) are pub.dev-visible.
  Flag whether the change is patch / minor / major under semver before it lands. Adding a public
  constructor to a value type is not just semver-significant, it breaks the package's core
  guarantee: don't.
- **`lib/src/` edits** are private; refactor freely as long as the public re-exports stay stable.
- **`test/` edits** are local, no publish impact.
- **`analysis_options.yaml` edits** affect every file; surface lint-posture changes loudly and add
  a written reason in `APPENDIX.md`.
- **`pubspec.yaml` dependency edits** add to every downstream user's transitive closure; treat as
  public-API-class, and remember opinionated deps belong in companion packages, not core.

## Auto-memory conventions for this project

- **`project` memories** — scope/constraints the user states aloud (e.g. "ship v0.1 with these six
  types", "raising the SDK floor to 3.10 on date Y"). Convert relative dates to absolute.
- **`feedback` memories** — corrections and validated non-obvious choices. Include **Why** and
  **How to apply**.
- **`reference` memories** — external pointers (pub.dev page, the context7 project, standard specs,
  GitHub issues). Not internal code paths, which live in AGENTS.md or are derivable from the repo.
- **Do NOT save** Dart file paths, lint-rule lists, or the API surface; all derivable from the repo
  or APPENDIX.md. Before acting on a memory, verify the named file / symbol still exists.

## Plan before editing when

- The change touches the public API (anything re-exported from `lib/minted.dart`); even adding a
  new type or method affects semver and downstream users.
- You're adding or removing a dependency in `pubspec.yaml`.
- You're changing `analysis_options.yaml`; lint posture is project-wide and any toggle deserves a
  written reason in APPENDIX.

For a single-file, single-concern change inside `lib/src/`, just do it.

The release flow (`CHANGELOG.md`, `version:` in `pubspec.yaml`) is **not** in this list: both are
pipeline-owned (see *Forbidden* below). Don't plan or make a CHANGELOG edit or a version bump.

## Commit / PR etiquette

- **Never commit without being asked.** Not after a fix, not as a "checkpoint". Leave changes in
  the working tree; suggest a message, let the user land it.
- **Never push without being asked.** Especially not to `main`.
- **Never `--amend`** unless asked; create a new commit instead.
- **Never `--no-verify`**, **never `git add -A`** — stage named paths.
- When asked for a commit: show `git status` + `git diff`, draft the message, wait for approval.
  Match existing commit style (short imperative subject).

## Forbidden / confirm-first actions

- **Never** `dart pub publish`. Publishing is effectively one-way (pub.dev reserves the version for
  7 days after retraction). Releases go through `tool/release.dart`, which the user runs manually.
- **Never** run `cider` commands or manually edit `CHANGELOG.md` (including `## Unreleased`) or the
  `version:` field. Those are owned by `tool/release.dart` and the changelog automation; manual
  edits get reordered or overwritten. If the user wants a release, suggest
  `dart run tool/release.dart <bump>`; don't run it (it pushes to `origin/main` and triggers
  publish). The `cider:` block in `pubspec.yaml` is static config, hand-editable.
- **Never** edit `pubspec.lock` directly (it's `dart pub get`'s output).
- **Never** delete files under `.fvm/`, `.dart_tool/`, or `pubspec.lock` without approval.
- **Destructive git** (`reset --hard`, `push --force`, `branch -D`, `clean -fd`) → ask first.

## Definition of done

- `dart run melos run analyze` clean (pedantic mode).
- `dart run melos run format` clean.
- `dart run melos run test` green, including the official standard test vectors for any
  standardised type.
- New / changed types honour the [value-type contract](CODESTYLE.md#value-type-contract):
  private constructor, `tryParse` + `parse`, `MintedFormatException`, value equality, canonical
  string form, documented normalisation.
- DCM rules applied by hand (`dart analyze` doesn't run them): `no-empty-block`,
  `newline-before-return`, `prefer-commenting-analyzer-ignores`, plus blank lines segmenting
  logical chunks in methods.
- Lint clean via the linterpol image for whatever changed: `actionlint` (workflows), `rumdl`
  (Markdown), `ryl` (YAML). The check set + per-tool config live in
  `.github/lint-checks.json`, `.rumdl.toml`, and `.yamllint.yaml`. **Actually run them.** A Docker
  daemon that is down is a thing to start, not a reason to hand the work over marked "unverified":
  these are CI gates, so skipping them just moves the failure to the pull request. Run all three
  together, since a Markdown edit can break `ryl` on a file you never opened:

  ```bash
  docker run --rm -v "$PWD":/work -w /work ghcr.io/lahaluhem/linterpol:latest sh -c 'actionlint && rumdl check . && ryl .'
  ```

- `dart pub publish --dry-run` clean if the change is publish-relevant. Do not bump the version or
  edit the CHANGELOG to make it pass; `tool/release.dart` owns those.
- Public API additions carry `///` dartdoc and are reflected in the README.
- **A local green is not a CI green.** Once a push has happened, read the run before treating
  anything as landed: `gh run list --workflow=package.yml --limit 3`, then
  `gh run view --job <id> --log`. The gates you can run here cannot see a CI-only failure at all.
- **When CI breaks and the diff is innocent, diff the runs, don't theorise.** Pull the last green
  job log beside the red one and compare what each actually resolved: `Download action repository`
  lines (the SHA behind a moving tag), the runner `Version:` lines, the SDK version. A `v1` tag that
  advanced from one release to another is invisible in `git log` and is what bit here. Correlating a
  release date with the breakage instead cost a wrong fix and a second red push, because the release
  that looked new was not the one that introduced the fault.
- **Read the upstream source before working around it.** `gh api repos/<o>/<r>/contents/<path>
  -H "Accept: application/vnd.github.raw"` at the tag in question. One `if` in setup-dart's
  `lib/main.dart` settled what the fix had to be; guessing from the release notes did not.
- Explicitly call out what you did NOT verify.
