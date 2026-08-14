import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';
import '../support/digits.dart';

void main() {
  feature('Gtin', () {
    // The canonical fourteen-digit form doubles as the expected outcome: a String means "accepted
    // and normalised to this", null means "rejected". Valid rows are published worked examples.
    scenarioOutline<({String input, String? canonical})>(
      'Gtin.tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'a GTIN-14, already the canonical length': (
          input: '10614141000415',
          canonical: '10614141000415',
        ),
        'an EAN-13 gains one leading zero': (input: '4006381333931', canonical: '04006381333931'),
        'a UPC-A gains two': (input: '036000291452', canonical: '00036000291452'),
        'an EAN-8 gains six': (input: '96385074', canonical: '00000096385074'),
        'an ISBN-13 is a GTIN-13 too, so it parses as one': (
          input: '9780306406157',
          canonical: '09780306406157',
        ),
        'hyphens group a GTIN as often as nothing does': (
          input: '4-006381-333931',
          canonical: '04006381333931',
        ),
        'spaces are stripped as well': (input: '036000 291452', canonical: '00036000291452'),
        'an already-padded GTIN-13 is the same number': (
          input: '04006381333931',
          canonical: '04006381333931',
        ),
        'a corrupted final check digit': (input: '4006381333932', canonical: null),
        'a corrupted EAN-8 check digit': (input: '96385075', canonical: null),
        'two transposed digits inside the number': (input: '4006381333391', canonical: null),
        'nine digits is not a GS1 length': (input: '400638133', canonical: null),
        'ten digits is not one either': (input: '4006381333', canonical: null),
        'eleven digits sits between UPC-A and nothing': (input: '40063813339', canonical: null),
        'fifteen digits is past GTIN-14': (input: '400638133393100', canonical: null),
        'letters are not a GTIN of any length': (input: 'ABCDEFGH', canonical: null),
        'empty': (input: '', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as a GTIN ...
        final parsedGtin = Gtin.tryParse(example.input);

        // Then it is normalised to the fourteen-digit form, or rejected (null).
        check(parsedGtin?.value).equals(example.canonical);
      },
    );

    scenario('the four lengths of one trade item are equal', () {
      final paddedGtin14 = Gtin.tryParse('00000096385074')!;

      check(Gtin.tryParse('96385074')!).equals(paddedGtin14);
      check(Gtin.tryParse('0000096385074')!).equals(paddedGtin14);
    });

    // The shorter forms are re-derived from the padded value, not stored, so these pin that the
    // padding is genuinely reversible.
    scenarioOutline<
      ({String input, String? gtin13, String? gtin12, String? gtin8, String shortest})
    >(
      'a GTIN spells itself back at every length it fits, and null at the ones it does not',
      examples: {
        'an EAN-8 fits all four': (
          input: '96385074',
          gtin13: '0000096385074',
          gtin12: '000096385074',
          gtin8: '96385074',
          shortest: '96385074',
        ),
        'a UPC-A fits three': (
          input: '036000291452',
          gtin13: '0036000291452',
          gtin12: '036000291452',
          gtin8: null,
          shortest: '036000291452',
        ),
        'an EAN-13 fits two': (
          input: '4006381333931',
          gtin13: '4006381333931',
          gtin12: null,
          gtin8: null,
          shortest: '4006381333931',
        ),
        'a true GTIN-14 fits only itself': (
          input: '10614141000415',
          gtin13: null,
          gtin12: null,
          gtin8: null,
          shortest: '10614141000415',
        ),
      },
      outline: (example) {
        final parsedGtin = Gtin.tryParse(example.input)!;

        check(parsedGtin.gtin13).equals(example.gtin13);
        check(parsedGtin.gtin12).equals(example.gtin12);
        check(parsedGtin.gtin8).equals(example.gtin8);
        check(parsedGtin.shortestForm).equals(example.shortest);
      },
    );

    scenario('a GTIN exposes its check digit', () {
      check(Gtin.tryParse('4006381333931')!.checkDigit).equals(Digit.tryFrom(1)!);
      check(Gtin.tryParse('96385074')!.checkDigit).equals(Digit.tryFrom(4)!);
    });

    scenarioOutline<({String input, GtinFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input has no digits to weigh': (input: '', failure: const GtinWrongLength(0)),
        'nine digits is none of the four lengths': (
          input: '400638133',
          failure: const GtinWrongLength(9),
        ),
        'fifteen digits is past GTIN-14': (
          input: '400638133393100',
          failure: const GtinWrongLength(15),
        ),
        'a stray letter is not a GTIN character': (
          input: '400638133393A',
          failure: const GtinInvalidCharacters(),
        ),
        'X is not a GTIN check digit the way it is an ISBN-10 one': (
          input: '40063813339X',
          failure: const GtinInvalidCharacters(),
        ),
        'a corrupted final digit fails mod-10': (
          input: '4006381333932',
          failure: const GtinChecksumFailed(),
        ),
        'a corrupted EAN-8 fails the same check': (
          input: '96385075',
          failure: const GtinChecksumFailed(),
        ),
      },
      outline: (example) => check(Gtin.parse(example.input).reasonOrNull).equals(example.failure),
    );

    // A property of GS1 mod-10, not a gap in ours: swapping adjacent digits five apart leaves the
    // weighted sum unchanged. Pinned so nobody "fixes" it later.
    scenario('mod-10 cannot catch a transposition of two adjacent digits differing by five', () {
      // 3 and 8 sit adjacent and five apart, so both spellings carry check digit 4.
      check(Gtin.tryParse('96385074')?.value).equals('00000096385074');
      check(Gtin.tryParse('96835074')?.value).equals('00000096835074');
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Gtin.parse('4006381333932')).equals(const ParseFailure(GtinChecksumFailed()));
      check(Gtin.parse('4006381333931').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Gtin.tryParse('4006381333932')).isNull();
      check(Gtin.tryParse('96385074')?.value).equals('00000096385074');
    });

    // fromBody runs our GS1 mod-10 generator; check it reproduces the published check digit at every
    // length rather than round-tripping our own output.
    scenarioOutline<({String body, String gtin})>(
      'fromBody computes the check digit to match the published GTIN',
      examples: {
        'a GTIN-8 body': (body: '9638507', gtin: '00000096385074'),
        'a UPC-A body': (body: '03600029145', gtin: '00036000291452'),
        'an EAN-13 body': (body: '400638133393', gtin: '04006381333931'),
        'a GTIN-14 body': (body: '1061414100041', gtin: '10614141000415'),
      },
      outline: (example) =>
          check(Gtin.fromBody(digitsOf(example.body)).getOrThrow().value).equals(example.gtin),
    );

    scenarioOutline<({String body, GtinFailure failure})>(
      'fromBody reports the same vocabulary as parse',
      examples: {
        'a body whose length plus a check digit is none of the four': (
          body: '400638133',
          failure: const GtinWrongLength(10),
        ),
      },
      outline: (example) {
        check(Gtin.fromBody(digitsOf(example.body)).reasonOrNull).equals(example.failure);
      },
    );

    scenario('a caller who asserts the body gets the throw back through getOrThrow', () {
      check(() => Gtin.fromBody(Digits.tryFrom([4, 0, 0, 6, 3, 8, 1, 3, 3])!).getOrThrow())
          .throws<MintedFormatException>()
          .has((error) => error.failure, 'failure')
          .equals(const GtinWrongLength(10));
    });
  });
}
