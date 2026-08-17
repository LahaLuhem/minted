<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Usage](#usage)
- [First publish of a package](#first-publish-of-a-package)
- [Cutover to the split packages (one-time)](#cutover-to-the-split-packages-one-time)
- [What's pipeline-owned vs. hand-editable](#whats-pipeline-owned-vs-hand-editable)
- [Tag format](#tag-format)
- [Preflight](#preflight)
- [FVM note](#fvm-note)

<!-- TOC end -->

Audience: maintainers and contributors who want to understand or invoke the release
flow. End users of the package don't need anything in this directory.

Cuts a versioned release of one workspace member, chosen from those with unreleased notes
(see [Which package](#which-package)).

Bumps the `version:` field in the member's `pubspec.yaml` via `cider`, finalises the
`## Unreleased` block in its `CHANGELOG.md` into a dated section, commits both files,
creates a SemVer tag, and pushes commit + tag atomically. The tag push triggers
[`../.github/workflows/publish.yml`](../.github/workflows/publish.yml), which then
publishes to pub.dev via OIDC.

Laptop-only — does not run inside CI.

> **Being ported.** [`tool/release.dart`](../tool/release.dart) is a Dart rewrite of this script,
> with unit tests under [`test/tool/`](../test/tool). It is not the live route: `release.sh` stays
> until the port has cut a real release. See
> [#62](https://github.com/LahaLuhem/minted/issues/62).

## Usage

```bash
scripts/release.sh                                # fully interactive
scripts/release.sh patch                          # bump type set, package + confirm on TTY
scripts/release.sh patch -p minted --yes          # non-interactive (CI-style)
scripts/release.sh --dry-run                      # full preflight + plan, no side effects
scripts/release.sh minor -m "Big new feature"     # annotated tag with this message
```

`BUMP` is one of `major`, `minor`, `patch`. The script prompts on a TTY if omitted.

### Which package

Candidates are the members whose `CHANGELOG.md` **opens** with a populated `## Unreleased`
block. `cider release` dates that heading, so a package drops off the list once it ships; one
sitting *below* a dated heading doesn't count, since the release above it consumed everything.

One candidate is picked automatically, several prompt, `--package NAME` chooses outright, and
naming one with nothing pending errors with the list. Releasing two packages means running
twice: a tag and a CI run each, no lockstep.

### Tag mode

By default, `git tag <version>` produces a **lightweight tag** — a bare ref pointer with no
body, message, or signature. Pass `-m "MSG"` / `--tag-message "MSG"` to produce an
**annotated tag** with that message; if your git config has `tag.gpgSign=true`, the
annotated tag is also signed.

The lightweight default is independent of your `tag.gpgSign` setting — for the
no-`-m` path the script runs `git tag` with `-c tag.gpgSign=false` applied to that one
invocation, so plain `release.sh minor` never opens an editor or demands a message.
Lightweight tags can't be signed (there's no body to sign), so the bypass is
mechanically necessary, not a stylistic choice.

## First publish of a package

pub.dev can only configure automated publishing for a package that already exists, so a package's
**first** version goes up by hand and every later one goes through the tag pipeline.

**Finalise the CHANGELOG first.** pub refuses to publish quietly if the CHANGELOG does not mention
the version going up, and it is `release.sh` that normally dates the `## Unreleased` heading. A hand
publish skips that, so do it yourself, then commit:

```bash
cd packages/<name> && cider release   # ## Unreleased -> ## [1.0.0] - today
```

No bump: a first release publishes the version already in the pubspec, which is why `release.sh`
is the wrong tool here. It always bumps, so it would turn 1.0.0 into 1.0.1.

While you are in there, **check the notes read correctly for a first release.** A cross-package PR
carries one `sem-*` label, and `changelog.yml` applies it to every package the PR touched, so a
package can inherit a section that only made sense for another one. The v3 split wrote
`### Removed` into all six new packages, where the honest heading was `### Added`.

Then publish:

```bash
dart pub -C packages/<name> publish
```

Then set that package's tag pattern to `<name>-{{version}}` under
`pub.dev/packages/<name>/admin`, same publisher as the rest. From its second release on,
`scripts/release.sh` is the only route.

Tag the version you just published anyway, so the history is uniform. `publish.yml` checks pub.dev
first and exits green when the version is already up, so the tag costs nothing.

## Cutover to the split packages (one-time)

Order matters: siblings cannot claim `minted ^3.0.0` until core actually declares it, because a
workspace refuses to resolve a constraint no member satisfies. The preflight refuses to release a
package whose sibling constraint is older than what the tree builds against, so a forgotten step 2
fails loudly instead of shipping a wrong constraint that pub.dev can never take back.

1. **Release core.** `scripts/release.sh major --package minted` takes 2.0.0 to 3.0.0 and publishes
   through the tag pipeline as usual. Its own pub.dev tag pattern must already be `minted-{{version}}`
   (see [Tag format](#tag-format)).
2. **Tighten every sibling** from `minted: '>=2.0.0 <4.0.0'` to `minted: ^3.0.0`, one commit.
3. **Publish each sibling** by hand, per *First publish* above, then configure its tag pattern.
   `minted_contact` depends on `minted_network`, so publish network first; the rest are independent.

## What's pipeline-owned vs. hand-editable

The member's `CHANGELOG.md` and the `version:` field in its `pubspec.yaml` are
**pipeline-owned**: the script reorders or overwrites manual edits to them. Hand-edits
will not survive the next release. The workspace-root `pubspec.yaml` carries no
`version:` at all, so it is outside this entirely.

The `## Unreleased` block in `CHANGELOG.md` is the script's **input** — curated by
hand between releases. The script bails if no package has one.

Entries land there automatically: on merge,
[`changelog.yml`](../.github/workflows/changelog.yml) runs `cider log` in each package the PR
touched, so one spanning two writes its title into both. Titles therefore need to read sensibly
in every package they touch, or the PR wants splitting. A root-only PR gets no entry.

The `cider:` block in `pubspec.yaml` is static configuration (link templates, URLs)
and sits outside the pipeline-owned set — hand-editable.

> Unlike the maintainer's Flutter packages, `minted` has no `example/pubspec.lock`
> to resync at release time: the example is a single `.dart` file resolved against the
> root package, so there is no separate lockfile to keep in step. That step, and the
> `flutter` preflight it needed, are gone.

## Tag format

`<package>-<MAJOR>.<MINOR>.<PATCH>`, no `v` prefix, e.g. `minted-2.1.0`. Pub names cannot
contain a hyphen, so [`publish.yml`](../.github/workflows/publish.yml) splits on the first one
to pick the member, `minted-3.0.0-beta.1` included.

> **Each package needs a matching tag pattern on pub.dev**, set under
> `pub.dev/packages/<name>/admin` to `<name>-{{version}}`. `minted` predates the workspace and
> is still `{{version}}`, so **it has to change when this lands**, or the next tag publishes
> nothing.

Before publishing, the version half is checked against the member's `pubspec.yaml`, and a
version already on pub.dev is skipped rather than re-published.

## Preflight

The script refuses to proceed unless every check passes:

- `dart` resolvable (prefers `.fvm/flutter_sdk/bin/dart` if present, else PATH).
- `cider` on PATH.
- `jq` on PATH (reads the lint manifest, `.github/lint-checks.json`).
- `docker` on PATH, daemon running (runs the checks from `.github/lint-checks.json`
  via the linterpol image: `shellcheck`, `actionlint`, `rumdl`, `ryl`, no local installs).
- Working tree clean, on `main`, in sync with `origin/main` (fetches first).
- The member's `CHANGELOG.md` has a non-empty `## Unreleased` (or `## [Unreleased]`) section.
- `dart format` and `dart analyze` clean, run repo-wide from the root; `dart test` green,
  run inside the member.
- The target tag does not already exist locally or on the remote.

`dart pub publish --dry-run` is *not* in preflight. It cross-checks three things
that must be satisfied simultaneously:

1. `pubspec.yaml`'s `version:` matches a CHANGELOG header.
2. No checked-in files are modified in the working tree.
3. The tarball builds and validates against pub.dev rules.

(1) only holds *after* `cider bump` + `cider release`. (2) only holds *after*
`git commit` — running the dry-run against the working tree mid-execute would
trip on the bump/release modifications. So the dry-run runs as step 5, after
the prep commit lands. The `ERR` trap handles failure in two phases:

- **Pre-commit failure** (bump or release errored, no commit yet):
  restore `pubspec.yaml` + `CHANGELOG.md` from `HEAD`.
- **Post-commit, pre-tag failure** (dry-run rejected the prep commit):
  `git reset --hard HEAD~1` to drop the prep commit, leaving the working
  tree exactly as it was before `release.sh` started. No remote tag is ever
  created in this case — the validation gate sits between commit and tag, so
  there's nothing to clean up on `origin`.

After the dry-run passes, the trap clears — `git tag` / `git push` failures
require manual recovery (the script prints the recipe).

## FVM note

If `.fvm/flutter_sdk/bin/dart` exists, the script prepends it to `PATH` so plain
`dart` resolves to the `.fvmrc`-pinned SDK. Otherwise, it falls back to whatever
`dart` is on `PATH` — a non-FVM contributor can run the script unchanged.
SDK-version compatibility is enforced indirectly via `pub publish --dry-run` in
preflight.
