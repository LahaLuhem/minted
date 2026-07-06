import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import 'support/bdd.dart';

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
      check(Digit.parse('7')).equals(Digit.from(7));
    });

    scenario('a Digit renders as its bare character', () {
      check(Digit.from(7).toString()).equals('7');
    });

    scenario('Digit.parse throws MintedFormatException, carrying the source', () {
      check(() => Digit.parse('x'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('x');
    });

    scenario('Digit.from throws MintedFormatException on an out-of-range value', () {
      check(() => Digit.from(10)).throws<MintedFormatException>();
    });
  });
}
