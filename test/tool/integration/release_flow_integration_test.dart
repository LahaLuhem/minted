@Tags(['integration'])
library;

import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Drives the real `tool/release.dart` against a throwaway bare remote, which no `publish.yml`
/// watches, so nothing here can reach pub.dev.
///
/// The unit suites fake the process runner, so only this proves the real `cider bump`, commit, tag
/// and atomic push behave as the flow assumes. It caught the rollback running git in whatever
/// directory the process started in, which every unit test passed over.
void main() {
  final dart = Platform.resolvedExecutable;
  final repoRoot = Directory.current.path;

  late Directory work;

  setUp(() => work = Directory.systemTemp.createTempSync('release_integration_'));
  tearDown(() => work.deleteSync(recursive: true));

  /// Runs [executable], failing the test with its output rather than a bare exit code.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    required String inside,
    bool expectSuccess = true,
  }) async {
    final result = await Process.run(executable, arguments, workingDirectory: inside);
    if (expectSuccess && result.exitCode != 0) {
      fail('$executable ${arguments.join(' ')} failed:\n${result.stdout}\n${result.stderr}');
    }

    return result;
  }

  /// A workspace at `<work>/clone` with a bare origin, holding one member at 1.0.0 with notes.
  ///
  /// Only what the real preflight reads, plus everything `pub publish --dry-run` insists on, since
  /// that gate runs post-commit for real.
  Future<String> scaffold({String package = 'scratch_pkg'}) async {
    final clone = '${work.path}/clone';
    final origin = '${work.path}/origin.git';

    await run('git', ['init', '--quiet', '--bare', origin], inside: work.path);
    await run('git', ['init', '--quiet', '--initial-branch=main', clone], inside: work.path);
    for (final config in [
      ['remote', 'add', 'origin', origin],
      ['config', 'user.name', 'Integration Test'],
      ['config', 'user.email', 'test@example.invalid'],
      ['config', 'commit.gpgSign', 'false'],
      ['config', 'tag.gpgSign', 'false'],
    ]) {
      await run('git', config, inside: clone);
    }

    Directory('$clone/.github').createSync(recursive: true);
    Directory('$clone/packages/$package/lib').createSync(recursive: true);
    Directory('$clone/packages/$package/test').createSync(recursive: true);

    void write(String path, String contents) => File('$clone/$path').writeAsStringSync(contents);

    // A manifest must parse and be non-empty or the preflight aborts. Alpine, not linterpol: this
    // proves the flow's `docker run` works, not that a linter does, and it is far smaller to pull.
    write('.github/lint-checks.json', '''
{ "image": "alpine:3", "checks": [{ "name": "shell", "cmd": "true" }] }
''');
    write('pubspec.yaml', '''
name: scratch_workspace
publish_to: none
environment:
  sdk: ^3.13.0
workspace:
  - packages/$package
''');
    write('packages/$package/pubspec.yaml', '''
name: $package
description: A throwaway package used to verify the release flow end to end, nothing more.
version: 1.0.0
repository: https://github.com/LahaLuhem/minted
environment:
  sdk: ^3.13.0
resolution: workspace
dev_dependencies:
  test: ^1.31.2
''');
    write('packages/$package/CHANGELOG.md', '## Unreleased\n\n### Added\n- Something.\n');
    write('packages/$package/README.md', '# $package\n\nThrowaway.\n');
    write('packages/$package/LICENSE', 'MIT\n');
    write('packages/$package/lib/$package.dart', 'int answer() => 42;\n');
    write('packages/$package/test/answer_test.dart', '''
import 'package:$package/$package.dart';
import 'package:test/test.dart';

void main() => test('answers', () => expect(answer(), 42));
''');
    write('.gitignore', '.dart_tool/\npubspec.lock\n');

    await run(dart, ['pub', 'get'], inside: clone);
    await run(dart, ['format', '.'], inside: clone);
    await run('git', ['add', '-A'], inside: clone);
    await run('git', ['commit', '--quiet', '-m', 'Scaffold'], inside: clone);
    await run('git', ['push', '--quiet', '-u', 'origin', 'main'], inside: clone);

    return clone;
  }

  Future<ProcessResult> release(String clone, {String package = 'scratch_pkg'}) => Process.run(
    dart,
    ['run', 'tool/release.dart', 'patch', '-p', package, '--yes', '--repo-root', clone],
    workingDirectory: repoRoot,
  );

  String read(String clone, String path) => File('$clone/$path').readAsStringSync();

  Future<String> git(String clone, List<String> arguments) async =>
      ((await run('git', arguments, inside: clone)).stdout as String).trim();

  test('a clean release bumps, dates, commits, tags and pushes', () async {
    final clone = await scaffold();

    final result = await release(clone);
    check(result.exitCode).equals(0);

    check(read(clone, 'packages/scratch_pkg/pubspec.yaml')).contains('version: 1.0.1');

    final changelog = read(clone, 'packages/scratch_pkg/CHANGELOG.md');
    check(changelog).contains('1.0.1');
    check(changelog).not((it) => it.contains('## Unreleased'));

    check(await git(clone, ['log', '-1', '--pretty=%s']))
        .equals('Prep for release scratch_pkg-1.0.1');
    check(await git(clone, ['status', '--porcelain'])).isEmpty();

    // Lightweight by default: no -m was passed, so the ref points straight at the commit.
    check(await git(clone, ['cat-file', '-t', 'scratch_pkg-1.0.1'])).equals('commit');
    check(await git(clone, ['ls-remote', '--tags', 'origin', 'refs/tags/scratch_pkg-1.0.1']))
        .isNotEmpty();
    check(
      await git(clone, ['rev-parse', 'HEAD']),
    ).startsWith((await git(clone, ['ls-remote', 'origin', 'refs/heads/main'])).split('\t').first);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a rejected commit restores both pipeline-owned files', () async {
    final clone = await scaffold();
    final hook = File('$clone/.git/hooks/pre-commit')..writeAsStringSync('#!/bin/sh\nexit 1\n');
    await run('chmod', ['+x', hook.path], inside: clone);

    final result = await release(clone);
    check(result.exitCode).not((it) => it.equals(0));

    check(read(clone, 'packages/scratch_pkg/pubspec.yaml')).contains('version: 1.0.0');
    check(read(clone, 'packages/scratch_pkg/CHANGELOG.md')).contains('## Unreleased');
    check(await git(clone, ['log', '-1', '--pretty=%s'])).equals('Scaffold');
    check(await git(clone, ['status', '--porcelain'])).isEmpty();
    check(await git(clone, ['tag', '-l'])).isEmpty();
    check(await git(clone, ['ls-remote', '--tags', 'origin'])).isEmpty();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
