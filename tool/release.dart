// Cut a versioned release of one workspace member: bump with cider, date the CHANGELOG, repair any
// dependent constraint the new version would fall outside, commit, tag `<package>-<version>`, push
// both atomically. The tag push triggers publish.yml.
//
// Laptop-only. Every gate runs before the first side effect, and a failure after that auto-reverts.
// See src/flow/rollback.dart. Sequence and gates: src/flow/release_flow.dart.
//
// Usage:
//   dart run tool/release.dart                        # fully interactive
//   dart run tool/release.dart patch -p minted --yes  # non-interactive
//   dart run tool/release.dart --dry-run              # preflight + plan, no side effects
import 'dart:io';

import 'src/flow/release_flow.dart';
import 'src/io/process_runner.dart';
import 'src/io/repo.dart';
import 'src/io/terminice_release_ui.dart';
import 'src/release_abort.dart';
import 'src/release_options.dart';

Future<void> main(List<String> arguments) async {
  final ui = TerminiceReleaseUi();

  try {
    final options = ReleaseOptions.parse(arguments);
    if (options.helpRequested) return ui.block(ReleaseOptions.usage);

    await ReleaseFlow(
      repo: Repo(options.repoRoot ?? _repoRoot()),
      runner: const RealProcessRunner(),
      ui: ui,
      options: options,
    ).run();
  } on ReleaseAbort catch (abort) {
    // Thrown rather than exited, so the rollback's `finally` still runs.
    abort.messages.forEach(ui.error);
    exitCode = abort.code;
  }
}

/// The workspace root, two levels up from this script.
String _repoRoot() => File.fromUri(Platform.script).parent.parent.path;
