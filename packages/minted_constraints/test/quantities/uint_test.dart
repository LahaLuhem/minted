import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('Uint', () {
    // The expected `.value` doubles as the outcome; null means the input was rejected.
    scenarioOutline<({int input, int? value})>(
      'Uint.tryFrom accepts zero and up, and rejects every negative',
      examples: {
        'zero, the one value that separates it from NaturalNumber': (input: 0, value: 0),
        'one': (input: 1, value: 1),
        'minus one, the near miss': (input: -1, value: null),
      },
      outline: (example) {
        check(Uint.tryFrom(example.input)?.value).equals(example.value);
      },
    );

    // Borrowed from C, where it would wrap at a fixed width. This pins that it does not.
    scenario('there is no upper bound', () {
      check(Uint.tryFrom(9007199254740991)?.value).equals(9007199254740991);
    });

    scenario('a Uint renders as its bare number', () {
      check(Uint.tryFrom(7)!.toString()).equals('7');
    });

    scenario('equality is by value', () {
      check(Uint.tryFrom(7)!).equals(Uint.tryFrom(7)!);
      check(Uint.tryFrom(7)! == Uint.tryFrom(8)!).isFalse();
    });
  });
}
