import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('AsciiLetters', () {
    scenarioOutline<({String input, String? accepted})>(
      'tryFrom takes one or more ASCII letters',
      examples: {
        'one': (input: 'Q', accepted: 'Q'),
        'several, mixed case': (input: 'NWBK', accepted: 'NWBK'),
        'a digit among them': (input: 'GB1', accepted: null),
        'a space among them': (input: 'G B', accepted: null),
        'an empty string': (input: '', accepted: null),
        'a non-ASCII letter': (input: 'G\u{00D8}', accepted: null),
      },
      outline: (example) {
        check(AsciiLetters.tryFrom(example.input)?.value).equals(example.accepted);
      },
    );

    scenario('letters hands back one AsciiLetter per code unit', () {
      check(AsciiLetters.tryFrom('GB')!.letters.map((letter) => letter.value).toList())
          .deepEquals(['G', 'B']);
    });
  });
}
