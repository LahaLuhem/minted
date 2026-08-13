import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Percentage', () {
    // The expected `.value` doubles as the outcome; null means the input was rejected.
    scenarioOutline<({num input, double? value})>(
      'Percentage.tryFrom takes the percent and bounds nothing but finiteness',
      examples: {
        'the everyday case': (input: 15, value: 15),
        'an int, which is why the door takes a num': (input: 250, value: 250),
        'above one hundred, because growth goes there': (input: 300.5, value: 300.5),
        'negative, because churn goes there': (input: -12, value: -12),
        'zero': (input: 0, value: 0),
        'a NaN is not a proportion': (input: double.nan, value: null),
        'nor is an infinity': (input: double.infinity, value: null),
        'nor is a negative one': (input: double.negativeInfinity, value: null),
      },
      outline: (example) {
        check(Percentage.tryFrom(example.input)?.value).equals(example.value);
      },
    );

    scenarioOutline<({num input, double? value})>(
      'Percentage.tryFromFraction lands on the decimal rather than a ulp under it',
      examples: {
        'the one the naive multiply gets wrong': (input: 0.29, value: 29),
        'and another': (input: 0.58, value: 58),
        'and one it overshoots': (input: 0.07, value: 7),
        'a fraction of a percent': (input: 0.035, value: 3.5),
        'past the whole': (input: 2.5, value: 250),
        'negative': (input: -0.12, value: -12),
        'small enough that toString goes exponential': (input: 1e-7, value: 0.00001),
        'a NaN is refused before the shift, which cannot parse one': (
          input: double.nan,
          value: null,
        ),
        'an infinity likewise': (input: double.infinity, value: null),
      },
      outline: (example) {
        check(Percentage.tryFromFraction(example.input)?.value).equals(example.value);
      },
    );

    scenario('the fraction door beats the multiply it replaces', () {
      check(Percentage.tryFromFraction(0.29)!.value).equals(29);
      check(0.29 * 100).not((it) => it.equals(29));
    });

    scenarioOutline<({num percent, double fraction})>(
      'fraction reads the same proportion back as a fraction of the whole',
      examples: {
        'the everyday case': (percent: 15, fraction: 0.15),
        'one the reverse multiply would get wrong': (percent: 29, fraction: 0.29),
        'past the whole': (percent: 250, fraction: 2.5),
        'negative': (percent: -12, fraction: -0.12),
      },
      outline: (example) {
        check(Percentage.tryFrom(example.percent)!.fraction).equals(example.fraction);
      },
    );

    scenarioOutline<({num percent, num quantity, double result})>(
      'of applies the percentage to a quantity',
      examples: {
        'the everyday case': (percent: 15, quantity: 200, result: 30),
        'one that dividing first would round twice': (percent: 7, quantity: 350, result: 24.5),
        'a fractional quantity': (percent: 12.5, quantity: 1234.56, result: 154.32),
        'above one hundred returns more than it was given': (
          percent: 300,
          quantity: 50,
          result: 150,
        ),
        'negative': (percent: -12, quantity: 200, result: -24),
      },
      outline: (example) {
        check(Percentage.tryFrom(example.percent)!.of(example.quantity)).equals(example.result);
      },
    );

    // -0.0 equals 0.0 and hashes alike, so this is about the rendered form and nothing else.
    scenario('a negative zero renders as a plain zero', () {
      check(Percentage.tryFrom(-0.0)!.value.toString()).equals('0.0');
      check(Percentage.tryFromFraction(-0.0)!.value.toString()).equals('0.0');
      check(Percentage.tryFrom(-0.0)!).equals(Percentage.tryFrom(0)!);
    });

    scenario('a Percentage renders as its bare number, carrying no unit', () {
      check(Percentage.tryFrom(15)!.toString()).equals('15.0');
    });

    scenario('equality is by value', () {
      check(Percentage.tryFrom(15)!).equals(Percentage.tryFromFraction(0.15)!);
      check(Percentage.tryFrom(15)! == Percentage.tryFrom(15.5)!).isFalse();
    });
  });
}
