import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Isin', () {
    // The compact twelve-character form doubles as the expected outcome: a String means "accepted
    // and normalised to this", null means "rejected". Valid rows are real, published ISINs.
    scenarioOutline<({String input, String? canonical})>(
      'Isin.tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'Apple': (input: 'US0378331005', canonical: 'US0378331005'),
        'Microsoft': (input: 'US5949181045', canonical: 'US5949181045'),
        'BAE Systems': (input: 'GB0002634946', canonical: 'GB0002634946'),
        'Tesla, a letter inside the NSIN': (input: 'US88160R1014', canonical: 'US88160R1014'),
        'the ISO 6166 worked example, letter-heavy': (
          input: 'AU0000XVGZA3',
          canonical: 'AU0000XVGZA3',
        ),
        'lower case is upper-cased before the check': (
          input: 'au0000xvgza3',
          canonical: 'AU0000XVGZA3',
        ),
        'whitespace is stripped': (input: 'US 0378 3310 05', canonical: 'US0378331005'),
        'a corrupted check digit': (input: 'US0378331006', canonical: null),
        'two transposed digits in the NSIN': (input: 'US0378313005', canonical: null),
        'a corrupted letter in the NSIN': (input: 'US88160S1014', canonical: null),
        'eleven characters is one short': (input: 'US037833100', canonical: null),
        'thirteen is one long': (input: 'US03783310055', canonical: null),
        'a hyphen is not an ISIN character': (input: 'US-378331005', canonical: null),
        'a digit cannot open the prefix': (input: '1S0378331005', canonical: null),
        'empty': (input: '', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as an ISIN ...
        final parsedIsin = Isin.tryParse(example.input);

        // Then it is normalised to the compact upper-case form, or rejected (null).
        check(parsedIsin?.value).equals(example.canonical);
      },
    );

    scenario('the spaced and compact spellings of one security are equal', () {
      check(Isin.tryParse('US 0378 3310 05')!).equals(Isin.tryParse('US0378331005')!);
    });

    scenarioOutline<({String input, String prefix, String nsin, int checkDigit})>(
      'an ISIN exposes its prefix, NSIN, and check digit',
      examples: {
        'a US security, whose NSIN is its CUSIP': (
          input: 'US0378331005',
          prefix: 'US',
          nsin: '037833100',
          checkDigit: 5,
        ),
        'an NSIN carrying letters': (
          input: 'AU0000XVGZA3',
          prefix: 'AU',
          nsin: '0000XVGZA',
          checkDigit: 3,
        ),
      },
      outline: (example) {
        final parsedIsin = Isin.tryParse(example.input)!;

        check(parsedIsin.prefix).equals(example.prefix);
        check(parsedIsin.nsin).equals(example.nsin);
        check(parsedIsin.checkDigit).equals(Digit.from(example.checkDigit));
      },
    );

    // The prefix is enforced as two letters, never as a country: rejecting XS would refuse real
    // ISINs, so the country fact is reported instead. Same call as Bic.isSwiftRegistrable.
    // The two non-country numbers below are constructed to satisfy the check digit rather than
    // taken from a published security; only the prefixes they carry are the point.
    scenarioOutline<({String input, bool hasCountryPrefix})>(
      'a non-country prefix parses, and says so rather than being refused',
      examples: {
        'GB is a country': (input: 'GB0002634946', hasCountryPrefix: true),
        'US is a country': (input: 'US0378331005', hasCountryPrefix: true),
        'XS is Euroclear and Clearstream, not a country': (
          input: 'XS0000000009',
          hasCountryPrefix: false,
        ),
        'EU is supranational': (input: 'EU000A1G0AA6', hasCountryPrefix: false),
      },
      outline: (example) {
        final parsedIsin = Isin.tryParse(example.input);

        check(parsedIsin).isNotNull();
        check(parsedIsin!.hasCountryPrefix).equals(example.hasCountryPrefix);
      },
    );

    scenarioOutline<({String input, IsinFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input has nothing to weigh': (input: '', failure: const IsinWrongLength(0)),
        'eleven characters is one short': (
          input: 'US037833100',
          failure: const IsinWrongLength(11),
        ),
        'a hyphen is outside the charset': (
          input: 'US-378331005',
          failure: const IsinInvalidCharacters(),
        ),
        'a lower-case letter survives only because it is upper-cased first': (
          input: 'US03783310@5',
          failure: const IsinInvalidCharacters(),
        ),
        'a digit cannot open the prefix': (
          input: '1S0378331005',
          failure: const IsinInvalidPrefix('1S'),
        ),
        'nor can two digits': (input: '120378331005', failure: const IsinInvalidPrefix('12')),
        'a corrupted check digit fails Luhn': (
          input: 'US0378331006',
          failure: const IsinChecksumFailed(),
        ),
        'a corrupted letter fails it too': (
          input: 'US88160S1014',
          failure: const IsinChecksumFailed(),
        ),
      },
      outline: (example) => check(Isin.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('parse reports the failure rather than throwing', () {
      check(Isin.parse('US0378331006')).equals(const ParseFailure(IsinChecksumFailed()));
      check(Isin.parse('US0378331005').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Isin.tryParse('US0378331006')).isNull();
      check(Isin.tryParse('us0378331005')?.value).equals('US0378331005');
    });

    // fromComponents runs our expand-then-Luhn generator; check it reproduces the published check
    // digit rather than round-tripping our own output. Letter-carrying NSINs are the interesting
    // rows, because those are the ones whose expansion changes the weighting.
    scenarioOutline<({String prefix, String nsin, String isin})>(
      'fromComponents computes the check digit to match the published ISIN',
      examples: {
        'Apple': (prefix: 'US', nsin: '037833100', isin: 'US0378331005'),
        'Deutsche Telekom': (prefix: 'DE', nsin: '000555750', isin: 'DE0005557508'),
        'Nestle': (prefix: 'CH', nsin: '001203204', isin: 'CH0012032048'),
        'Tesla, one letter in the NSIN': (prefix: 'US', nsin: '88160R101', isin: 'US88160R1014'),
        'the AU example, five letters in the NSIN': (
          prefix: 'AU',
          nsin: '0000XVGZA',
          isin: 'AU0000XVGZA3',
        ),
      },
      outline: (example) {
        check(
          Isin.fromComponents(prefix: example.prefix, nsin: example.nsin).value,
        ).equals(example.isin);
      },
    );

    scenario('fromComponents normalises a spaced, lower-case input', () {
      check(Isin.fromComponents(prefix: 'au', nsin: '0000 XVGZA').value).equals('AU0000XVGZA3');
    });

    scenarioOutline<({String prefix, String nsin, IsinFailure failure})>(
      'fromComponents reports the same vocabulary as parse',
      examples: {
        'a short NSIN cannot reach twelve characters': (
          prefix: 'US',
          nsin: '03783310',
          failure: const IsinWrongLength(11),
        ),
        'the generator refuses a part outside the charset': (
          prefix: 'US',
          nsin: '0378331@0',
          failure: const IsinInvalidCharacters(),
        ),
        'a prefix that is not two letters': (
          prefix: '1S',
          nsin: '037833100',
          failure: const IsinInvalidPrefix('1S'),
        ),
      },
      outline: (example) {
        check(() => Isin.fromComponents(prefix: example.prefix, nsin: example.nsin))
            .throws<MintedFormatException>()
            .has((error) => error.failure, 'failure')
            .equals(example.failure);
      },
    );

    scenario('fromComponents error carries the components as its source', () {
      check(() => Isin.fromComponents(prefix: 'US', nsin: '03783310'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('US + 03783310');
    });
  });
}
