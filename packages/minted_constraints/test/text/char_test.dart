import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('Char', () {
    // Each accepted row is one character spanning one to five code points, which is why the
    // invariant is a cluster.
    scenarioOutline<({String input, String? accepted})>(
      'tryFrom takes exactly one grapheme cluster',
      examples: {
        'a letter': (input: 'x', accepted: 'x'),
        'a digit': (input: '7', accepted: '7'),
        'a CJK ideograph': (input: '\u{4E2D}', accepted: '\u{4E2D}'),
        'an emoji, one code point over two code units': (input: '\u{1F44D}', accepted: '\u{1F44D}'),
        'a skin-toned emoji, two code points': (
          input: '\u{1F44D}\u{1F3FD}',
          accepted: '\u{1F44D}\u{1F3FD}',
        ),
        'a flag, two regional indicators': (
          input: '\u{1F1F3}\u{1F1F1}',
          accepted: '\u{1F1F3}\u{1F1F1}',
        ),
        'a joined family, five code points': (
          input: '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}',
          accepted: '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}',
        ),
        'a heart with its variation selector': (
          input: '\u{2764}\u{FE0F}',
          accepted: '\u{2764}\u{FE0F}',
        ),
        'a decomposed accent': (input: 'e\u{0301}', accepted: 'e\u{0301}'),
        // One cluster by the clustering rules, surprising but honest.
        'CRLF': (input: '\r\n', accepted: '\r\n'),
        'a tab': (input: '\t', accepted: '\t'),
        'two letters': (input: 'ab', accepted: null),
        'an empty string': (input: '', accepted: null),
        // One grapheme by the rules, but not a character in any encoding, so guarded separately.
        'a lone high surrogate': (input: '\uD83D', accepted: null),
        'a lone low surrogate': (input: '\uDC4D', accepted: null),
      },
      outline: (example) {
        check(Char.tryFrom(example.input)?.value).equals(example.accepted);
      },
    );

    // The measurement the invariant rests on: code-unit and code-point counts both disagree with it.
    scenario('a flag is one character, two code points and four code units', () {
      const flag = '\u{1F1F3}\u{1F1F1}';

      check(Char.tryFrom(flag)).isNotNull();
      check(flag.runes.length).equals(2);
      check(flag.length).equals(4);
    });
  });
}
