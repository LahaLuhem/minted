import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import '../io/process_runner.dart';
import '../io/release_ui.dart';
import '../io/repo.dart';
import '../parsing/pubspec_fields.dart';
import '../release_abort.dart';
import '../release_options.dart';
import '../versioning/bump_type.dart';
import '../versioning/release_tag.dart';
import 'rollback.dart';

/// Cuts a versioned release of one workspace member.
///
/// Order is the contract: gates run cheapest-first, and the execute phase advances one [Rollback]
/// as it goes.
class ReleaseFlow {
  new({required this.repo, required this.runner, required this.ui, required this.options});

  final Repo repo;
  final ProcessRunner runner;
  final ReleaseUi ui;
  final ReleaseOptions options;

  late final String _dart;

  Future<void> run() async {
    final selected = _resolvePackage();
    final bump = _resolveBump();

    ui.log('Selected ${selected.name} (${selected.dir}).');

    _preflightTooling(selected);
    _preflightGitState();

    final pubspec = repo.readFile('${selected.dir}/pubspec.yaml');
    final version = _computeVersion(selected, pubspec, bump);
    final tag = releaseTag(package: selected.name, version: version.next);

    ui.log('Tag:             $tag');

    _preflightSiblingConstraints(selected, pubspec);
    _preflightTagCollision(tag);
    await _preflightLint();
    await _preflightDart(selected);

    _printPlan(selected: selected, bump: bump, version: version, tag: tag);

    if (options.dryRun) {
      ui.log('Dry-run mode, preflight passed; nothing executed.');

      return;
    }

    if (!_confirmed()) {
      ui.log('Aborted.');

      return;
    }

    await _execute(selected: selected, bump: bump, next: version.next, tag: tag);
  }

  // ── Resolution ────────────────────────────────────────────────────────────

  PendingPackage _resolvePackage() {
    final pending = repo.pendingPackages();
    if (pending.isEmpty) {
      throw ReleaseAbort.all([
        'No package has notes waiting under "## Unreleased", so there is nothing to release.',
        'Add them to that package CHANGELOG first, e.g.:',
        '  ## Unreleased',
        '  - Describe the change.',
      ]);
    }

    final byName = {for (final candidate in pending) candidate.name: candidate};
    final names = byName.keys.toList(growable: false);
    if (options.package == null && pending.length == 1) return pending.single;

    final requested = options.package ?? ui.choosePackage(names);
    if (requested == null) {
      throw ReleaseAbort.all([
        'More than one package has unreleased notes; name one with --package.',
        ...names.map((name) => '  $name'),
      ], code: usageErrorCode);
    }

    return byName[requested] ??
        (throw ReleaseAbort.all([
          "'$requested' is not a package with unreleased notes. Ready to release:",
          ...names.map((name) => '  $name'),
        ], code: usageErrorCode));
  }

  BumpType _resolveBump() {
    final bump = options.bump ?? ui.chooseBump();
    if (bump == null) {
      throw ReleaseAbort(
        'BUMP argument required in non-interactive mode (one of: ${BumpType.names}).',
        code: usageErrorCode,
      );
    }

    return bump;
  }

  // ── Preflight ─────────────────────────────────────────────────────────────

  void _preflightTooling(PendingPackage selected) {
    ui.step('Preflight: tooling');

    _dart = _resolveDart();
    ui.log('Using Dart from: $_dart');

    // Run cider rather than just resolve it: a stale snapshot makes `pub global run` rebuild and
    // print resolution chatter, so probing here fails fast and leaves the snapshot warm.
    final probe = runner.capture('cider', ['version'], workingDirectory: _dirOf(selected));
    if (probe.notFound) {
      throw ReleaseAbort('cider not on PATH. Install: dart pub global activate cider');
    }
    if (!probe.ok) {
      throw ReleaseAbort(
        'cider is installed but failed to run. Re-activate: dart pub global activate cider',
      );
    }
    if (!_reportsSemver('${probe.stdout}\n${probe.stderr}')) {
      throw ReleaseAbort(
        'cider ran but reported no version. Re-activate: dart pub global activate cider',
      );
    }
    ui.log('cider available.');

    final docker = runner.capture('docker', ['info']);
    if (docker.notFound) {
      throw ReleaseAbort.all([
        'docker not on PATH. The preflight runs the lint checks (from',
        '${Repo.lintManifestPath}) via the linterpol image. Install Docker and retry.',
      ]);
    }
    if (!docker.ok) {
      throw ReleaseAbort(
        'docker is on PATH but the daemon is not responding. Start Docker and retry.',
      );
    }
    ui.log('docker available (lint checks run via linterpol).');
  }

  void _preflightGitState() {
    ui
      ..step('Preflight: git state')
      ..log('Fetching origin (with tag prune)...');
    _git(['fetch', 'origin', '--quiet', '--tags', '--prune', '--prune-tags']);

    // Collected rather than fail-fast, so one run tells the user everything that is wrong.
    final failures = <String>[];

    if (_git(['status', '--porcelain']).stdout.isNotEmpty) {
      failures.add('Working tree is dirty. Commit or stash first.');
    } else {
      ui.log('Working tree clean.');
    }

    final branch = _git(['rev-parse', '--abbrev-ref', 'HEAD']).stdout;
    if (branch != Repo.mainBranch) {
      failures.add("Current branch is '$branch'; expected '${Repo.mainBranch}'.");
    } else {
      ui.log("On branch '${Repo.mainBranch}'.");
    }

    final localHead = _git(['rev-parse', 'HEAD']).stdout;
    final remoteHead = runner.capture('git', [
      'rev-parse',
      'origin/${Repo.mainBranch}',
    ], workingDirectory: repo.root);
    if (!remoteHead.ok || remoteHead.stdout.isEmpty) {
      failures.add('origin/${Repo.mainBranch} not found.');
    } else if (localHead != remoteHead.stdout) {
      failures.add(
        'HEAD ($localHead) is not at origin/${Repo.mainBranch} (${remoteHead.stdout}). '
        'Pull / push first.',
      );
    } else {
      ui.log('In sync with origin/${Repo.mainBranch}.');
    }

    if (failures.isNotEmpty) {
      throw ReleaseAbort.all([...failures, 'Git-state preflight failed, aborting.']);
    }
  }

  ({String current, String next}) _computeVersion(
    PendingPackage selected,
    String pubspec,
    BumpType bump,
  ) {
    ui.step('Compute new version for ${selected.name}');

    // From the file rather than `cider version`: pub's resolution chatter reached stdout and became
    // the version once. Reading it here also leaves the cider cross-check two independent sides.
    final current = pubspecVersion(pubspec);
    if (current == null || !semverPattern.hasMatch(current)) {
      throw ReleaseAbort(
        "Could not read a SemVer version from ${selected.dir}/pubspec.yaml; got '$current'.",
      );
    }

    final next = bump.applyTo(current);
    ui
      ..log('Current version: $current')
      ..log('New version:     $next  (${bump.name} bump)');

    return (current: current, next: next);
  }

  void _preflightSiblingConstraints(PendingPackage selected, String pubspec) {
    ui.step('Preflight: sibling constraints');

    final stale = staleConstraints(
      selectedName: selected.name,
      selectedPubspec: pubspec,
      memberPubspecs: repo.memberPubspecs(),
    );

    if (stale.isNotEmpty) {
      throw ReleaseAbort.all([
        ...stale.expand((constraint) => _staleConstraintReport(selected.name, constraint)),
        'Sibling-constraint preflight failed, aborting.',
      ]);
    }

    ui.log('Sibling constraints match the tree.');
  }

  /// The two lines one stale constraint is reported over.
  Iterable<String> _staleConstraintReport(String selectedName, StaleConstraint constraint) {
    final summary =
        '$selectedName wants ${constraint.member} ${constraintOf(constraint.declared)}, but this '
        'tree builds against ${constraint.member} ${constraint.treeMajor}.x.';

    return [summary, 'Tighten the constraint before publishing.'];
  }

  void _preflightTagCollision(String tag) {
    ui.step('Preflight: tag collision');

    if (runner.capture('git', ['rev-parse', 'refs/tags/$tag'], workingDirectory: repo.root).ok) {
      throw ReleaseAbort("Tag '$tag' already exists locally.");
    }
    if (_git(['ls-remote', '--tags', 'origin', 'refs/tags/$tag']).stdout.isNotEmpty) {
      throw ReleaseAbort("Tag '$tag' already exists on origin.");
    }

    ui.log("Tag '$tag' is unused locally and on origin.");
  }

  Future<void> _preflightLint() async {
    final manifest = repo.lintManifest();

    for (final check in manifest.checks) {
      // Through the image's own shell, so a glob in the manifest expands against the mounted
      // checkout. That is what repo.yml's matrix does, and the manifest is written for it.
      final result = await ui.task(
        'lint: ${check.name}',
        () => runner.run('docker', [
          'run',
          '--rm',
          '-v',
          '${repo.root}:/work:ro',
          manifest.image,
          'sh',
          '-c',
          check.cmd,
        ]),
      );

      _abortOnFailure(result, '${check.name} failed (via linterpol).');
    }
  }

  /// The repo-wide format and analyze gates, then the selected member's suite.
  ///
  /// `pub publish --dry-run` is absent on purpose: it only means anything post-bump, so it runs in
  /// [_execute] where the rollback covers it.
  Future<void> _preflightDart(PendingPackage selected) async {
    _abortOnFailure(
      await ui.task(
        'dart format',
        () => _dartRun(['format', '--output=none', '--set-exit-if-changed', '.']),
      ),
      "Formatting check failed. Run 'dart format .' and commit.",
    );

    _abortOnFailure(
      await ui.task('dart analyze', () => _dartRun(['--no-version-check', 'analyze', '.'])),
      'Static analysis failed.',
    );

    // Per-package, unlike the repo-wide gates above: the root holds no member suite.
    _abortOnFailure(
      await ui.task('dart test', () => _dartRun(['test'], workingDirectory: _dirOf(selected))),
      'Test suite failed.',
    );
  }

  // ── Plan and confirmation ─────────────────────────────────────────────────

  void _printPlan({
    required PendingPackage selected,
    required BumpType bump,
    required ({String current, String next}) version,
    required String tag,
  }) {
    final tagKind = options.tagMessage == null
        ? '(lightweight; pass -m "MSG" to annotate)'
        : '(annotated, message: "${options.tagMessage}")';

    ui
      ..step('Plan')
      ..block(
        '''
Releasing ${selected.name} from ${selected.dir}

Will execute, in order:
  1. cider bump ${bump.name}                                (${selected.dir}/pubspec.yaml: ${version.current} to ${version.next})
  2. cider release                                         (${selected.dir}/CHANGELOG.md: ## Unreleased to ## ${version.next} [dated today])
  3. git add  ${selected.dir}/{pubspec.yaml,CHANGELOG.md}
  4. git commit -m "Prep for release $tag"
  5. dart pub -C ${selected.dir} publish --dry-run          (validate clean committed state; reset HEAD~1 on failure)
  6. git tag $tag                                $tagKind
  7. git push --atomic origin HEAD:${Repo.mainBranch} $tag   (triggers .github/workflows/publish.yml)

publish.yml routes on the '${selected.name}' half of the tag and publishes ${version.next} via OIDC.''',
      );
  }

  bool _confirmed() {
    if (options.skipConfirmation) return true;

    if (!ui.isInteractive) {
      throw ReleaseAbort(
        'Refusing to proceed without --yes in non-interactive mode.',
        code: usageErrorCode,
      );
    }

    return ui.confirmRelease();
  }

  // ── Execute ───────────────────────────────────────────────────────────────

  Future<void> _execute({
    required PendingPackage selected,
    required BumpType bump,
    required String next,
    required String tag,
  }) async {
    final rollback = Rollback(
      runner: runner,
      ui: ui,
      repoRoot: repo.root,
      packageDir: selected.dir,
    );

    // Dart neither unwinds reliably on Ctrl-C nor reports 130. Rolling back before the `exit` is
    // what makes it safe, since `exit` skips the `finally` below.
    final interrupts = ProcessSignal.sigint.watch().listen((_) {
      ui.error('Interrupted.');
      rollback.run();
      exit(interruptedCode);
    });

    try {
      rollback.phase = .filesTouched;

      ui.step('cider bump ${bump.name}');
      final bumped = runner.capture('cider', [
        'bump',
        bump.name,
      ], workingDirectory: _dirOf(selected));
      if (!bumped.ok) throw ReleaseAbort('cider bump failed. ${bumped.stderr}'.trim());

      final reported = _lastSemverLine(bumped.stdout);
      if (reported != next) {
        throw ReleaseAbort.all([
          "cider produced '$reported' but expected '$next'.",
          'Aborting; pubspec.yaml will be restored.',
        ]);
      }

      _abortOnFailure(
        await ui.task(
          'cider release',
          () => runner.run('cider', ['release'], workingDirectory: _dirOf(selected)),
        ),
        'cider release failed.',
      );

      ui.step('git add ${selected.dir}/{pubspec.yaml,CHANGELOG.md}');
      _git([
        'add',
        '${selected.dir}/pubspec.yaml',
        '${selected.dir}/CHANGELOG.md',
      ], failure: 'Could not stage the release files.');

      ui.step('git commit -m "Prep for release $tag"');
      _git([
        'commit',
        '-m',
        'Prep for release $tag',
      ], failure: 'Could not commit the release files.');

      rollback.phase = .commitLanded;

      // Post-commit on purpose. Pub cross-checks the version field against a CHANGELOG header AND
      // that no checked-in file is modified, so both only hold once the prep commit has landed.
      _abortOnFailure(
        await ui.task(
          'dart pub -C ${selected.dir} publish --dry-run',
          () => _dartRun(['pub', '-C', selected.dir, 'publish', '--dry-run']),
        ),
        'Publish dry-run failed.',
      );

      // Past here the tag and push window is the user's, so nothing is undone automatically.
      rollback.phase = .none;

      await _tagAndPush(tag: tag, mainBranch: Repo.mainBranch);

      ui
        ..step('Released $tag')
        ..log("Pushed commit + tag '$tag' to origin/${Repo.mainBranch}.")
        ..log('Watch .github/workflows/publish.yml for the pub.dev upload.');
    } finally {
      rollback.run();
      await interrupts.cancel();
    }
  }

  Future<void> _tagAndPush({required String tag, required String mainBranch}) async {
    try {
      ui.step('git tag $tag');
      final message = options.tagMessage;
      if (message == null) {
        // Lightweight: a bare `git tag NAME` under a global `tag.gpgSign=true` would be promoted to
        // signed-annotated and demand a message. Omitting -m is how the user opts out.
        _git(['-c', 'tag.gpgSign=false', 'tag', tag], failure: 'Could not create the tag.');
      } else {
        _git(['tag', '-m', message, tag], failure: 'Could not create the annotated tag.');
      }

      _abortOnFailure(
        await ui.task(
          'git push --atomic origin HEAD:$mainBranch $tag',
          () => runner.run('git', [
            'push',
            '--atomic',
            'origin',
            'HEAD:$mainBranch',
            tag,
          ], workingDirectory: repo.root),
        ),
        'Push failed.',
      );
    } on ReleaseAbort catch (abort, stackTrace) {
      Error.throwWithStackTrace(
        ReleaseAbort.all([
          ...abort.messages,
          'The prep commit is still local. Recover with:',
          '  git tag -d $tag',
          '  git reset --hard HEAD~1',
        ], code: abort.code),
        stackTrace,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dirOf(PendingPackage selected) => repo.absolute(selected.dir);

  /// Runs git at the repo root, aborting with [failure] when it reports one.
  CommandResult _git(List<String> arguments, {String? failure}) {
    final result = runner.capture('git', arguments, workingDirectory: repo.root);
    if (failure != null && !result.ok) {
      throw ReleaseAbort('$failure ${result.stderr}'.trim());
    }

    return result;
  }

  Future<CommandResult> _dartRun(List<String> arguments, {String? workingDirectory}) =>
      runner.run(_dart, arguments, workingDirectory: workingDirectory ?? repo.root);

  /// Aborts with [failure] when [result] failed, carrying what the command printed.
  ///
  /// Captured gates print nothing themselves, so this is the only evidence the user gets.
  void _abortOnFailure(CommandResult result, String failure) {
    if (result.ok) return;

    final output = [result.stdout, result.stderr].where((part) => part.isNotEmpty);

    throw ReleaseAbort.all([failure, ...output.expand(const LineSplitter().convert)]);
  }

  /// The `dart` to shell out to: the FVM symlink first, then PATH.
  ///
  /// Resolved rather than taken from [Platform.resolvedExecutable], so subprocesses get the
  /// `.fvmrc`-pinned SDK even when a host `dart` started this script.
  String _resolveDart() {
    const pinned = '.fvm/flutter_sdk/bin/dart';
    if (repo.fileExists(pinned)) return repo.absolute(pinned);

    if (runner.capture('dart', ['--version']).notFound) {
      throw ReleaseAbort.all([
        "no 'dart' on PATH and no $pinned found.",
        "Install Dart 3.13+, or run 'fvm install' from the project root.",
      ]);
    }

    return 'dart';
  }

  /// Whether any line of [output] is entirely a version, which is cider reporting one.
  bool _reportsSemver(String output) =>
      const LineSplitter().convert(output).any((line) => semverPattern.hasMatch(line.trim()));

  /// The last line of [output] that is entirely a version, which is what cider bumped to.
  String? _lastSemverLine(String output) => const LineSplitter()
      .convert(output)
      .map((line) => line.trim())
      .where(semverPattern.hasMatch)
      .lastOrNull;
}
