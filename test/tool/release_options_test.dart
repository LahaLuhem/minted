import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../tool/src/release_abort.dart';
import '../../tool/src/release_options.dart';
import '../../tool/src/versioning/bump_type.dart';

/// The abort a usage error carries, for asserting the exit code rather than just the type.
ReleaseAbort _abortFrom(List<String> arguments) {
  try {
    ReleaseOptions.parse(arguments);
  } on ReleaseAbort catch (abort) {
    return abort;
  }

  throw StateError('expected $arguments to be rejected');
}

void main() {
  group('defaults', () {
    test('no arguments leaves every choice open', () {
      final options = ReleaseOptions.parse([]);

      check(options.bump).isNull();
      check(options.package).isNull();
      check(options.tagMessage).isNull();
      check(options.skipConfirmation).isFalse();
      check(options.dryRun).isFalse();
      check(options.helpRequested).isFalse();
    });
  });

  group('bump', () {
    test('reads the positional bump', () {
      check(ReleaseOptions.parse(['minor']).bump).equals(.minor);
    });

    test('rejects an unknown positional with a usage code', () {
      check(_abortFrom(['sideways']).code).equals(2);
    });

    test('rejects more than one positional', () {
      check(_abortFrom(['patch', 'minor']).code).equals(2);
    });
  });

  group('options', () {
    test('reads the long forms', () {
      final options = ReleaseOptions.parse([
        'patch',
        '--package',
        'minted',
        '--tag-message',
        'Big one',
        '--yes',
        '--dry-run',
      ]);

      check(options.bump).equals(.patch);
      check(options.package).equals('minted');
      check(options.tagMessage).equals('Big one');
      check(options.skipConfirmation).isTrue();
      check(options.dryRun).isTrue();
    });

    test('reads the abbreviations', () {
      final options = ReleaseOptions.parse(['-p', 'minted_finance', '-m', 'note', '-y', '-n']);

      check(options.package).equals('minted_finance');
      check(options.tagMessage).equals('note');
      check(options.skipConfirmation).isTrue();
      check(options.dryRun).isTrue();
    });

    test('order does not matter', () {
      check(ReleaseOptions.parse(['--yes', 'major']).bump).equals(.major);
    });

    // An empty value is a mistyped invocation, not a request to release nothing.
    test('rejects an empty package name', () {
      check(_abortFrom(['-p', '']).code).equals(2);
    });

    test('rejects an empty tag message', () {
      check(_abortFrom(['-m', '']).code).equals(2);
    });

    test('rejects an unknown option', () {
      check(_abortFrom(['--publish-now']).code).equals(2);
    });
  });

  group('help', () {
    test('short-circuits everything else', () {
      check(ReleaseOptions.parse(['--help', 'patch']).helpRequested).isTrue();
    });

    test('names every bump it accepts, so the text cannot drift from the enum', () {
      for (final bump in BumpType.values) {
        check(ReleaseOptions.usage).contains(bump.name);
      }
    });
  });
}
