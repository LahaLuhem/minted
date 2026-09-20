import 'package:checks/checks.dart';
import 'package:minted_constraints/minted_constraints.dart';

import '../../../../test/support/bdd.dart';

// Each of these 3 is a const context, so the file failing to build is the assertion: a getter could
// not stand in any of them.
const firstThree = <Digit>[DigitConstants.d0, DigitConstants.d1, DigitConstants.d2];

Digit startingAt([Digit start = DigitConstants.d0]) => start;

String nameOf(Digit digit) => switch (digit) {
  DigitConstants.d0 => 'zero',
  DigitConstants.d9 => 'nine',
  _ => 'neither end',
};

void main() {
  feature('Digit', () {
    // tryFrom takes the numeric value directly, and only 0-9 yield a Digit.
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
      check(DigitConstants.d7.toString()).equals('7');
    });

    scenario('equal digits are equal, and differing ones are not', () {
      check(Digit.tryFrom(7)).equals(Digit.tryFrom(7));
      check(Digit.tryFrom(7) == Digit.tryFrom(8)).isFalse();
    });

    scenario('the named constants carry their digit, whichever way one is built', () {
      check(DigitConstants.d0.value).equals(0);
      check(DigitConstants.d9.value).equals(9);
      check(Digit.tryFrom(7)).equals(DigitConstants.d7);
    });

    scenario('the constants reach const lists, default arguments and case patterns', () {
      check(firstThree.map((digit) => digit.value)).deepEquals([0, 1, 2]);
      check(startingAt()).equals(DigitConstants.d0);
      check(nameOf(DigitConstants.d9)).equals('nine');
      check(nameOf(DigitConstants.d5)).equals('neither end');
    });
  });
}
