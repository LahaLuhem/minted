import '../io/process_runner.dart';
import '../io/release_ui.dart';

/// Undoes a part-finished release, at most once.
///
/// Once only because [RollbackPhase.commitLanded] drops a commit, and both the interrupt handler
/// and the enclosing `finally` call [run].
class Rollback {
  new({
    required this._runner,
    required this._ui,
    required this.repoRoot,
    required this.packageDir,
    this.repairedPubspecs = const [],
  });

  final ProcessRunner _runner;
  final ReleaseUi _ui;

  /// Absolute path to the checkout being released. git has to run here, not wherever the process
  /// happened to start, or the undo lands in the wrong repo.
  final String repoRoot;

  /// Directory of the member being released, relative to [repoRoot].
  final String packageDir;

  /// Other members' pubspecs the release rewrote, relative to [repoRoot]. Restored alongside the
  /// released member's own files: a half-repaired tree does not resolve.
  final List<String> repairedPubspecs;

  /// Updated as the release advances, and read only when something goes wrong.
  RollbackPhase phase = .none;

  var _done = false;

  bool get isDone => _done;

  void run() {
    if (_done) return;
    _done = true;

    switch (phase) {
      case .none:
        return;

      case .filesTouched:
        _ui.error(
          'Failure mid-release, restoring $packageDir pubspec.yaml + CHANGELOG.md from HEAD.',
        );
        _runner.capture('git', [
          'checkout',
          'HEAD',
          '--',
          '$packageDir/pubspec.yaml',
          '$packageDir/CHANGELOG.md',
          ...repairedPubspecs,
        ], workingDirectory: repoRoot);

      case .commitLanded:
        _ui.error('Failure post-commit, git reset --hard HEAD~1 to drop the prep commit.');
        _runner.capture('git', ['reset', '--hard', 'HEAD~1'], workingDirectory: repoRoot);
    }
  }
}

/// How far a release got, which decides what undoing it means.
enum RollbackPhase {
  /// Before the bump, or past the dry-run, where cleanup could drop real work if the push was the
  /// step that failed.
  none,

  /// The bump and CHANGELOG edit landed in the tree, with no commit yet.
  filesTouched,

  /// The prep commit landed and the publish dry-run is still pending.
  commitLanded,
}
