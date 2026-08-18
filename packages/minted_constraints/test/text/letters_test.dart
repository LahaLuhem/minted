import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('Letters', () {
    scenarioOutline<({String input, String? accepted})>(
      'tryFrom takes one or more letters, in any script',
      examples: {
        'one letter': (input: 'x', accepted: 'x'),
        'several': (input: 'abc', accepted: 'abc'),
        'mixed scripts': (input: 'a\u{00D8}\u{0416}', accepted: 'a\u{00D8}\u{0416}'),
        'a decomposed accent counts as its base letter': (
          input: 'ae\u{0301}',
          accepted: 'ae\u{0301}',
        ),
        'a digit among them': (input: 'ab1', accepted: null),
        'a space among them': (input: 'a b', accepted: null),
        'an emoji among them': (input: 'a\u{1F44D}', accepted: null),
        'an empty string': (input: '', accepted: null),
      },
      outline: (example) {
        check(Letters.tryFrom(example.input)?.value).equals(example.accepted);
      },
    );

    // The property Q4 rests on: grapheme boundaries survive concatenation, so the split is exact.
    scenario('letters splits back into what built it, accents included', () {
      final initials = Letters.tryFrom('J\u{00D8}e\u{0301}')!;

      check(initials.letters.map((letter) => letter.value).toList())
          .deepEquals(['J', '\u{00D8}', 'e\u{0301}']);
    });

    scenario('a Letters is not one Letter, so it is not passable as one', () {
      check(Letters.tryFrom('ab')).isNotNull();
      check(Letter.tryFrom('ab')).isNull();
    });
  });
}
