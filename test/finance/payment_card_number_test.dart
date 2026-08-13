import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('PaymentCardNumber', () {
    // The compact form doubles as the expected outcome: a String means "accepted and normalised to
    // this", null means "rejected". Valid rows are the networks' own published test numbers, which
    // are designed to be non-issuable; no real card number belongs in a repository.
    scenarioOutline<({String input, String? canonical})>(
      'tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'a Visa test number': (input: '4111111111111111', canonical: '4111111111111111'),
        'a second Visa test number': (input: '4012888888881881', canonical: '4012888888881881'),
        'a Mastercard test number': (input: '5555555555554444', canonical: '5555555555554444'),
        'a second Mastercard test number': (
          input: '5105105105105100',
          canonical: '5105105105105100',
        ),
        'a Mastercard 2-series test number': (
          input: '2223003122003222',
          canonical: '2223003122003222',
        ),
        'an American Express test number': (input: '378282246310005', canonical: '378282246310005'),
        'a second American Express test number': (
          input: '371449635398431',
          canonical: '371449635398431',
        ),
        'a Discover test number': (input: '6011111111111117', canonical: '6011111111111117'),
        'a second Discover test number': (input: '6011000990139424', canonical: '6011000990139424'),
        'a JCB test number': (input: '3530111333300000', canonical: '3530111333300000'),
        'a Diners Club test number': (input: '30569309025904', canonical: '30569309025904'),
        'a second Diners Club test number': (input: '38520000023237', canonical: '38520000023237'),
        'a UnionPay test number': (input: '6200000000000005', canonical: '6200000000000005'),
        // ISO/IEC 7812-1 Annex B's worked example: 1789372997 takes the check digit 4.
        'the Luhn example from the standard itself': (
          input: '17893729974',
          canonical: '17893729974',
        ),
        'cards are printed in groups, so spaces arrive with them': (
          input: '4111 1111 1111 1111',
          canonical: '4111111111111111',
        ),
        'hyphenated input is compacted too': (
          input: '4111-1111-1111-1111',
          canonical: '4111111111111111',
        ),
        'surrounding whitespace is stripped': (
          input: '  4111111111111111  ',
          canonical: '4111111111111111',
        ),
        'eight digits is the ISO floor': (input: '00000000', canonical: '00000000'),
        'twelve digits, the shortest length a card is issued at': (
          input: '411111111117',
          canonical: '411111111117',
        ),
        'nineteen digits is the ISO ceiling': (
          input: '4111111111111111110',
          canonical: '4111111111111111110',
        ),
        'seven digits is under the floor': (input: '4111111', canonical: null),
        'twenty digits is over the ceiling': (input: '41111111111111111119', canonical: null),
        'empty': (input: '', canonical: null),
        'a corrupted final digit fails the Luhn check': (
          input: '4111111111111112',
          canonical: null,
        ),
        'two transposed digits fail it as well': (input: '4012888888818881', canonical: null),
        'letters are not card-number characters': (input: '4111111111111abc', canonical: null),
        // A separator the compacting step doesn't strip usually lands on the length check instead,
        // since a card number has no positions to spend on one; sixteen digits plus three dots is
        // nineteen characters, so this row reaches the charset check.
        'dots survive the separator strip': (input: '4111.1111.1111.1111', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as a card number ...
        final parsedNumber = PaymentCardNumber.tryParse(example.input);

        // Then it is normalised to its compact form, or rejected (null).
        check(parsedNumber?.value).equals(example.canonical);
      },
    );

    scenario('the grouped and compact spellings of one card are equal', () {
      check(PaymentCardNumber.tryParse('4111 1111 1111 1111')!)
          .equals(PaymentCardNumber.tryParse('4111111111111111')!);
      check({
        PaymentCardNumber.tryParse('4111111111111111')!,
        PaymentCardNumber.tryParse('4111-1111-1111-1111')!,
        PaymentCardNumber.tryParse('4111 1111 1111 1111')!,
      }).length.equals(1);
    });

    scenario('a sixteen-digit number exposes each of its parts', () {
      final parsedNumber = PaymentCardNumber.tryParse('4111111111111111')!;

      check(parsedNumber.majorIndustryIdentifier.value).equals(4);
      check(parsedNumber.iin6).equals('411111');
      check(parsedNumber.iin8).equals('41111111');
      check(parsedNumber.last4).equals('1111');
      check(parsedNumber.checkDigit.value).equals(1);
    });

    // An issuer identification number needs a check digit after it, so the shortest numbers cannot
    // report the wider one at all rather than overlapping it.
    scenarioOutline<({String input, String? iin6, String? iin8})>(
      'the issuer identification number is null when the card is too short to hold it',
      examples: {
        'eight digits leaves no room for an eight-digit IIN': (
          input: '00000000',
          iin6: '000000',
          iin8: null,
        ),
        'twelve digits holds both': (input: '411111111117', iin6: '411111', iin8: '41111111'),
      },
      outline: (example) {
        final parsedNumber = PaymentCardNumber.tryParse(example.input)!;

        check(parsedNumber.iin6).equals(example.iin6);
        check(parsedNumber.iin8).equals(example.iin8);
      },
    );

    scenario('the rendered form masks everything but the last four digits', () {
      final parsedNumber = PaymentCardNumber.tryParse('4111111111111111')!;

      check(parsedNumber.masked).equals('••••1111');
      // Interpolation and print() both route through toString, so neither can leak the number.
      check('$parsedNumber').equals('PaymentCardNumber(••••1111)');
      check(parsedNumber.toString()).not((it) => it.contains('4111111111111111'));
    });

    // Mod-10 is blind to a 09/90 transposition and to the twin errors 22/55, 33/66 and 44/77: both
    // members of each pair carry the same weighted sum. That is a property of the standard, not of
    // this implementation, so it is pinned rather than left to read as a bug.
    scenarioOutline<({String accepted, String alsoAccepted})>(
      'the Luhn check cannot catch these, a blind spot the standard carries',
      examples: {
        'a 09 transposed to 90': (accepted: '4111110000000096', alsoAccepted: '4111110000000906'),
        'a 22 mistyped as 55': (accepted: '4111110000000229', alsoAccepted: '4111110000000559'),
        'a 33 mistyped as 66': (accepted: '4111110000000336', alsoAccepted: '4111110000000666'),
        'a 44 mistyped as 77': (accepted: '4111110000000443', alsoAccepted: '4111110000000773'),
      },
      outline: (example) {
        check(PaymentCardNumber.tryParse(example.accepted)).isNotNull();
        check(PaymentCardNumber.tryParse(example.alsoAccepted)).isNotNull();
      },
    );

    scenarioOutline<({String input, PaymentCardNumberFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input is no length at all': (
          input: '',
          failure: const PaymentCardNumberWrongLength(0),
        ),
        'seven digits is under the floor': (
          input: '4111111',
          failure: const PaymentCardNumberWrongLength(7),
        ),
        'twenty digits is over the ceiling': (
          input: '41111111111111111119',
          failure: const PaymentCardNumberWrongLength(20),
        ),
        'letters inside the window reach the charset check': (
          input: '4111111111111abc',
          failure: const PaymentCardNumberInvalidCharacters(),
        ),
        'a mistyped digit reaches the Luhn check': (
          input: '4111111111111112',
          failure: const PaymentCardNumberChecksumFailed(),
        ),
      },
      outline: (example) =>
          check(PaymentCardNumber.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('parse reports the failure rather than throwing', () {
      check(PaymentCardNumber.parse('4111111111111112'))
          .equals(const ParseFailure(PaymentCardNumberChecksumFailed()));
      check(PaymentCardNumber.parse('4111111111111111').isSuccess).isTrue();
    });

    scenario('fromComponents computes the check digit', () {
      final assembledNumber = PaymentCardNumber.fromComponents(
        iin: Digits.parse('411111').getOrThrow(),
        accountIdentifier: Digits.parse('111111111').getOrThrow(),
      );

      // The parts of the Visa test number above, so the computed digit is checkable by eye.
      check(assembledNumber.value).equals('4111111111111111');
      check(assembledNumber.checkDigit.value).equals(1);
    });

    scenarioOutline<({String iin, String accountIdentifier, PaymentCardNumberFailure failure})>(
      'fromComponents reports the same vocabulary as parse',
      examples: {
        'parts too short to reach the floor': (
          iin: '4111',
          accountIdentifier: '11',
          failure: const PaymentCardNumberWrongLength(7),
        ),
        'parts past the ceiling': (
          iin: '41111111',
          accountIdentifier: '111111111111',
          failure: const PaymentCardNumberWrongLength(21),
        ),
      },
      outline: (example) {
        check(
              () => PaymentCardNumber.fromComponents(
                iin: Digits.parse(example.iin).getOrThrow(),
                accountIdentifier: Digits.parse(example.accountIdentifier).getOrThrow(),
              ),
            )
            .throws<MintedFormatException>()
            .has((error) => error.failure, 'failure')
            .equals(example.failure);
      },
    );

    scenario('fromComponents error carries the components as its source', () {
      check(
            () => PaymentCardNumber.fromComponents(
              iin: Digits.parse('4111').getOrThrow(),
              accountIdentifier: Digits.parse('11').getOrThrow(),
            ),
          )
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('4111 + 11');
    });

    // The scheme is reported, not validated, so every row here parses. One row per listed scheme,
    // plus the two cases the table deliberately declines to answer.
    scenarioOutline<({String input, CardScheme cardScheme, List<CardScheme> cardSchemes})>(
      'the card scheme is reported from the prefix',
      examples: {
        'Visa opens with 4': (input: '4111111111111111', cardScheme: .visa, cardSchemes: [.visa]),
        'Mastercard in its 51-55 block': (
          input: '5555555555554444',
          cardScheme: .mastercard,
          cardSchemes: [.mastercard],
        ),
        'Mastercard in its 2-series block': (
          input: '2223003122003222',
          cardScheme: .mastercard,
          cardSchemes: [.mastercard],
        ),
        'American Express opens with 37': (
          input: '371449635398431',
          cardScheme: .americanExpress,
          cardSchemes: [.americanExpress],
        ),
        'JCB inside 3528-3589': (input: '3530111333300000', cardScheme: .jcb, cardSchemes: [.jcb]),
        'Diners Club opens with 30': (
          input: '30569309025904',
          cardScheme: .dinersClub,
          cardSchemes: [.dinersClub],
        ),
        'Discover opens with 6011': (
          input: '6011111111111117',
          cardScheme: .discover,
          cardSchemes: [.discover],
        ),
        'UnionPay opens with 62': (
          input: '6200000000000005',
          cardScheme: .unionPay,
          cardSchemes: [.unionPay],
        ),
        // The 622126-622925 window is a real co-brand, so one number is honestly both.
        'the UnionPay window Discover also accepts is both': (
          input: '6221260000000000',
          cardScheme: .unknown,
          cardSchemes: [.unionPay, .discover],
        ),
        // Discover and RuPay both claim 65, so the table lists it for neither.
        'a contested range is claimed for nobody': (
          input: '6500000000000002',
          cardScheme: .unknown,
          cardSchemes: [],
        ),
        'the example from the standard belongs to no scheme': (
          input: '17893729974',
          cardScheme: .unknown,
          cardSchemes: [],
        ),
      },
      outline: (example) {
        final parsedNumber = PaymentCardNumber.tryParse(example.input);

        check(parsedNumber).isNotNull();
        check(parsedNumber!.cardScheme).equals(example.cardScheme);
        check(parsedNumber.cardSchemes).unorderedEquals(example.cardSchemes);
      },
    );

    // The static answers from partial input, which no instance getter can do: a half-typed number
    // has no check digit yet, so it cannot parse.
    scenarioOutline<({String input, List<CardScheme> cardSchemes})>(
      'cardSchemesOf answers while the number is still being typed',
      examples: {
        'one digit already places Visa': (input: '4', cardSchemes: [.visa]),
        'two digits place Mastercard': (input: '55', cardSchemes: [.mastercard]),
        'a partial co-brand reports both': (input: '622126', cardSchemes: [.unionPay, .discover]),
        'a prefix one digit short of its range says nothing yet': (input: '2', cardSchemes: []),
        'grouping is stripped here too': (input: '4111 11', cardSchemes: [.visa]),
        'empty input claims nothing': (input: '', cardSchemes: []),
        'letters claim nothing': (input: 'abcd', cardSchemes: []),
      },
      outline: (example) =>
          check(PaymentCardNumber.cardSchemesOf(example.input))
              .unorderedEquals(example.cardSchemes),
    );
  });
}
