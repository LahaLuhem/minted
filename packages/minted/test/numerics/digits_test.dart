import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Digits', () {
    // Values in, digits out; null means at least one value was not 0-9.
    scenarioOutline<({List<int> input, String? canonical})>(
      'Digits.tryFrom accepts in-range values and rejects the rest',
      examples: {
        'a run of digits': (input: [9, 0, 5], canonical: '905'),
        'a single digit': (input: [7], canonical: '7'),
        'empty is an empty sequence': (input: [], canonical: ''),
        'a value above nine': (input: [9, 10, 5], canonical: null),
        'a negative value': (input: [9, -1, 5], canonical: null),
      },
      outline: (example) {
        check(Digits.tryFrom(example.input)?.asString).equals(example.canonical);
      },
    );

    scenario('a single-digit sequence exposes its one Digit', () {
      final parsedDigits = Digits.tryFrom([7])!;

      check(parsedDigits.length).equals(1);
      check(parsedDigits.isEmpty).isFalse();
      check(parsedDigits[0]).equals(Digit.tryFrom(7)!);
    });

    scenario('an empty sequence has no digits', () {
      final parsedDigits = Digits.tryFrom([])!;

      check(parsedDigits.length).equals(0);
      check(parsedDigits.isEmpty).isTrue();
      check(parsedDigits.asString).equals('');
    });

    scenario('indexing and iteration agree', () {
      final parsedDigits = Digits.tryFrom([9, 0, 5])!;

      check(parsedDigits[0]).equals(Digit.tryFrom(9)!);
      check(parsedDigits[2]).equals(Digit.tryFrom(5)!);
      check(parsedDigits.toList())
          .deepEquals([Digit.tryFrom(9), Digit.tryFrom(0), Digit.tryFrom(5)]);
    });

    scenario('a Digits is an Iterable of its Digits', () {
      check(Digits.tryFrom([9, 0, 5])!.map((digit) => digit.value).toList()).deepEquals([9, 0, 5]);
      check(Digits.tryFrom([1, 2, 3, 2, 1])!.where((digit) => digit == Digit.tryFrom(2)!).length)
          .equals(2);
    });

    scenario('equal sequences are equal by value and hash', () {
      check(Digits.tryFrom([1, 2, 3])).equals(Digits.tryFrom([1, 2, 3]));
      check(Digits.tryFrom([1, 2, 3])!.hashCode).equals(Digits.tryFrom([1, 2, 3])!.hashCode);
    });

    scenario('different sequences are not equal', () {
      check(Digits.tryFrom([1, 2, 3]) == Digits.tryFrom([1, 2, 4])).isFalse();
    });

    scenario('of builds a sequence from already-valid Digits', () {
      check(Digits.of([Digit.tryFrom(9)!, Digit.tryFrom(0)!, Digit.tryFrom(5)!]).asString)
          .equals('905');
    });

    scenario('a Digits renders its digits, not Instance of', () {
      // Digits is the one value type that hand-writes toString; the extension types inherit theirs.
      check(Digits.tryFrom([9, 0, 5])!.toString()).equals('Digits(905)');
      check(Digits.tryFrom([])!.toString()).equals('Digits()');
    });
  });
}
