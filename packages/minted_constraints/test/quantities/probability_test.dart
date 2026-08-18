import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../support/bdd.dart';

void main() {
  feature('Probability', () {
    // The expected `.value` doubles as the outcome; null means the input was rejected.
    scenarioOutline<({num input, double? value})>(
      'Probability.tryFrom accepts 0 to 1 inclusive and refuses either side',
      examples: {
        'both ends are members, not edge cases': (input: 0, value: 0),
        'the certain end': (input: 1, value: 1),
        'the everyday case': (input: 0.15, value: 0.15),
        'an int, which is why the door takes a num': (input: 1, value: 1),
        'just past certainty': (input: 1.0000001, value: null),
        'just below impossible': (input: -0.0000001, value: null),
        'a NaN falls out of the positive test': (input: double.nan, value: null),
        'an infinity likewise': (input: double.infinity, value: null),
      },
      outline: (example) {
        check(Probability.tryFrom(example.input)?.value).equals(example.value);
      },
    );

    scenario('the two ends are reported rather than refused', () {
      check(Probability.tryFrom(0)!.isImpossible).isTrue();
      check(Probability.tryFrom(0)!.isCertain).isFalse();
      check(Probability.tryFrom(1)!.isCertain).isTrue();
      check(Probability.tryFrom(0.5)!.isImpossible).isFalse();
      check(Probability.tryFrom(0.5)!.isCertain).isFalse();
    });

    scenarioOutline<({num input, double complement})>(
      'complement is the probability of the event not happening',
      examples: {
        'the everyday case': (input: 0.25, complement: 0.75),
        'impossible becomes certain': (input: 0, complement: 1),
        'certain becomes impossible': (input: 1, complement: 0),
        'a half is its own complement': (input: 0.5, complement: 0.5),
      },
      outline: (example) {
        check(Probability.tryFrom(example.input)!.complement.value).equals(example.complement);
      },
    );

    // The guarantee is the range, not involution: a third of ordinary values fail to round-trip,
    // because 1 - (1 - x) is not x in IEEE. Asserted rather than hidden.
    scenario('complement stays in range, and only round-trips where doubles allow it', () {
      check(Probability.tryFrom(1)!.complement.isImpossible).isTrue();
      check(Probability.tryFrom(0)!.complement.isCertain).isTrue();
      check(Probability.tryFrom(0.25)!.complement.complement).equals(Probability.tryFrom(0.25)!);
      check(Probability.tryFrom(0.3)!.complement.complement.value).equals(0.30000000000000004);
    });

    // Total one way, partial the other: that asymmetry is why both types exist.
    scenarioOutline<({num input, double percent})>(
      'toPercentage always succeeds, and lands on the decimal',
      examples: {
        'the everyday case': (input: 0.15, percent: 15),
        'one a naive multiply would get wrong': (input: 0.29, percent: 29),
        'impossible': (input: 0, percent: 0),
        'certain': (input: 1, percent: 100),
      },
      outline: (example) {
        check(Probability.tryFrom(example.input)!.toPercentage().value).equals(example.percent);
      },
    );

    scenarioOutline<({num percent, double? value})>(
      'tryFromPercentage refuses the percentages that are not probabilities',
      examples: {
        'the everyday case': (percent: 15, value: 0.15),
        'exactly the whole': (percent: 100, value: 1),
        'zero': (percent: 0, value: 0),
        'growth past the whole is no probability': (percent: 250, value: null),
        'nor is churn': (percent: -12, value: null),
      },
      outline: (example) {
        check(Probability.tryFromPercentage(Percentage.tryFrom(example.percent)!)?.value)
            .equals(example.value);
      },
    );

    // -0.0 passes `>= 0`, so it reaches the representation and only the rendered form needs it.
    scenario('a negative zero renders as a plain zero', () {
      check(Probability.tryFrom(-0.0)!.value.toString()).equals('0.0');
      check(Probability.tryFrom(-0.0)!.isImpossible).isTrue();
    });

    scenario('a Probability renders as its bare number', () {
      check(Probability.tryFrom(0.15)!.toString()).equals('0.15');
    });

    scenario('equality is by value', () {
      check(Probability.tryFrom(0.15)!)
          .equals(Probability.tryFromPercentage(Percentage.tryFrom(15)!)!);
      check(Probability.tryFrom(0.15)! == Probability.tryFrom(0.16)!).isFalse();
    });
  });
}
