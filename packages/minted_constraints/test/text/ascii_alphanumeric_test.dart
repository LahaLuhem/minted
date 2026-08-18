import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('AsciiAlphanumeric', () {
    scenarioOutline<({String input, String? accepted})>(
      'tryFrom takes exactly one ASCII letter or digit',
      examples: {
        'a letter': (input: 'Q', accepted: 'Q'),
        'a digit': (input: '7', accepted: '7'),
        'punctuation': (input: '-', accepted: null),
        'a space': (input: ' ', accepted: null),
        'two characters': (input: 'a1', accepted: null),
        'an empty string': (input: '', accepted: null),
        'a non-ASCII letter': (input: '\u{00D8}', accepted: null),
      },
      outline: (example) {
        check(AsciiAlphanumeric.tryFrom(example.input)?.value).equals(example.accepted);
      },
    );

    scenario('an AsciiLetter is an AsciiAlphanumeric, but a digit is no letter', () {
      final AsciiAlphanumeric letter = AsciiLetter.tryFrom('Q')!;

      check(letter.value).equals('Q');
      check(AsciiLetter.tryFrom('7')).isNull();
      check(AsciiAlphanumeric.tryFrom('7')).isNotNull();
    });
  });
}
