#!/usr/bin/env bash
# ===========================================================================
# release.sh
#
# Cut a versioned release of minted. Bumps the pubspec.yaml `version:` with
# `cider`, finalises the CHANGELOG.md `## Unreleased` section into a dated
# `## <new_version>` block, commits both files, creates a SemVer tag, and
# pushes commit + tag atomically. The tag push triggers
# .github/workflows/publish.yml, which then publishes to pub.dev via OIDC.
#
# Laptop-only — does not run inside CI. Safe by default: preflight refuses to
# proceed on a dirty tree, wrong branch, origin mismatch, missing tooling,
# an empty/missing `## Unreleased` section, failing format/analyze/test, or a
# tag that already exists. `pub publish --dry-run` runs after the prep commit
# — it cross-checks pubspec version against CHANGELOG headers AND that no
# checked-in files are modified, so both signals must be satisfied before the
# tag is ever created. Failure mid-release auto-reverts via the ERR trap:
# pre-commit failures restore files from HEAD; post-commit failures
# `git reset --hard HEAD~1` to drop the prep commit. Tag/push failures and
# (rare) server-side validation failures in publish.yml need manual recovery;
# the script prints the recipe.
#
# Tags are pushed without a `v` prefix, matching the trigger pattern in
# .github/workflows/publish.yml (`[0-9]+.[0-9]+.[0-9]+`) and pub.dev's
# canonical `{{version}}` convention.
#
# Note: if `.fvm/flutter_sdk/bin/dart` exists (FVM users), the script
# prepends it to PATH so plain `dart` resolves to the `.fvmrc`-pinned SDK.
# Otherwise it falls back to whatever `dart` is on PATH — a non-FVM
# contributor can run the script unchanged. SDK-version compatibility is
# enforced indirectly via `pub publish --dry-run` (post-commit). See
# CODESTYLE.md.
#
# Usage:
#   scripts/release.sh                # fully interactive
#   scripts/release.sh patch          # bump type set, confirm on TTY
#   scripts/release.sh patch --yes    # non-interactive (CI-style)
#   scripts/release.sh --dry-run      # full preflight + plan, no side effects
# ===========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Resolve `dart`: prefer the project's FVM symlink (gives the `.fvmrc`-pinned
# SDK); fall back to whatever's on PATH for non-FVM users. Done before
# anything that calls `dart` so the rest of the script can use plain
# invocations.
if [ -x "${REPO_ROOT}/.fvm/flutter_sdk/bin/dart" ]; then
    PATH="${REPO_ROOT}/.fvm/flutter_sdk/bin:${PATH}"
    DART_SOURCE="${REPO_ROOT}/.fvm/flutter_sdk/bin/dart (.fvmrc-pinned via FVM)"
elif command -v dart >/dev/null 2>&1; then
    DART_SOURCE="$(command -v dart) (host PATH — no .fvm/flutter_sdk symlink)"
else
    printf "[release] ERROR: no 'dart' on PATH and no .fvm/flutter_sdk/bin/dart found.\n" >&2
    printf "[release] Install Dart 3.12+, or run 'fvm install' from the project root.\n" >&2
    exit 1
fi

MAIN_BRANCH="main"

# Lint tooling (shellcheck + actionlint) ships in this image, so the preflight
# needs only Docker locally, not hand-installed linters. Bump the tag (or pin a
# digest) here in one place. https://github.com/LahaLuhem/linterpol
LINTERPOL_IMAGE="ghcr.io/lahaluhem/linterpol:latest"

BUMP=""
YES=0
DRY_RUN=0
TAG_MESSAGE=""

usage() {
    cat <<'USAGE'
release.sh — bump version, finalise CHANGELOG, commit, tag, push to origin.

Usage:
  scripts/release.sh [BUMP] [OPTIONS]

Arguments:
  BUMP            one of: major, minor, patch  (prompted if omitted on a TTY)

Options:
  -y, --yes               skip the confirmation prompt (required for non-TTY)
  -n, --dry-run           run full preflight + print the plan, no side effects
  -m, --tag-message MSG   attach MSG as the tag message (creates an annotated,
                          signed-if-configured tag). Without this flag the tag
                          is lightweight.
  -h, --help              show this message

Preflight (all must pass):
  - `dart` resolvable (via `.fvm/flutter_sdk/bin/` if FVM is set up, else PATH)
  - cider on PATH
  - docker on PATH + daemon running (lints scripts + workflows via linterpol)
  - working tree clean, on `main`, in sync with origin/main (fetches first)
  - CHANGELOG.md has a non-empty `## Unreleased` (or `## [Unreleased]`) section
  - `shellcheck scripts/*.sh` clean (via linterpol image)
  - `actionlint` clean on `.github/workflows/` (via linterpol image)
  - `dart format --output=none --set-exit-if-changed .` clean
  - `dart --no-version-check analyze .` clean
  - `dart test` green
  - computed tag unused locally AND on origin

Sequence:
  cider bump <BUMP>                                (pubspec.yaml version → new)
  cider release                                    (CHANGELOG.md ## Unreleased → ## <new> dated today)
  git add  pubspec.yaml CHANGELOG.md
  git commit -m "Prep for release <new>"
  dart pub publish --dry-run                       (validates clean committed state; resets HEAD~1 on fail)
  git tag <new>                                    (lightweight by default; annotated when -m given)
  git push --atomic origin HEAD:main <new>         (triggers publish.yml)

Non-interactive example:
  scripts/release.sh patch --yes
USAGE
}

while (($#)); do
    case "$1" in
        major|minor|patch) BUMP="$1" ;;
        -y|--yes)          YES=1 ;;
        -n|--dry-run)      DRY_RUN=1 ;;
        -m|--tag-message)
            shift
            if [ $# -eq 0 ] || [ -z "${1}" ]; then
                printf '%s requires a non-empty MSG argument\n' "${0##*/} -m/--tag-message" >&2
                exit 2
            fi
            TAG_MESSAGE="$1"
            ;;
        -h|--help)         usage; exit 0 ;;
        *)                 printf 'unknown arg: %s (use --help)\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

log()  { printf '[release] %s\n' "$*"; }
step() { printf '\n[release] == %s ==\n' "$*"; }
err()  { printf '[release] ERROR: %s\n' "$*" >&2; }

is_tty() { [ -t 0 ]; }

prompt_bump() {
    local reply
    while :; do
        printf 'Bump type [major/minor/patch] (default: patch): ' >&2
        read -r reply
        reply="${reply:-patch}"
        case "$reply" in
            major|minor|patch) echo "$reply"; return 0 ;;
            *) printf 'Please enter major, minor, or patch.\n' >&2 ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Resolve BUMP
# ---------------------------------------------------------------------------
if [ -z "$BUMP" ]; then
    if is_tty; then
        BUMP="$(prompt_bump)"
    else
        err 'BUMP argument required in non-interactive mode (one of: major, minor, patch).'
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# Preflight: tooling (fail fast — cheapest checks first)
# ---------------------------------------------------------------------------
step 'Preflight: tooling'
log "Using Dart from: ${DART_SOURCE}"
if ! command -v cider >/dev/null 2>&1; then
    err 'cider not on PATH. Install: dart pub global activate cider'
    exit 1
fi
log 'cider available.'
if ! command -v docker >/dev/null 2>&1; then
    err 'docker not on PATH. The preflight lints scripts + workflows via'
    err "the ${LINTERPOL_IMAGE} image. Install Docker and retry."
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    err 'docker is on PATH but the daemon is not responding. Start Docker and retry.'
    exit 1
fi
log 'docker available (shellcheck + actionlint run via linterpol).'

# ---------------------------------------------------------------------------
# Preflight: git state
# ---------------------------------------------------------------------------
step 'Preflight: git state'
log 'Fetching origin (with tag prune)...'
git fetch origin --quiet --tags --prune --prune-tags

# Initialise the rollup flag — `set -u` would trip the later check if every
# branch below passed and no branch ever assigned `fail=1`.
fail=0

if [ -n "$(git status --porcelain)" ]; then
    err 'Working tree is dirty. Commit or stash first.'
    fail=1
else
    log 'Working tree clean.'
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$current_branch" != "$MAIN_BRANCH" ]; then
    err "Current branch is '$current_branch'; expected '$MAIN_BRANCH'."
    fail=1
else
    log "On branch '$MAIN_BRANCH'."
fi

local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse "origin/${MAIN_BRANCH}" 2>/dev/null || echo '')"
if [ -z "$remote_head" ]; then
    err "origin/${MAIN_BRANCH} not found."
    fail=1
elif [ "$local_head" != "$remote_head" ]; then
    err "HEAD ($local_head) is not at origin/${MAIN_BRANCH} ($remote_head). Pull / push first."
    fail=1
else
    log "In sync with origin/${MAIN_BRANCH}."
fi

[ "$fail" -eq 1 ] && { err 'Git-state preflight failed — aborting.'; exit 1; }

# ---------------------------------------------------------------------------
# Compute new version from pubspec.yaml (via cider)
# ---------------------------------------------------------------------------
step 'Compute new version'
current_version="$(cider version)"
log "Current version: ${current_version}"

# Plain SemVer arithmetic. Pre-release / build metadata is stripped so the
# bump produces a clean X.Y.Z — cider's own behaviour for a plain X.Y.Z
# input matches this, so the two will agree.
IFS='.' read -r cur_major cur_minor cur_patch <<< "${current_version%%[+-]*}"
case "$BUMP" in
    major) new_version="$((cur_major + 1)).0.0" ;;
    minor) new_version="${cur_major}.$((cur_minor + 1)).0" ;;
    patch) new_version="${cur_major}.${cur_minor}.$((cur_patch + 1))" ;;
esac
log "New version:     ${new_version}  (${BUMP} bump)"

# ---------------------------------------------------------------------------
# Preflight: tag collision (no `v` prefix — matches publish.yml + pub.dev)
# ---------------------------------------------------------------------------
step 'Preflight: tag collision'
if git rev-parse "refs/tags/${new_version}" >/dev/null 2>&1; then
    err "Tag '${new_version}' already exists locally."
    exit 1
elif git ls-remote --tags origin "refs/tags/${new_version}" | grep -q .; then
    err "Tag '${new_version}' already exists on origin."
    exit 1
else
    log "Tag '${new_version}' is unused locally and on origin."
fi

# ---------------------------------------------------------------------------
# Preflight: `## Unreleased` populated in CHANGELOG.md
# ---------------------------------------------------------------------------
step 'Preflight: CHANGELOG'
if ! grep -qiE '^## \[?Unreleased\]?' CHANGELOG.md 2>/dev/null; then
    err "CHANGELOG.md is missing a '## Unreleased' section."
    err 'Add notes for this release first, e.g.:'
    err '  ## Unreleased'
    err '  - Describe the change.'
    exit 1
fi

unreleased_block="$(awk '
    BEGIN{found=0}
    tolower($0) ~ /^## \[?unreleased\]?/{found=1; next}
    found && /^## /{exit}
    found{print}
' CHANGELOG.md)"

if [ -z "$(printf '%s' "$unreleased_block" | tr -d '[:space:]-')" ]; then
    err "CHANGELOG.md has '## Unreleased' but no entries beneath it."
    err 'Populate the section before re-running.'
    exit 1
fi
log "'## Unreleased' populated."

# ---------------------------------------------------------------------------
# Preflight: lint / format / analyze / test (cheapest → slowest)
# ---------------------------------------------------------------------------
step 'Preflight: shellcheck scripts/ (via linterpol)'
if ! docker run --rm -v "${REPO_ROOT}:/work:ro" "$LINTERPOL_IMAGE" shellcheck scripts/*.sh; then
    err 'shellcheck failed on one or more shell scripts.'
    exit 1
fi

step 'Preflight: actionlint .github/workflows/ (via linterpol)'
if ! docker run --rm -v "${REPO_ROOT}:/work:ro" "$LINTERPOL_IMAGE" actionlint; then
    err 'actionlint failed on one or more workflows.'
    exit 1
fi

step 'Preflight: dart format'
if ! dart format --output=none --set-exit-if-changed .; then
    err "Formatting check failed. Run 'dart format .' and commit."
    exit 1
fi

step 'Preflight: dart --no-version-check analyze'
if ! dart --no-version-check analyze .; then
    err 'Static analysis failed.'
    exit 1
fi

step 'Preflight: dart test'
if ! dart test; then
    err 'Test suite failed.'
    exit 1
fi

# `dart pub publish --dry-run` is NOT run here. Its "current version in
# CHANGELOG" check is meaningful only against the *post-bump* state — running
# it pre-bump would block the first release (0.0.0 has no `## 0.0.0` entry)
# and provide no extra signal on later releases. The dry-run runs after the
# bump + CHANGELOG finalisation in the execute phase, where the ERR trap still
# auto-reverts those files on failure (cider_phase=1 window).

# ---------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------
step 'Plan'
if [ -n "${TAG_MESSAGE}" ]; then
    tag_kind_note="(annotated, message: \"${TAG_MESSAGE}\")"
else
    tag_kind_note="(lightweight; pass -m \"MSG\" to annotate)"
fi
cat <<PLAN
Will execute, in order:
  1. cider bump ${BUMP}                                    (pubspec.yaml: ${current_version} → ${new_version})
  2. cider release                                         (CHANGELOG.md: ## Unreleased → ## ${new_version} [dated today])
  3. git add  pubspec.yaml CHANGELOG.md
  4. git commit -m "Prep for release ${new_version}"
  5. dart pub publish --dry-run                            (validate clean committed state; reset HEAD~1 on failure)
  6. git tag ${new_version}                                ${tag_kind_note}
  7. git push --atomic origin HEAD:${MAIN_BRANCH} ${new_version}   (triggers .github/workflows/publish.yml)

publish.yml will then build & publish ${new_version} to pub.dev via OIDC.
PLAN

if [ "$DRY_RUN" -eq 1 ]; then
    log 'Dry-run mode — preflight passed; nothing executed.'
    exit 0
fi

# ---------------------------------------------------------------------------
# Confirm
# ---------------------------------------------------------------------------
if [ "$YES" -eq 0 ]; then
    if is_tty; then
        printf '\nProceed with release? [y/N] '
        read -r reply
        case "$reply" in
            y|Y|yes|YES) ;;
            *) log 'Aborted.'; exit 0 ;;
        esac
    else
        err 'Refusing to proceed without --yes in non-interactive mode.'
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
# Auto-revert pipeline-owned files if anything fails between the `cider bump`
# step and the `dart pub publish --dry-run` validation. The revert strategy
# depends on how far we got:
#
#   cider_phase=1 — bump/release ran, no commit yet → restore from HEAD
#   cider_phase=2 — prep commit landed, dry-run pending → reset --hard HEAD~1
#   cider_phase=0 — past dry-run (tag/push window) OR before bump → no auto-revert
#
# `cider_phase=0` after dry-run because the tag + push window is the user's
# domain by then; automatic cleanup would silently nuke real work if the push
# happened to be the failing step.
cider_phase=0
# ShellCheck's flow analysis doesn't follow assignments across a quoted trap string.
# shellcheck disable=SC2154
trap '
    rc=$?
    case "$cider_phase" in
        1)
            printf "[release] failure mid-release — restoring pubspec.yaml + CHANGELOG.md from HEAD\n" >&2
            git checkout HEAD -- pubspec.yaml CHANGELOG.md 2>/dev/null || true
            ;;
        2)
            printf "[release] failure post-commit — git reset --hard HEAD~1 to drop the prep commit\n" >&2
            git reset --hard HEAD~1 2>/dev/null || true
            ;;
    esac
    exit $rc
' ERR

cider_phase=1

step "cider bump ${BUMP}"
bumped_version="$(cider bump "$BUMP")"
if [ "$bumped_version" != "$new_version" ]; then
    err "cider produced '${bumped_version}' but expected '${new_version}'."
    err 'Aborting; pubspec.yaml will be reverted by the trap.'
    exit 1
fi

step 'cider release'
cider release

step 'git add pubspec.yaml CHANGELOG.md'
git add pubspec.yaml CHANGELOG.md

step "git commit -m \"Prep for release ${new_version}\""
git commit -m "Prep for release ${new_version}"

# Commit landed. Trap switches to "reset HEAD~1" mode for the dry-run window.
cider_phase=2

# Post-commit validation. By this point pubspec.yaml is at <new_version>,
# CHANGELOG.md has a `## <new_version>` block, AND the working tree is clean
# (both files committed). Pub's --dry-run cross-checks all three:
#   - version field matches a CHANGELOG header
#   - no uncommitted modifications to checked-in files
#   - the tarball builds and validates
# Running it pre-commit would trip the "checked-in files are modified" warning
# even though every other check passed. ERR trap reverts via reset HEAD~1 on
# failure — keeps the local repo identical to its pre-release state and
# spares the user from creating + then deleting a remote tag.
step 'dart pub publish --dry-run'
dart pub publish --dry-run

# Past this point: trap no longer auto-reverts. Manual recovery if the
# tag/push fails:
#   git tag -d ${new_version} 2>/dev/null
#   git reset --hard HEAD~1
cider_phase=0

step "git tag ${new_version}"
if [ -n "${TAG_MESSAGE}" ]; then
    # Annotated tag with explicit message — gpg signing honours user's git
    # config (`tag.gpgSign`, `user.signingKey`, etc.) because `git tag -m`
    # produces an annotated object that the config can attach a signature to.
    git tag -m "${TAG_MESSAGE}" "${new_version}"
else
    # Lightweight tag — just a ref pointer, no body, no signature. The
    # per-command `-c tag.gpgSign=false` overrides the user's global
    # `tag.gpgSign=true` for *this* invocation only; without it git would
    # auto-promote a plain `git tag NAME` into a signed-annotated tag and
    # demand a message via the editor. This bypass is the documented intent
    # of "no -m → lightweight" — the user explicitly opted in by omitting -m.
    git -c tag.gpgSign=false tag "${new_version}"
fi

step "git push --atomic origin HEAD:${MAIN_BRANCH} ${new_version}"
git push --atomic origin "HEAD:${MAIN_BRANCH}" "${new_version}"

step "Released ${new_version}"
log "Pushed commit + tag '${new_version}' to origin/${MAIN_BRANCH}."
log "Watch .github/workflows/publish.yml for the pub.dev upload."
