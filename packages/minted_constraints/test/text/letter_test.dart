import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('Letter', () {
    scenarioOutline<({String input, String? accepted})>(
      'tryFrom takes exactly one letter, in any script',
      examples: {
        'ASCII lower case': (input: 'x', accepted: 'x'),
        'ASCII upper case': (input: 'Q', accepted: 'Q'),
        // The three the ASCII type would refuse, which is why this one is unprefixed.
        'a Danish initial': (input: '\u{00D8}', accepted: '\u{00D8}'),
        'a Polish initial': (input: '\u{0141}', accepted: '\u{0141}'),
        'a Cyrillic initial': (input: '\u{0416}', accepted: '\u{0416}'),
        'a CJK ideograph is a letter to Unicode': (input: '\u{4E2D}', accepted: '\u{4E2D}'),
        'an astral letter, two code units': (input: '\u{1D400}', accepted: '\u{1D400}'),
        // The base rune decides, so the accent rides along.
        'a decomposed accent': (input: 'e\u{0301}', accepted: 'e\u{0301}'),
        'a digit': (input: '7', accepted: null),
        'punctuation': (input: '-', accepted: null),
        'an emoji is one character but no letter': (input: '\u{1F44D}', accepted: null),
        'two letters': (input: 'ab', accepted: null),
        'an empty string': (input: '', accepted: null),
        'a lone surrogate': (input: '\uD83D', accepted: null),
      },
      outline: (example) {
        check(Letter.tryFrom(example.input)?.value).equals(example.accepted);
      },
    );

    // The narrowing is declared, so a letter passes anywhere a character is wanted.
    scenario('a Letter is a Char', () {
      final Char letter = Letter.tryFrom('\u{00D8}')!;

      check(letter.value).equals('\u{00D8}');
    });
  });
}
