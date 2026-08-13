// These doors are deprecated for removal in 2.0.0 but still ship in 1.x, so their tests
// stay until they go; see #44.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Digit', () {
    // A digit is exactly one character in 0-9. The expected `.value` doubles as
    // the outcome; null means the input was rejected.
    scenarioOutline<({String input, int? value})>(
      'Digit.tryParse accepts a single 0-9 character and rejects the rest',
      examples: {
        'zero': (input: '0', value: 0),
        'nine': (input: '9', value: 9),
        'a mid digit': (input: '5', value: 5),
        'more than one character': (input: '12', value: null),
        'a letter': (input: 'a', value: null),
        'a non-ASCII digit': (input: '١', value: null),
        'a sign': (input: '-', value: null),
        'whitespace': (input: ' ', value: null),
        'empty': (input: '', value: null),
      },
      outline: (example) {
        check(Digit.tryParse(example.input)?.value).equals(example.value);
      },
    );

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

    scenario('the string and integer factories agree', () {
      check(Digit.parse('7')).equals(ParseSuccess(Digit.from(7)));
    });

    scenario('a Digit renders as its bare character', () {
      check(Digit.from(7).toString()).equals('7');
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Digit.parse('x')).equals(const ParseFailure(DigitFailure.notADigit));
      check(Digit.parse('x').reasonOrNull).equals(DigitFailure.notADigit);
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Digit.tryParse('x')).isNull();
      check(Digit.tryParse('7')).equals(Digit.from(7));
    });

    scenario('from still throws, because calling it asserts the value is in range', () {
      check(() => Digit.from(10))
          .throws<MintedFormatException>()
          .has((error) => error.failure, 'failure')
          .equals(DigitFailure.notADigit);
    });

    scenario('both doors report the same one failure a digit has', () {
      check(Digit.parse('x').reasonOrNull).equals(DigitFailure.notADigit);
      check(() => Digit.from(10))
          .throws<MintedFormatException>()
          .has((error) => error.failure, 'failure')
          .equals(DigitFailure.notADigit);
    });
  });
}
