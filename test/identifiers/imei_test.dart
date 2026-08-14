import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';
import '../support/digits.dart';

void main() {
  feature('Imei', () {
    // The compact fifteen-digit form doubles as the expected outcome: a String means "accepted and
    // normalised to this", null means "rejected". Valid rows are published test IMEIs.
    scenarioOutline<({String input, String? canonical})>(
      'Imei.tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'a compact IMEI': (input: '490154203237518', canonical: '490154203237518'),
        'the printed grouping is stripped back': (
          input: '35-209900-176148-1',
          canonical: '352099001761481',
        ),
        'spaces group an IMEI as often as hyphens': (
          input: '35 693803 564380 9',
          canonical: '356938035643809',
        ),
        'a corrupted final check digit': (input: '490154203237510', canonical: null),
        'a corrupted digit inside the serial': (input: '352099001861481', canonical: null),
        'two transposed digits three apart': (input: '490154203237581', canonical: null),
        'fourteen digits is an IMEI missing its check digit': (
          input: '49015420323751',
          canonical: null,
        ),
        'sixteen digits is an IMEISV': (input: '3520990017614810', canonical: null),
        'letters are not an IMEI': (input: 'ABCDEFGHIJKLMNO', canonical: null),
        'empty': (input: '', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as an IMEI ...
        final parsedImei = Imei.tryParse(example.input);

        // Then it is normalised to the compact form, or rejected (null).
        check(parsedImei?.value).equals(example.canonical);
      },
    );

    scenario('the printed and compact spellings of one handset are equal', () {
      check(Imei.tryParse('35-209900-176148-1')!).equals(Imei.tryParse('352099001761481')!);
    });

    scenario('an IMEI exposes its TAC, allocating body, serial, and check digit', () {
      final parsedImei = Imei.tryParse('352099001761481')!;

      check(parsedImei.tac).equals('35209900');
      check(parsedImei.reportingBodyIdentifier).equals('35');
      check(parsedImei.serialNumber).equals('176148');
      check(parsedImei.checkDigit).equals(Digit.tryFrom(1)!);
    });

    scenario('formatted rebuilds the printed grouping', () {
      check(Imei.tryParse('352099001761481')!.formatted).equals('35-209900-176148-1');
      check(Imei.tryParse('490154203237518')!.formatted).equals('49-015420-323751-8');
    });

    scenarioOutline<({String input, ImeiFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input has no digits to weigh': (input: '', failure: const ImeiWrongLength(0)),
        'fourteen digits is one short': (
          input: '49015420323751',
          failure: const ImeiWrongLength(14),
        ),
        'sixteen digits is named as the IMEISV it is': (
          input: '3520990017614810',
          failure: const ImeiWrongLength(16),
        ),
        'a stray letter is not an IMEI character': (
          input: '35209900176148A',
          failure: const ImeiInvalidCharacters(),
        ),
        'a corrupted final digit fails Luhn': (
          input: '490154203237510',
          failure: const ImeiChecksumFailed(),
        ),
        'a corrupted inner digit fails the same check': (
          input: '352099001861481',
          failure: const ImeiChecksumFailed(),
        ),
      },
      outline: (example) => check(Imei.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('the IMEISV failure says what the number actually is', () {
      check(Imei.parse('3520990017614810').reasonOrNull?.message)
          .equals('16 digits is an IMEISV, not an IMEI');
    });

    // A property of Luhn, not a gap in ours: an adjacent 0 and 9 sum the same whichever is doubled.
    // Pinned so nobody "fixes" it later.
    scenario('Luhn cannot catch a transposed adjacent 0 and 9', () {
      check(Imei.tryParse('352099001761481')?.value).equals('352099001761481');
      check(Imei.tryParse('352909001761481')?.value).equals('352909001761481');
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Imei.parse('490154203237510')).equals(const ParseFailure(ImeiChecksumFailed()));
      check(Imei.parse('490154203237518').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Imei.tryParse('490154203237510')).isNull();
      check(Imei.tryParse('35-209900-176148-1')?.value).equals('352099001761481');
    });

    // fromComponents runs our Luhn generator; check it reproduces the published check digit rather
    // than round-tripping our own output.
    scenarioOutline<({String tac, String serialNumber, String imei})>(
      'fromComponents computes the check digit to match the published IMEI',
      examples: {
        'a BABT-allocated TAC': (tac: '35209900', serialNumber: '176148', imei: '352099001761481'),
        'a check digit of eight': (
          tac: '49015420',
          serialNumber: '323751',
          imei: '490154203237518',
        ),
        'a check digit of nine': (tac: '35693803', serialNumber: '564380', imei: '356938035643809'),
      },
      outline: (example) {
        check(
          Imei.fromComponents(
            tac: digitsOf(example.tac),
            serialNumber: digitsOf(example.serialNumber),
          ).getOrThrow().value,
        ).equals(example.imei);
      },
    );

    scenarioOutline<({String tac, String serialNumber, ImeiFailure failure})>(
      'fromComponents reports the same vocabulary as parse',
      examples: {
        'a short TAC cannot reach fifteen digits': (
          tac: '352099',
          serialNumber: '176148',
          failure: const ImeiWrongLength(13),
        ),
        'a long serial overshoots': (
          tac: '35209900',
          serialNumber: '1761480',
          failure: const ImeiWrongLength(16),
        ),
      },
      outline: (example) {
        check(
          Imei.fromComponents(
            tac: digitsOf(example.tac),
            serialNumber: digitsOf(example.serialNumber),
          ).reasonOrNull,
        ).equals(example.failure);
      },
    );

    scenario('a caller who asserts the parts gets the throw back through getOrThrow', () {
      check(
            () => Imei.fromComponents(
              tac: Digits.tryFrom([3, 5, 2, 0, 9, 9])!,
              serialNumber: Digits.tryFrom([1, 7, 6, 1, 4, 8])!,
            ).getOrThrow(),
          )
          .throws<MintedFormatException>()
          .has((error) => error.failure, 'failure')
          .equals(const ImeiWrongLength(13));
    });
  });
}
