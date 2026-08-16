import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('NaturalNumber', () {
    // The expected `.value` doubles as the outcome; null means the input was rejected.
    scenarioOutline<({int input, int? value})>(
      'NaturalNumber.tryFrom accepts one and up, and rejects zero and below',
      examples: {
        'one, the smallest there is': (input: 1, value: 1),
        'zero, excluded by the reading this type takes': (input: 0, value: null),
        'minus one': (input: -1, value: null),
      },
      outline: (example) {
        check(NaturalNumber.tryFrom(example.input)?.value).equals(example.value);
      },
    );

    // The convention is split, so which reading this type takes is the load-bearing fact.
    scenario('zero is the one value the two quantity types disagree on', () {
      check(NaturalNumber.tryFrom(0)).isNull();
      check(Uint.tryFrom(0)?.value).equals(0);
    });

    scenario('there is no upper bound', () {
      check(NaturalNumber.tryFrom(9007199254740991)?.value).equals(9007199254740991);
    });

    scenario('a NaturalNumber renders as its bare number', () {
      check(NaturalNumber.tryFrom(7)!.toString()).equals('7');
    });

    scenario('equality is by value', () {
      check(NaturalNumber.tryFrom(7)!).equals(NaturalNumber.tryFrom(7)!);
      check(NaturalNumber.tryFrom(7)! == NaturalNumber.tryFrom(8)!).isFalse();
    });
  });
}
