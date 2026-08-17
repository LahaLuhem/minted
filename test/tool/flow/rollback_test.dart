import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../../../tool/src/flow/rollback.dart';
import '../support/fake_process_runner.dart';
import '../support/fake_release_ui.dart';

void main() {
  late FakeProcessRunner runner;
  late FakeReleaseUi ui;
  late Rollback rollback;

  setUp(() {
    runner = FakeProcessRunner();
    ui = FakeReleaseUi();
    rollback = Rollback(runner: runner, ui: ui, packageDir: 'packages/minted');
  });

  test('undoes nothing before the bump', () {
    rollback.run();

    check(runner.calls).isEmpty();
  });

  test('restores both pipeline-owned files when only the tree was touched', () {
    rollback
      ..phase = .filesTouched
      ..run();

    check(runner.calls).deepEquals([
      'git checkout HEAD -- packages/minted/pubspec.yaml packages/minted/CHANGELOG.md',
    ]);
  });

  test('drops the prep commit once it has landed', () {
    rollback
      ..phase = .commitLanded
      ..run();

    check(runner.calls).deepEquals(['git reset --hard HEAD~1']);
  });

  // The bash predecessor trapped EXIT rather than ERR partly for this: the reset drops a commit, so
  // a second run would drop an innocent one. Both the interrupt handler and the `finally` call it.
  test('runs at most once, so the reset cannot drop a second commit', () {
    rollback
      ..phase = .commitLanded
      ..run()
      ..run()
      ..run();

    check(runner.timesRan('git reset')).equals(1);
    check(rollback.isDone).isTrue();
  });

  test('a phase set after the first run is ignored', () {
    rollback
      ..run()
      ..phase = .commitLanded
      ..run();

    check(runner.calls).isEmpty();
  });

  test('says what it is undoing, so the tree state is never a surprise', () {
    rollback
      ..phase = .commitLanded
      ..run();

    check(ui.said('HEAD~1')).isTrue();
  });
}
