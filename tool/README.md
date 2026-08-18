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

## Usage

```bash
dart run tool/release.dart                              # fully interactive
dart run tool/release.dart patch                        # bump set, package + confirm on TTY
dart run tool/release.dart patch -p minted --yes        # non-interactive
dart run tool/release.dart --dry-run                    # full preflight + plan, no side effects
dart run tool/release.dart minor -m "Big new feature"   # annotated tag with this message
```

`BUMP` is one of `major`, `minor`, `patch`. The tool prompts on a TTY if omitted.
`--help` lists every option.

`--repo-root DIR` releases from a different checkout instead of the one this tool lives in. It
exists for the integration test, which cuts a real release against a throwaway clone with a local
bare remote, so nothing can reach pub.dev. That is what verifies `cider bump`, the commit, the tag
and the atomic push, which the unit tests only fake.

```bash
dart run melos run test-release-flow    # needs git, cider and a running Docker daemon
```

`integration`-tagged, so the default `dart test` skips it and CI runs it in its own step. Worth the
setup: it caught the rollback running git in whatever directory the process started in, which every
unit test passed over.

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
no-`-m` path the tool runs `git tag` with `-c tag.gpgSign=false` applied to that one
invocation, so a plain `minor` run never opens an editor or demands a message.
Lightweight tags can't be signed (there's no body to sign), so the bypass is
mechanically necessary, not a stylistic choice.

## First publish of a package

pub.dev can only configure automated publishing for a package that already exists, so a package's
**first** version goes up by hand and every later one goes through the tag pipeline.

**Finalise the CHANGELOG first.** pub refuses to publish quietly if the CHANGELOG does not mention
the version going up, and it is the release tool that normally dates that heading. A hand
publish skips that, so do it yourself, then commit:

```bash
cd packages/<name> && cider release   # ## Unreleased -> ## [1.0.0] - today
```

No bump: a first release publishes the version already in the pubspec, which is why the release
tool is the wrong one here. It always bumps, so it would turn 1.0.0 into 1.0.1.

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
`tool/release.dart` is the only route.

Tag the version you just published anyway, so the history is uniform. `publish.yml` checks pub.dev
first and exits green when the version is already up, so the tag costs nothing.

## Cutover to the split packages (one-time)

Order matters: siblings cannot claim `minted ^3.0.0` until core actually declares it, because a
workspace refuses to resolve a constraint no member satisfies. The preflight refuses to release a
package whose sibling constraint is older than what the tree builds against, so a forgotten step 2
fails loudly instead of shipping a wrong constraint that pub.dev can never take back.

1. **Release core.** `dart run tool/release.dart major --package minted` takes 2.0.0 to 3.0.0 and publishes
   through the tag pipeline as usual. Its own pub.dev tag pattern must already be `minted-{{version}}`
   (see [Tag format](#tag-format)).
2. **Tighten every sibling** from `minted: '>=2.0.0 <4.0.0'` to `minted: ^3.0.0`, one commit.
3. **Publish each sibling** by hand, per *First publish* above, then configure its tag pattern.
   `minted_contact` depends on `minted_network`, so publish network first; the rest are independent.

## What's pipeline-owned vs. hand-editable

The member's `CHANGELOG.md` and the `version:` field in its `pubspec.yaml` are
**pipeline-owned**: the tool reorders or overwrites manual edits to them. Hand-edits
will not survive the next release. The workspace-root `pubspec.yaml` carries no
`version:` at all, so it is outside this entirely.

The `## Unreleased` block in `CHANGELOG.md` is the tool's **input** — curated by
hand between releases. The tool bails if no package has one.

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

The tool refuses to proceed unless every check passes:

- `dart` resolvable (prefers `.fvm/flutter_sdk/bin/dart` if present, else PATH).
- `cider` on PATH, and able to report a version.
- `docker` on PATH, daemon running (runs the checks from `.github/lint-checks.json`
  via the linterpol image: `actionlint`, `rumdl`, `ryl`, no local installs).
- Working tree clean, on `main`, in sync with `origin/main` (fetches first).
- The member's `CHANGELOG.md` has a non-empty `## Unreleased` (or `## [Unreleased]`) section.
- `dart format` and `dart analyze` clean, run repo-wide from the root; `dart test` green,
  run inside the member.
- The target tag does not already exist locally or on the remote.
- No other member declares a constraint the release's new version would fall outside. A major
  otherwise leaves every dependent's caret excluding it, which stops `dart pub get` resolving the
  workspace. Those lines are rewritten in the same commit, and the plan names each one first.

`dart pub publish --dry-run` is *not* in preflight. It cross-checks three things
that must be satisfied simultaneously:

1. `pubspec.yaml`'s `version:` matches a CHANGELOG header.
2. No checked-in files are modified in the working tree.
3. The tarball builds and validates against pub.dev rules.

(1) only holds *after* `cider bump` + `cider release`. (2) only holds *after*
`git commit` — running the dry-run against the working tree mid-execute would
trip on the bump/release modifications. So the dry-run runs as step 6, after
the prep commit lands. Failure before that point is undone automatically, by a phase the execute
step advances as it goes:

- **Pre-commit failure** (bump or release errored, or a hook rejected the commit):
  restore `pubspec.yaml` + `CHANGELOG.md` from `HEAD`, along with any dependent pubspec the
  constraint repair rewrote. A half-repaired tree does not resolve, so they go back together.
- **Post-commit, pre-tag failure** (dry-run rejected the prep commit):
  `git reset --hard HEAD~1` to drop it, leaving the tree exactly as it was
  before the run started. No remote tag is ever created in this case — the
  validation gate sits between commit and tag, so there's nothing to clean
  up on `origin`.

The undo runs at most once, since the second phase drops a commit and doing that twice would
drop an innocent one. `Ctrl-C` routes through the same undo and exits 130, which Dart does not
do by itself.

After the dry-run passes, nothing is undone automatically: the tag and push window is yours, and
cleaning up there could discard real work if the push were the failing step. The tool prints the
recovery recipe instead.

## FVM note

If `.fvm/flutter_sdk/bin/dart` exists, the tool shells out to that binary directly, so every
`dart` subprocess gets the `.fvmrc`-pinned SDK even when a host `dart` started the run.
Otherwise it falls back to whatever `dart` is on `PATH` — a non-FVM contributor can run it
unchanged. SDK-version compatibility is enforced indirectly via `pub publish --dry-run`.
