import 'package:checks/checks.dart';
import 'package:terminice/testing.dart';
import 'package:test/test.dart';

import '../../../tool/src/io/terminice_release_ui.dart';

/// Runs [body] against a scripted terminal, so the rich prompts can be driven without a TTY.
T withScript<T>(TerminalScript script, T Function(TerminiceReleaseUi ui) body) {
  final tester = TerminiceTester.interactive(script: script);

  return tester.run((client) => body(TerminiceReleaseUi(client: client)));
}

void main() {
  group('choosePackage', () {
    test('returns the entry the arrow keys land on', () {
      final chosen = withScript(
        TerminalScript.build(
          (script) => script
            ..down()
            ..enter(),
        ),
        (ui) => ui.choosePackage(['minted', 'minted_finance', 'minted_network']),
      );

      check(chosen).equals('minted_finance');
    });

    test('returns the first entry when Enter is pressed straight away', () {
      final chosen = withScript(
        TerminalScript.build((script) => script.enter()),
        (ui) => ui.choosePackage(['minted', 'minted_finance']),
      );

      check(chosen).equals('minted');
    });

    // Esc yields an empty selection, which the flow has to read as "no choice", not as a package.
    test('a cancelled prompt is no choice', () {
      final chosen = withScript(
        TerminalScript.build((script) => script.escape()),
        (ui) => ui.choosePackage(['minted', 'minted_finance']),
      );

      check(chosen).isNull();
    });

    test('is no choice when nobody is there to answer', () {
      final tester = TerminiceTester.nonInteractive();
      final chosen = tester.run(
        (client) => TerminiceReleaseUi(client: client).choosePackage(['minted']),
      );

      check(chosen).isNull();
    });

    // The picker passes showSearch, and the cases above only ever press arrows. These drive the
    // other half.
    group('search', () {
      const options = ['minted', 'minted_finance', 'minted_network'];

      test('a typed query narrows to its match', () {
        final chosen = withScript(
          TerminalScript.build(
            (script) => script
              ..text('finance')
              ..enter(),
          ),
          (ui) => ui.choosePackage(options),
        );

        check(chosen).equals('minted_finance');
      });

      test('a query nothing matches is no choice', () {
        final chosen = withScript(
          TerminalScript.build(
            (script) => script
              ..text('cobol')
              ..enter(),
          ),
          (ui) => ui.choosePackage(options),
        );

        check(chosen).isNull();
      });

      test('Backspace edits the query rather than cancelling the prompt', () {
        final chosen = withScript(
          TerminalScript.build(
            (script) => script
              ..text('financex')
              ..backspace()
              ..enter(),
          ),
          (ui) => ui.choosePackage(options),
        );

        check(chosen).equals('minted_finance');
      });

      // Both are literal query text, not controls. `minted docs` is not a real package: it is here
      // so a typed space has something to match.
      test('Space and slash type into the query', () {
        final spaced = withScript(
          TerminalScript.build(
            (script) => script
              ..text('minted')
              ..space()
              ..text('docs')
              ..enter(),
          ),
          (ui) => ui.choosePackage(['minted', 'minted docs']),
        );
        final slashed = withScript(
          TerminalScript.build(
            (script) => script
              ..text('minted')
              ..key(KeyEventType.slash)
              ..enter(),
          ),
          (ui) => ui.choosePackage(['minted', 'minted docs']),
        );

        check(spaced).equals('minted docs');
        check(slashed).isNull();
      });
    });
  });

  group('chooseBump', () {
    test('maps the picked label back to the enum', () {
      final chosen = withScript(
        TerminalScript.build(
          (script) => script
            ..down()
            ..enter(),
        ),
        (ui) => ui.chooseBump(),
      );

      check(chosen).equals(.minor);
    });

    test('a cancelled prompt is no choice', () {
      final chosen = withScript(
        TerminalScript.build((script) => script.escape()),
        (ui) => ui.chooseBump(),
      );

      check(chosen).isNull();
    });
  });

  group('confirmRelease', () {
    test('is false unattended, so a release cannot happen by default', () {
      final tester = TerminiceTester.nonInteractive();

      check(tester.run((client) => TerminiceReleaseUi(client: client).confirmRelease())).isFalse();
    });
  });

  group('task', () {
    test('returns the work result and announces the label', () async {
      final tester = TerminiceTester.interactive();
      final ui = TerminiceReleaseUi(client: tester.terminice);

      final answer = await tester.runAsync((_) => ui.task('dart test', () async => 42));

      check(answer).equals(42);
      check(tester.output.plainText).contains('dart test');
    });

    test('lets a failure through rather than swallowing it', () async {
      final tester = TerminiceTester.interactive();
      final ui = TerminiceReleaseUi(client: tester.terminice);

      await expectLater(
        tester.runAsync((_) => ui.task<void>('dart test', () async => throw StateError('boom'))),
        throwsA(isA<StateError>()),
      );
    });
  });
}
