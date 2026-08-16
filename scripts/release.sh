#!/usr/bin/env bash
# ===========================================================================
# release.sh
#
# Cut a versioned release of one workspace member. Offers the packages whose
# CHANGELOG opens with a populated `## Unreleased` block, bumps the chosen
# one's `version:` with `cider`, dates that block, commits both files, tags
# `<package>-<version>` and pushes commit + tag atomically. The tag push
# triggers .github/workflows/publish.yml, which publishes to pub.dev via OIDC.
#
# Laptop-only — does not run inside CI. Safe by default: preflight refuses to
# proceed on a dirty tree, wrong branch, origin mismatch, missing tooling,
# an empty/missing `## Unreleased` section, failing format/analyze/test, or a
# tag that already exists. `pub publish --dry-run` runs after the prep commit
# — it cross-checks pubspec version against CHANGELOG headers AND that no
# checked-in files are modified, so both signals must be satisfied before the
# tag is ever created. Failure mid-release auto-reverts via the EXIT trap:
# pre-commit failures restore files from HEAD; post-commit failures
# `git reset --hard HEAD~1` to drop the prep commit. Tag/push failures and
# (rare) server-side validation failures in publish.yml need manual recovery;
# the script prints the recipe.
#
# Tags are `<package>-<version>`, no `v` prefix: publish.yml routes on the
# package half, and pub.dev is configured per package with a matching
# `<package>-{{version}}` tag pattern.
#
# Note: if `.fvm/flutter_sdk/bin/dart` exists (FVM users), the script
# prepends it to PATH so plain `dart` resolves to the `.fvmrc`-pinned SDK.
# Otherwise it falls back to whatever `dart` is on PATH — a non-FVM
# contributor can run the script unchanged. SDK-version compatibility is
# enforced indirectly via `pub publish --dry-run` (post-commit). See
# CODESTYLE.md.
#
# Usage:
#   scripts/release.sh                      # fully interactive
#   scripts/release.sh patch                # bump type set, confirm on TTY
#   scripts/release.sh patch -p minted --yes  # non-interactive (CI-style)
#   scripts/release.sh --dry-run            # full preflight + plan, no side effects
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

# Set by the selection step below, from the packages that have unreleased work.
PACKAGE_DIR=""
PACKAGE_NAME=""

# What a version must look like, for the pubspec read and for the cider guard.
SEMVER_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$'

# Container-based lint checks (tool + args) and the linterpol image tag live in
# one manifest, shared with .github/workflows/repo.yml so this preflight and CI
# run the identical set and can't drift. Add a linter = one entry there; the
# preflight picks it up with no change here. https://github.com/LahaLuhem/linterpol
LINT_MANIFEST="${REPO_ROOT}/.github/lint-checks.json"

BUMP=""
PACKAGE=""
YES=0
DRY_RUN=0
TAG_MESSAGE=""

# Notes under a package's first `## ` heading, when that heading is `## Unreleased`; empty
# otherwise, so "no output" means "nothing to release here".
#
# Keep the regex a literal: `awk -v` unescapes its value, turning `\[?` into the character class
# `[?unreleased]`, which leaves `^## ` matching every heading there is.
unreleased_notes() {
    awk '
        # Only the first heading counts. A dated one on top means the last release consumed
        # everything, whatever sits further down.
        /^## / {
            if (!seen++ && tolower($0) ~ /^## \[?unreleased\]?/) { collecting = 1; next }
            exit
        }
        collecting { print }
    ' "$1"
}

# Publishable members with notes waiting, one directory per line. cider dates the heading on
# release, so a package drops off this list by construction once it ships.
pending_packages() {
    local dir
    for dir in packages/*/; do
        [ -f "${dir}pubspec.yaml" ] && [ -f "${dir}CHANGELOG.md" ] || continue
        grep -qE '^publish_to: *none' "${dir}pubspec.yaml" && continue
        [ -n "$(unreleased_notes "${dir}CHANGELOG.md" | tr -d '[:space:]-')" ] || continue
        printf '%s\n' "${dir%/}"
    done
}

# The tag is built from the declared name, not the directory: they match by convention only.
package_name_of() { awk '$1 == "name:" { print $2; exit }' "${1}/pubspec.yaml"; }

usage() {
    cat <<'USAGE'
release.sh — bump version, finalise CHANGELOG, commit, tag, push to origin.

Usage:
  scripts/release.sh [BUMP] [OPTIONS]

Arguments:
  BUMP            one of: major, minor, patch  (prompted if omitted on a TTY)

Options:
  -p, --package NAME      which workspace member to release. Must be one with a
                          populated `## Unreleased` block. Prompted if omitted on
                          a TTY and more than one qualifies; required otherwise.
  -y, --yes               skip the confirmation prompt (required for non-TTY)
  -n, --dry-run           run full preflight + print the plan, no side effects
  -m, --tag-message MSG   attach MSG as the tag message (creates an annotated,
                          signed-if-configured tag). Without this flag the tag
                          is lightweight.
  -h, --help              show this message

Preflight (all must pass):
  - `dart` resolvable (via `.fvm/flutter_sdk/bin/` if FVM is set up, else PATH)
  - cider on PATH
  - jq on PATH (reads the lint manifest, .github/lint-checks.json)
  - docker on PATH + daemon running (runs the lint checks via linterpol)
  - working tree clean, on `main`, in sync with origin/main (fetches first)
  - at least one package has a non-empty `## Unreleased` (or `## [Unreleased]`)
  - every check in .github/lint-checks.json clean (via linterpol image)
  - `dart format --output=none --set-exit-if-changed .` clean (repo-wide)
  - `dart --no-version-check analyze .` clean (repo-wide)
  - `dart test` green (inside the selected package)
  - computed tag unused locally AND on origin

Sequence, with PKG the selected member and DIR its directory:
  cider bump <BUMP>                                (DIR/pubspec.yaml version → new)
  cider release                                    (DIR/CHANGELOG.md ## Unreleased → ## <new> dated today)
  git add  DIR/pubspec.yaml DIR/CHANGELOG.md
  git commit -m "Prep for release PKG-<new>"
  dart pub -C DIR publish --dry-run                (validates clean committed state; resets HEAD~1 on fail)
  git tag PKG-<new>                                (lightweight by default; annotated when -m given)
  git push --atomic origin HEAD:main PKG-<new>     (triggers publish.yml, which routes on PKG)

Non-interactive example:
  scripts/release.sh patch --package minted --yes
USAGE
}

while (($#)); do
    case "$1" in
        major|minor|patch) BUMP="$1" ;;
        -p|--package)
            shift
            if [ $# -eq 0 ] || [ -z "${1}" ]; then
                printf '%s requires a non-empty NAME argument\n' "${0##*/} -p/--package" >&2
                exit 2
            fi
            PACKAGE="$1"
            ;;
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

prompt_package() {
    local index reply
    printf 'Packages with unreleased notes:\n' >&2
    for index in "${!PENDING[@]}"; do
        printf '  %d) %s\n' "$((index + 1))" "$(package_name_of "${PENDING[$index]}")" >&2
    done
    while :; do
        printf 'Release which? [1-%d]: ' "${#PENDING[@]}" >&2
        read -r reply
        if [[ "$reply" =~ ^[0-9]+$ ]] && [ "$reply" -ge 1 ] && [ "$reply" -le "${#PENDING[@]}" ]; then
            printf '%s\n' "${PENDING[$((reply - 1))]}"
            return 0
        fi
        printf 'Please enter a number between 1 and %d.\n' "${#PENDING[@]}" >&2
    done
}

# Names of every candidate, for the "which did you mean" error paths.
pending_names() {
    local dir
    for dir in "${PENDING[@]}"; do err "  $(package_name_of "$dir")"; done
}

# ---------------------------------------------------------------------------
# Resolve PACKAGE — which member to release
# ---------------------------------------------------------------------------
# A plain loop, not `mapfile`: stock macOS still ships bash 3.2, which has none.
PENDING=()
while IFS= read -r pending_dir; do
    PENDING+=("$pending_dir")
done < <(pending_packages)

if [ "${#PENDING[@]}" -eq 0 ]; then
    err 'No package has notes waiting under "## Unreleased", so there is nothing to release.'
    err 'Add them to that package CHANGELOG first, e.g.:'
    err '  ## Unreleased'
    err '  - Describe the change.'
    exit 1
fi

if [ -n "$PACKAGE" ]; then
    for pending_dir in "${PENDING[@]}"; do
        [ "$(package_name_of "$pending_dir")" = "$PACKAGE" ] && PACKAGE_DIR="$pending_dir"
    done
    if [ -z "$PACKAGE_DIR" ]; then
        err "'${PACKAGE}' is not a package with unreleased notes. Ready to release:"
        pending_names
        exit 2
    fi
elif [ "${#PENDING[@]}" -eq 1 ]; then
    PACKAGE_DIR="${PENDING[0]}"
elif is_tty; then
    PACKAGE_DIR="$(prompt_package)"
else
    err 'More than one package has unreleased notes; name one with --package.'
    pending_names
    exit 2
fi

PACKAGE_NAME="$(package_name_of "$PACKAGE_DIR")"
log "Selected ${PACKAGE_NAME} (${PACKAGE_DIR})."

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
# Run it, not just resolve it: a stale snapshot makes `pub global run` rebuild and print resolution
# chatter, so probing here fails fast and leaves the snapshot warm for the bump. From the member:
# `cider version` reads the pubspec it stands in, and the root carries no `version:`.
if ! cider_probe="$(cd "$PACKAGE_DIR" && cider version 2>&1)"; then
    err 'cider is installed but failed to run. Re-activate: dart pub global activate cider'
    exit 1
elif ! printf '%s\n' "$cider_probe" | grep -Eq "$SEMVER_PATTERN"; then
    err 'cider ran but reported no version. Re-activate: dart pub global activate cider'
    exit 1
fi
log 'cider available.'
if ! command -v jq >/dev/null 2>&1; then
    err 'jq not on PATH. The preflight reads the lint manifest'
    err '(.github/lint-checks.json) with jq. Install jq and retry.'
    exit 1
fi
log 'jq available.'
if ! command -v docker >/dev/null 2>&1; then
    err 'docker not on PATH. The preflight runs the lint checks (from'
    err '.github/lint-checks.json) via the linterpol image. Install Docker and retry.'
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    err 'docker is on PATH but the daemon is not responding. Start Docker and retry.'
    exit 1
fi
log 'docker available (lint checks run via linterpol).'

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
# Compute new version from pubspec.yaml
# ---------------------------------------------------------------------------
# From the file, not `cider version`: pub's `MSG : Resolving dependencies...` chatter reached stdout
# and became the version. Reading it here also leaves the `cider bump` guard two independent sides.
step "Compute new version for ${PACKAGE_NAME}"
current_version="$(awk '$1 == "version:" { print $2; exit }' "${PACKAGE_DIR}/pubspec.yaml")"
if [[ ! "$current_version" =~ $SEMVER_PATTERN ]]; then
    err "Could not read a SemVer version from ${PACKAGE_DIR}/pubspec.yaml; got '${current_version}'."
    exit 1
fi
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

# Pub names cannot contain a hyphen, so publish.yml splits this back apart on the first one,
# `minted-3.0.0-beta.1` included.
TAG="${PACKAGE_NAME}-${new_version}"
log "Tag:             ${TAG}"

# ---------------------------------------------------------------------------
# Preflight: tag collision (no `v` prefix — matches publish.yml + pub.dev)
# ---------------------------------------------------------------------------
step 'Preflight: tag collision'
if git rev-parse "refs/tags/${TAG}" >/dev/null 2>&1; then
    err "Tag '${TAG}' already exists locally."
    exit 1
elif git ls-remote --tags origin "refs/tags/${TAG}" | grep -q .; then
    err "Tag '${TAG}' already exists on origin."
    exit 1
else
    log "Tag '${TAG}' is unused locally and on origin."
fi

# No CHANGELOG preflight here: reaching this point means `pending_packages` already passed it.

# ---------------------------------------------------------------------------
# Preflight: lint / format / analyze / test (cheapest → slowest)
# ---------------------------------------------------------------------------
step 'Preflight: lint checks (via linterpol)'
# Image + checks come from the manifest shared with CI (repo.yml), so both gates
# run the identical set. Validate it parses and is non-empty first: an unreadable
# manifest must fail loudly here, not silently skip every lint.
if ! jq -e '.image and (.checks | length > 0)' "$LINT_MANIFEST" >/dev/null 2>&1; then
    err '.github/lint-checks.json is missing, malformed, or has no checks.'
    exit 1
fi
lint_image="$(jq -r '.image' "$LINT_MANIFEST")"
while IFS=$'\t' read -r lint_name lint_cmd; do
    log "lint: ${lint_name}"
    # $lint_cmd is intentionally unquoted so it word-splits into the tool + args
    # and glob-expands (e.g. scripts/*.sh) against the checkout, matching how
    # repo.yml's matrix invokes it.
    # shellcheck disable=SC2086
    if ! docker run --rm -v "${REPO_ROOT}:/work:ro" "$lint_image" $lint_cmd; then
        err "${lint_name} failed (via linterpol)."
        exit 1
    fi
done < <(jq -r '.checks[] | [.name, .cmd] | @tsv' "$LINT_MANIFEST")

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
# Per-package, unlike the repo-wide format and analyze above: the root holds no test/.
if ! (cd "$PACKAGE_DIR" && dart test); then
    err 'Test suite failed.'
    exit 1
fi

# `dart pub publish --dry-run` is NOT run here. Its "current version in
# CHANGELOG" check is meaningful only against the *post-bump* state — running
# it pre-bump would block the first release (0.0.0 has no `## 0.0.0` entry)
# and provide no extra signal on later releases. The dry-run runs after the
# bump + CHANGELOG finalisation in the execute phase, where the EXIT trap still
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
Releasing ${PACKAGE_NAME} from ${PACKAGE_DIR}

Will execute, in order:
  1. cider bump ${BUMP}                                    (${PACKAGE_DIR}/pubspec.yaml: ${current_version} → ${new_version})
  2. cider release                                         (${PACKAGE_DIR}/CHANGELOG.md: ## Unreleased → ## ${new_version} [dated today])
  3. git add  ${PACKAGE_DIR}/{pubspec.yaml,CHANGELOG.md}
  4. git commit -m "Prep for release ${TAG}"
  5. dart pub -C ${PACKAGE_DIR} publish --dry-run          (validate clean committed state; reset HEAD~1 on failure)
  6. git tag ${TAG}                                        ${tag_kind_note}
  7. git push --atomic origin HEAD:${MAIN_BRANCH} ${TAG}   (triggers .github/workflows/publish.yml)

publish.yml routes on the '${PACKAGE_NAME}' half of the tag and publishes ${new_version} via OIDC.
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
#
# On EXIT, not ERR: an explicit `exit 1` is no failing command, so ERR skipped the promised revert.
# EXIT also fires only once, and the phase-2 `reset --hard HEAD~1` must not run twice.
cider_phase=0
# ShellCheck's flow analysis doesn't follow assignments across a quoted trap string.
# shellcheck disable=SC2154
trap '
    rc=$?
    case "$cider_phase" in
        1)
            printf "[release] failure mid-release — restoring %s pubspec.yaml + CHANGELOG.md from HEAD\n" "$PACKAGE_DIR" >&2
            git checkout HEAD -- "${PACKAGE_DIR}/pubspec.yaml" "${PACKAGE_DIR}/CHANGELOG.md" 2>/dev/null || true
            ;;
        2)
            printf "[release] failure post-commit — git reset --hard HEAD~1 to drop the prep commit\n" >&2
            git reset --hard HEAD~1 2>/dev/null || true
            ;;
    esac
    exit $rc
' EXIT

cider_phase=1

step "cider bump ${BUMP}"
# Raw first so a cider failure still aborts; sed then drops pub's chatter, printing nothing on a
# no-match rather than tripping pipefail.
cider_bump_output="$(cd "$PACKAGE_DIR" && cider bump "$BUMP")"
bumped_version="$(
    printf '%s\n' "$cider_bump_output" |
        sed -n -E 's/^([0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?)$/\1/p' |
        tail -n 1
)"
if [ "$bumped_version" != "$new_version" ]; then
    err "cider produced '${bumped_version}' but expected '${new_version}'."
    err 'Aborting; pubspec.yaml will be reverted by the trap.'
    exit 1
fi

step 'cider release'
(cd "$PACKAGE_DIR" && cider release)

step "git add ${PACKAGE_DIR}/{pubspec.yaml,CHANGELOG.md}"
git add "${PACKAGE_DIR}/pubspec.yaml" "${PACKAGE_DIR}/CHANGELOG.md"

step "git commit -m \"Prep for release ${TAG}\""
git commit -m "Prep for release ${TAG}"

# Commit landed. Trap switches to "reset HEAD~1" mode for the dry-run window.
cider_phase=2

# Post-commit validation. By this point pubspec.yaml is at <new_version>,
# CHANGELOG.md has a `## <new_version>` block, AND the working tree is clean
# (both files committed). Pub's --dry-run cross-checks all three:
#   - version field matches a CHANGELOG header
#   - no uncommitted modifications to checked-in files
#   - the tarball builds and validates
# Running it pre-commit would trip the "checked-in files are modified" warning
# even though every other check passed. EXIT trap reverts via reset HEAD~1 on
# failure — keeps the local repo identical to its pre-release state and
# spares the user from creating + then deleting a remote tag.
step "dart pub -C ${PACKAGE_DIR} publish --dry-run"
dart pub -C "$PACKAGE_DIR" publish --dry-run

# Past this point: trap no longer auto-reverts. Manual recovery if the
# tag/push fails:
#   git tag -d ${TAG} 2>/dev/null
#   git reset --hard HEAD~1
cider_phase=0

step "git tag ${TAG}"
if [ -n "${TAG_MESSAGE}" ]; then
    # Annotated tag with explicit message — gpg signing honours user's git
    # config (`tag.gpgSign`, `user.signingKey`, etc.) because `git tag -m`
    # produces an annotated object that the config can attach a signature to.
    git tag -m "${TAG_MESSAGE}" "${TAG}"
else
    # Lightweight tag — just a ref pointer, no body, no signature. The
    # per-command `-c tag.gpgSign=false` overrides the user's global
    # `tag.gpgSign=true` for *this* invocation only; without it git would
    # auto-promote a plain `git tag NAME` into a signed-annotated tag and
    # demand a message via the editor. This bypass is the documented intent
    # of "no -m → lightweight" — the user explicitly opted in by omitting -m.
    git -c tag.gpgSign=false tag "${TAG}"
fi

step "git push --atomic origin HEAD:${MAIN_BRANCH} ${TAG}"
git push --atomic origin "HEAD:${MAIN_BRANCH}" "${TAG}"

step "Released ${TAG}"
log "Pushed commit + tag '${TAG}' to origin/${MAIN_BRANCH}."
log "Watch .github/workflows/publish.yml for the pub.dev upload."
