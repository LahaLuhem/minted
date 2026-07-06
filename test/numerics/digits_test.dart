import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Digits', () {
    // A digits-only string round-trips through asString; null means rejected.
    scenarioOutline<({String input, String? canonical})>(
      'Digits.tryParse accepts digit-only strings and rejects the rest',
      examples: {
        'a run of digits': (input: '905', canonical: '905'),
        'a single digit': (input: '7', canonical: '7'),
        'empty is an empty sequence': (input: '', canonical: ''),
        'a letter in the middle': (input: '90x5', canonical: null),
        'a leading sign': (input: '-5', canonical: null),
        'a non-ASCII digit': (input: '٥', canonical: null),
        'spaces': (input: '9 0 5', canonical: null),
      },
      outline: (example) {
        check(Digits.tryParse(example.input)?.asString).equals(example.canonical);
      },
    );

    scenario('a single-digit sequence exposes its one Digit', () {
      final parsedDigits = Digits.parse('7');

      check(parsedDigits.length).equals(1);
      check(parsedDigits.isEmpty).isFalse();
      check(parsedDigits[0]).equals(Digit.from(7));
    });

    scenario('an empty sequence has no digits', () {
      final parsedDigits = Digits.parse('');

      check(parsedDigits.length).equals(0);
      check(parsedDigits.isEmpty).isTrue();
      check(parsedDigits.asString).equals('');
    });

    scenario('indexing and iteration agree', () {
      final parsedDigits = Digits.parse('905');

      check(parsedDigits[0]).equals(Digit.from(9));
      check(parsedDigits[2]).equals(Digit.from(5));
      check(parsedDigits.toList()).deepEquals([Digit.from(9), Digit.from(0), Digit.from(5)]);
    });

    scenario('a Digits is an Iterable of its Digits', () {
      check(Digits.parse('905').map((digit) => digit.value).toList()).deepEquals([9, 0, 5]);
      check(Digits.parse('12321').where((digit) => digit == Digit.from(2)).length).equals(2);
    });

    scenario('equal sequences are equal by value and hash', () {
      check(Digits.parse('12345')).equals(Digits.parse('12345'));
      check(Digits.parse('12345').hashCode).equals(Digits.parse('12345').hashCode);
    });

    scenario('different sequences are not equal', () {
      check(Digits.parse('12345') == Digits.parse('12346')).isFalse();
    });

    scenario('tryFrom accepts in-range values and rejects out-of-range', () {
      check(Digits.tryFrom([9, 0, 5])?.asString).equals('905');
      check(Digits.tryFrom([9, 10, 5])).isNull();
      check(Digits.tryFrom([9, -1, 5])).isNull();
    });

    scenario('of builds a sequence from already-valid Digits', () {
      check(Digits.of([Digit.from(9), Digit.from(0), Digit.from(5)]).asString).equals('905');
    });

    scenario('Digits.parse throws MintedFormatException, carrying the source', () {
      check(() => Digits.parse('90x'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('90x');
    });

    scenario('Digits.from throws MintedFormatException on an out-of-range value', () {
      check(() => Digits.from([9, 10])).throws<MintedFormatException>();
    });
  });
}
