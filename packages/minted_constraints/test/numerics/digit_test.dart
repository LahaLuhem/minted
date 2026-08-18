import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('Digit', () {
    // tryFrom takes the numeric value directly; only 0-9 yield a Digit.
    scenarioOutline<({int input, int? value})>(
      'Digit.tryFrom accepts 0-9 and rejects out-of-range integers',
      examples: {
        'zero': (input: 0, value: 0),
        'nine': (input: 9, value: 9),
        'negative': (input: -1, value: null),
        'ten': (input: 10, value: null),
        'far out of range': (input: 42, value: null),
      },
      outline: (example) {
        check(Digit.tryFrom(example.input)?.value).equals(example.value);
      },
    );

    scenario('a Digit renders as its bare character', () {
      check(Digit.tryFrom(7)!.toString()).equals('7');
    });

    scenario('equal digits are equal, and differing ones are not', () {
      check(Digit.tryFrom(7)).equals(Digit.tryFrom(7));
      check(Digit.tryFrom(7) == Digit.tryFrom(8)).isFalse();
    });
  });
}
