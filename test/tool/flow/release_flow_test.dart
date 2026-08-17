import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../tool/src/flow/release_flow.dart';
import '../../../tool/src/io/process_runner.dart';
import '../../../tool/src/release_abort.dart';
import '../../../tool/src/release_options.dart';
import '../support/fake_process_runner.dart';
import '../support/fake_release_ui.dart';
import '../support/fixture_repo.dart';

/// The head both sides of the sync check report, so the git-state gate passes by default.
const _head = 'abc123';

CommandResult _ok([String stdout = '']) => CommandResult(exitCode: 0, stdout: stdout, stderr: '');

/// Answers the probes a healthy checkout would. [bumpedTo] is what cider claims, so a test can make
/// the cross-check disagree.
CommandResult Function(String) _healthy({String bumpedTo = '3.0.1'}) =>
    (command) => switch (command) {
      'cider version' => _ok('3.0.0'),
      'cider bump patch' => _ok(bumpedTo),
      'docker info' => _ok('Server Version: 27.0.0'),
      'dart --version' => _ok('Dart SDK version: 3.13.0'),
      'git status --porcelain' => _ok(),
      'git rev-parse --abbrev-ref HEAD' => _ok('main'),
      'git rev-parse HEAD' => _ok(_head),
      'git rev-parse origin/main' => _ok(_head),
      // An unused tag: `rev-parse` fails on it and `ls-remote` finds nothing.
      _ when command.startsWith('git rev-parse refs/tags/') => const CommandResult(
        exitCode: 128,
        stdout: '',
        stderr: 'unknown revision',
      ),
      _ => _ok(),
    };

void main() {
  late FixtureRepo fixture;

  setUp(() {
    fixture = FixtureRepo()..addLintManifest();
  });

  tearDown(() => fixture.dispose());

  Future<ReleaseAbort?> runFlow({
    required FakeProcessRunner runner,
    required FakeReleaseUi ui,
    ReleaseOptions options = const ReleaseOptions(bump: .patch, skipConfirmation: true),
  }) async {
    try {
      await ReleaseFlow(repo: fixture.repo, runner: runner, ui: ui, options: options).run();
    } on ReleaseAbort catch (abort) {
      return abort;
    }

    return null;
  }

  group('package discovery', () {
    test('offers only publishable members that have notes', () {
      fixture
        ..addMember(name: 'with_notes', version: '1.0.0')
        ..addMember(
          name: 'no_notes',
          version: '1.0.0',
          changelog: '## 1.0.0 - 2026-01-01\n- Out.\n',
        )
        ..addMember(name: 'private_member', version: '1.0.0', publishable: false);

      check(fixture.repo.pendingPackages().map((pending) => pending.name))
          .deepEquals(['with_notes']);
    });

    test('skips a member with no CHANGELOG at all', () {
      fixture.addMember(name: 'documented', version: '1.0.0');
      fixture.repo.pendingPackages();

      // minted_conformance is exactly this case after its changelog was dropped.
      check(fixture.repo.pendingPackages()).length.equals(1);
    });

    test('aborts with guidance when nothing is pending', () async {
      fixture.addMember(
        name: 'shipped',
        version: '1.0.0',
        changelog: '## 1.0.0 - 2026-01-01\n- Out.\n',
      );

      final abort = await runFlow(runner: FakeProcessRunner(), ui: FakeReleaseUi());

      check(abort).isNotNull().has((abort) => abort.toString(), 'text').contains('## Unreleased');
    });

    test('takes the only candidate without asking', () async {
      fixture.addMember(name: 'only_one', version: '1.0.0');
      final ui = FakeReleaseUi();

      await runFlow(
        runner: FakeProcessRunner(onCapture: _healthy()),
        ui: ui,
      );

      check(ui.said('Selected only_one')).isTrue();
    });

    test('refuses to guess between two candidates off a TTY', () async {
      fixture
        ..addMember(name: 'first', version: '1.0.0')
        ..addMember(name: 'second', version: '1.0.0');

      final abort = await runFlow(runner: FakeProcessRunner(), ui: FakeReleaseUi());

      check(abort).isNotNull().has((abort) => abort.code, 'code').equals(2);
    });

    test('uses the picker answer on a TTY', () async {
      fixture
        ..addMember(name: 'first', version: '1.0.0')
        ..addMember(name: 'second', version: '1.0.0');

      final ui = FakeReleaseUi(isInteractive: true, packageChoice: 'second');
      await runFlow(
        runner: FakeProcessRunner(onCapture: _healthy()),
        ui: ui,
      );

      check(ui.said('Selected second')).isTrue();
    });

    test('rejects a --package that is not a candidate, naming the ones that are', () async {
      fixture.addMember(name: 'real_member', version: '1.0.0');

      final abort = await runFlow(
        runner: FakeProcessRunner(),
        ui: FakeReleaseUi(),
        options: const ReleaseOptions(bump: .patch, package: 'typo_member', skipConfirmation: true),
      );

      check(abort).isNotNull().has((abort) => abort.code, 'code').equals(2);
      check(abort?.toString() ?? '').contains('real_member');
    });
  });

  group('git-state gate', () {
    test('reports every problem in one run rather than the first', () async {
      fixture.addMember(name: 'member', version: '1.0.0');

      final abort = await runFlow(
        runner: FakeProcessRunner(
          onCapture: (command) => switch (command) {
            'cider version' => _ok('1.0.0'),
            'docker info' => _ok('up'),
            'dart --version' => _ok('3.13.0'),
            'git status --porcelain' => _ok(' M lib/thing.dart'),
            'git rev-parse --abbrev-ref HEAD' => _ok('feature/x'),
            'git rev-parse HEAD' => _ok(_head),
            'git rev-parse origin/main' => _ok('def456'),
            _ => _ok(),
          },
        ),
        ui: FakeReleaseUi(),
      );

      final text = abort?.toString() ?? '';
      check(text).contains('dirty');
      check(text).contains('feature/x');
      check(text).contains('not at origin/main');
    });
  });

  group('sibling-constraint gate', () {
    test('blocks a release whose sibling constraint predates the tree', () async {
      fixture
        ..addMember(name: 'core', version: '3.0.0')
        ..addMember(
          name: 'companion',
          version: '1.0.0',
          dependencies: {'core': "'>=2.0.0 <4.0.0'"},
        );

      final abort = await runFlow(
        runner: FakeProcessRunner(onCapture: _healthy()),
        ui: FakeReleaseUi(),
        options: const ReleaseOptions(bump: .patch, package: 'companion', skipConfirmation: true),
      );

      check(abort).isNotNull().has((abort) => abort.toString(), 'text').contains('Tighten');
    });
  });

  group('happy path', () {
    test('runs the seven steps in order and tags without signing', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(onCapture: _healthy());

      final abort = await runFlow(runner: runner, ui: FakeReleaseUi());

      check(abort).isNull();
      check(runner.ran('cider bump patch')).isTrue();
      check(runner.ran('cider release')).isTrue();
      check(runner.ran('git add packages/core/pubspec.yaml')).isTrue();
      check(runner.ran('git commit -m Prep for release core-3.0.1')).isTrue();
      check(runner.ran('git -c tag.gpgSign=false tag core-3.0.1')).isTrue();
      check(runner.ran('git push --atomic origin HEAD:main core-3.0.1')).isTrue();

      // Nothing was undone, which is the whole point of a clean run.
      check(runner.ran('git checkout HEAD')).isFalse();
      check(runner.ran('git reset')).isFalse();
    });

    test('an annotated tag is used when a message is given', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(onCapture: _healthy());

      await runFlow(
        runner: runner,
        ui: FakeReleaseUi(),
        options: const ReleaseOptions(bump: .patch, tagMessage: 'Big one', skipConfirmation: true),
      );

      check(runner.ran('git tag -m Big one core-3.0.1')).isTrue();
      check(runner.ran('git -c tag.gpgSign=false')).isFalse();
    });

    test('a dry run stops after the plan', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(onCapture: _healthy());

      await runFlow(
        runner: runner,
        ui: FakeReleaseUi(),
        options: const ReleaseOptions(bump: .patch, dryRun: true),
      );

      check(runner.ran('cider bump')).isFalse();
      check(runner.ran('git commit')).isFalse();
      check(runner.ran('git push')).isFalse();
    });

    test('declining the confirmation changes nothing', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(onCapture: _healthy());

      final abort = await runFlow(
        runner: runner,
        ui: FakeReleaseUi(isInteractive: true, confirmation: false),
        options: const ReleaseOptions(bump: .patch),
      );

      check(abort).isNull();
      check(runner.ran('cider bump')).isFalse();
      check(runner.ran('git push')).isFalse();
    });

    test('refuses to proceed unconfirmed off a TTY', () async {
      fixture.addMember(name: 'core', version: '3.0.0');

      final abort = await runFlow(
        runner: FakeProcessRunner(onCapture: _healthy()),
        ui: FakeReleaseUi(),
        options: const ReleaseOptions(bump: .patch),
      );

      check(abort).isNotNull().has((abort) => abort.code, 'code').equals(2);
    });
  });

  // What the port exists to pin down. Each case asserts both what was undone and what was not.
  group('rollback', () {
    test('a cider disagreement restores the files and leaves history alone', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(onCapture: _healthy(bumpedTo: '9.9.9'));

      final abort = await runFlow(runner: runner, ui: FakeReleaseUi());

      check(abort).isNotNull().has((abort) => abort.toString(), 'text').contains('9.9.9');
      check(
        runner.ran('git checkout HEAD -- packages/core/pubspec.yaml packages/core/CHANGELOG.md'),
      ).isTrue();
      check(runner.ran('git reset')).isFalse();
      check(runner.ran('git commit')).isFalse();
      check(runner.ran('git push')).isFalse();
    });

    test('a failed commit restores the files, since nothing landed', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(
        onCapture: (command) => command.startsWith('git commit')
            ? const CommandResult(exitCode: 1, stdout: '', stderr: 'pre-commit hook failed')
            : _healthy()(command),
      );

      final abort = await runFlow(runner: runner, ui: FakeReleaseUi());

      check(abort).isNotNull();
      check(runner.ran('git checkout HEAD --')).isTrue();
      check(runner.ran('git reset')).isFalse();
      check(runner.ran('git push')).isFalse();
    });

    test('a failed publish dry-run drops the prep commit exactly once', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(
        onCapture: _healthy(),
        onStream: (command) => command.contains('publish --dry-run') ? 1 : 0,
      );

      final abort = await runFlow(runner: runner, ui: FakeReleaseUi());

      check(abort).isNotNull();
      check(runner.timesRan('git reset --hard HEAD~1')).equals(1);
      check(runner.ran('git checkout HEAD --')).isFalse();
      check(runner.ran('git push')).isFalse();
    });

    // Past the dry-run the window is the user's: a push that half-succeeded must not be second
    // guessed, so the flow prints the recipe instead of running it.
    test('a failed push undoes nothing and prints the recovery recipe', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(
        onCapture: _healthy(),
        onStream: (command) => command.startsWith('git push') ? 1 : 0,
      );

      final abort = await runFlow(runner: runner, ui: FakeReleaseUi());

      check(abort).isNotNull();
      check(runner.ran('git reset')).isFalse();
      check(runner.ran('git checkout HEAD --')).isFalse();

      final text = abort?.toString() ?? '';
      check(text).contains('git tag -d core-3.0.1');
      check(text).contains('git reset --hard HEAD~1');
    });

    test('a failing lint gate never reaches the bump', () async {
      fixture.addMember(name: 'core', version: '3.0.0');
      final runner = FakeProcessRunner(
        onCapture: _healthy(),
        onStream: (command) => command.startsWith('docker run') ? 1 : 0,
      );

      final abort = await runFlow(runner: runner, ui: FakeReleaseUi());

      check(abort).isNotNull().has((abort) => abort.toString(), 'text').contains('ShellCheck');
      check(runner.ran('cider bump')).isFalse();
      check(runner.ran('git checkout HEAD --')).isFalse();
    });
  });
}
