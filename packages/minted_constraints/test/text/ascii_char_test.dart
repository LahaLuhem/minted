import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('AsciiChar', () {
    // A String means "accepted, and this is the character"; null means "rejected".
    scenarioOutline<({String input, String? accepted})>(
      'tryFrom takes exactly one ASCII character',
      examples: {
        'a letter': (input: 'x', accepted: 'x'),
        'a digit': (input: '7', accepted: '7'),
        'punctuation': (input: '-', accepted: '-'),
        'a space': (input: ' ', accepted: ' '),
        // Admitted on purpose: a delimiter is often a tab, and refusing it would invent a rule.
        'a tab': (input: '\t', accepted: '\t'),
        'DEL, the last ASCII code point': (input: '\u{007F}', accepted: '\u{007F}'),
        'two characters': (input: 'xy', accepted: null),
        'an empty string': (input: '', accepted: null),
        // One code unit, but not an ASCII one.
        'a non-ASCII letter': (input: '\u{00D8}', accepted: null),
        // Two code units, so a length check alone would already refuse it.
        'an emoji': (input: '\u{1F44D}', accepted: null),
      },
      outline: (example) {
        check(AsciiChar.tryFrom(example.input)?.value).equals(example.accepted);
      },
    );

    scenarioOutline<({String input, bool isControl})>(
      'isControl reports the shape tryFrom declines to refuse',
      examples: {
        'a tab': (input: '\t', isControl: true),
        'NUL': (input: '\u{0000}', isControl: true),
        'DEL': (input: '\u{007F}', isControl: true),
        'a space is printable, though it shows nothing': (input: ' ', isControl: false),
        'a letter': (input: 'x', isControl: false),
      },
      outline: (example) {
        check(AsciiChar.tryFrom(example.input)!.isControl).equals(example.isControl);
      },
    );

    // Every ASCII code unit is a grapheme cluster on its own, so the narrowing holds.
    scenario('an AsciiChar is a Char', () {
      final Char character = AsciiChar.tryFrom('\t')!;

      check(character.value).equals('\t');
    });

    scenario('equality and toString come from the character, being an extension type', () {
      check(AsciiChar.tryFrom('x')).equals(AsciiChar.tryFrom('x'));
      check(AsciiChar.tryFrom('x')!.value).equals('x');
      check(AsciiChar.tryFrom('x')?.toString()).equals('x');
    });
  });
}
