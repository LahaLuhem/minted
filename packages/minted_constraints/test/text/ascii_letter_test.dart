import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('AsciiLetter', () {
    scenarioOutline<({String input, String? accepted})>(
      'tryFrom takes exactly one ASCII letter',
      examples: {
        'upper case': (input: 'Q', accepted: 'Q'),
        'lower case': (input: 'q', accepted: 'q'),
        'a digit is a character but not a letter': (input: '7', accepted: null),
        'punctuation': (input: '-', accepted: null),
        'two letters': (input: 'ab', accepted: null),
        'an empty string': (input: '', accepted: null),
        // The reason the ASCII prefix is in the name: a Danish initial needs the Unicode type.
        'a non-ASCII letter': (input: '\u{00D8}', accepted: null),
      },
      outline: (example) {
        check(AsciiLetter.tryFrom(example.input)?.value).equals(example.accepted);
      },
    );

    // The narrowing is declared, so a letter passes anywhere a character is wanted.
    scenario('an AsciiLetter is an AsciiChar', () {
      final AsciiChar letter = AsciiLetter.tryFrom('Q')!;

      check(letter.value).equals('Q');
      check(letter.isControl).isFalse();
    });

    scenario('case is kept, not folded, since no standard here says to fold it', () {
      check(AsciiLetter.tryFrom('Q') == AsciiLetter.tryFrom('q')).isFalse();
    });

    // Extension types erase to their representation, so the two compare equal at runtime.
    scenario('a letter equals the character spelling it', () {
      check(AsciiLetter.tryFrom('Q') == AsciiChar.tryFrom('Q')).isTrue();
    });
  });
}
