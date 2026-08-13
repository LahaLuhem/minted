import 'package:checks/checks.dart';
import 'package:minted/minted.dart';

import '../support/bdd.dart';

void main() {
  feature('Iban', () {
    // Acceptance and normalisation in one table: the canonical (compact,
    // upper-cased) form doubles as the expected outcome. A String means
    // "accepted and normalised to this"; null means "rejected". The valid rows
    // are registry examples, including Oman (mandated 2024/2025) to show the
    // country table tracks recent adoptions rather than a frozen snapshot.
    scenarioOutline<({String input, String? canonical})>(
      'Iban.tryParse normalises accepted input and rejects input that fails a check',
      examples: {
        'a valid UK IBAN': (input: 'GB29NWBK60161331926819', canonical: 'GB29NWBK60161331926819'),
        'a valid German IBAN': (
          input: 'DE75512108001245126199',
          canonical: 'DE75512108001245126199',
        ),
        'Oman, mandated 2024/2025': (
          input: 'OM040280000012345678901',
          canonical: 'OM040280000012345678901',
        ),
        'grouped paper form is compacted and upper-cased': (
          input: 'gb29 nwbk 6016 1331 9268 19',
          canonical: 'GB29NWBK60161331926819',
        ),
        'a corrupted final check digit': (input: 'GB29NWBK60161331926818', canonical: null),
        'too short for its country': (input: 'GB29NWBK6016133192681', canonical: null),
        'an unknown country code': (input: 'ZZ00NWBK60161331926819', canonical: null),
        'far too short': (input: 'GB29 NWBK', canonical: null),
        'empty': (input: '', canonical: null),
      },
      outline: (example) {
        // When the input is parsed as an IBAN ...
        final parsedIban = Iban.tryParse(example.input);

        // Then it is normalised to the compact form, or rejected (null).
        check(parsedIban?.value).equals(example.canonical);
      },
    );

    scenario('grouped and compact forms are equal', () {
      check(Iban.tryParse('gb29 nwbk 6016 1331 9268 19')!)
          .equals(Iban.tryParse('GB29NWBK60161331926819')!);
    });

    scenario('an IBAN exposes its country code, check digits, and BBAN', () {
      final parsedIban = Iban.tryParse('GB29NWBK60161331926819')!;

      check(parsedIban.countryCode).equals('GB');
      check(parsedIban.checkDigits).equals((first: Digit.from(2), second: Digit.from(9)));
      check(parsedIban.bban).equals('NWBK60161331926819');
    });

    scenario('an IBAN rebuilds the grouped paper form', () {
      check(Iban.tryParse('GB29NWBK60161331926819')!.formatted)
          .equals('GB29 NWBK 6016 1331 9268 19');
    });

    scenarioOutline<({String input, IbanFailure failure})>(
      'parse reports which check the input failed',
      examples: {
        'empty input cannot identify a country yet': (input: '', failure: const IbanTooShort()),
        'under four characters is still too short': (input: 'GB', failure: const IbanTooShort()),
        'a stray separator is not an IBAN character': (
          input: 'GB29-NWBK60161331926819',
          failure: const IbanInvalidCharacters(),
        ),
        'an unregistered country is unsupported, not mistyped': (
          input: 'ZZ29NWBK60161331926819',
          failure: const IbanUnknownCountry('ZZ'),
        ),
        'a known country fixes the length': (
          input: 'GB29NWBK6016133192681',
          failure: const IbanInvalidLength(expected: 22, actual: 21),
        ),
        'a corrupted final digit fails mod-97': (
          input: 'GB29NWBK60161331926818',
          failure: const IbanChecksumFailed(),
        ),
      },
      outline: (example) => check(Iban.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('the check-digit generator refuses a BBAN with characters outside A-Z and 0-9', () {
      // Our own mod-97-10 generator maps an unknown character to -1 rather than guessing, so the
      // assembled IBAN fails validation instead of getting plausible-looking check digits.
      check(() => Iban.fromComponents(countryCode: 'GB', bban: 'NWBK-6016133192681'))
          .throws<MintedFormatException>()
          .has((error) => error.failure, 'failure')
          .equals(const IbanInvalidCharacters());
    });

    scenario('fromComponents reports the same vocabulary as parse', () {
      check(() => Iban.fromComponents(countryCode: 'GB', bban: 'TOOSHORT'))
          .throws<MintedFormatException>()
          .has((error) => error.failure, 'failure')
          .equals(const IbanInvalidLength(expected: 22, actual: 12));
    });

    scenario('the length failure names the length the country requires', () {
      check(Iban.parse('GB29NWBK6016133192681').reasonOrNull?.message)
          .equals('expected 22 characters for this country, got 21');
    });

    scenario('parse reports the failure rather than throwing', () {
      check(Iban.parse('GB29NWBK60161331926818')).equals(const ParseFailure(IbanChecksumFailed()));
      check(Iban.parse('GB29NWBK60161331926819').isSuccess).isTrue();
    });

    scenario('tryParse still yields a plain null, unchanged by the outcome underneath', () {
      check(Iban.tryParse('GB29NWBK60161331926818')).isNull();
      check(Iban.tryParse('gb29 nwbk 6016 1331 9268 19')?.value).equals('GB29NWBK60161331926819');
    });

    scenario('fromComponents computes the check digits and assembles a valid IBAN', () {
      check(Iban.fromComponents(countryCode: 'GB', bban: 'NWBK60161331926819').value)
          .equals('GB29NWBK60161331926819');
    });

    scenario('fromComponents throws MintedFormatException on a wrong-length BBAN', () {
      check(() => Iban.fromComponents(countryCode: 'GB', bban: 'TOOSHORT'))
          .throws<MintedFormatException>();
    });

    // fromComponents runs our own mod-97-10 generator (check_digits.dart); check
    // it reproduces the registry check digits across countries, letters and
    // digits-only BBANs and different lengths. That is our code, not the
    // validator's.
    scenarioOutline<({String countryCode, String bban, String iban})>(
      'fromComponents computes the check digits to match the registry IBAN',
      examples: {
        'UK, letters in the BBAN': (
          countryCode: 'GB',
          bban: 'NWBK60161331926819',
          iban: 'GB29NWBK60161331926819',
        ),
        'Germany, digits only': (
          countryCode: 'DE',
          bban: '512108001245126199',
          iban: 'DE75512108001245126199',
        ),
        'Oman, 23 characters': (
          countryCode: 'OM',
          bban: '0280000012345678901',
          iban: 'OM040280000012345678901',
        ),
      },
      outline: (example) {
        check(Iban.fromComponents(countryCode: example.countryCode, bban: example.bban).value)
            .equals(example.iban);
      },
    );

    scenario('fromComponents normalises a lower-case, spaced input', () {
      check(Iban.fromComponents(countryCode: 'gb', bban: 'nwbk 6016 1331 9268 19').value)
          .equals('GB29NWBK60161331926819');
    });

    scenario('fromComponents error carries the components as its source', () {
      check(() => Iban.fromComponents(countryCode: 'GB', bban: 'TOOSHORT'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('GB + TOOSHORT');
    });
  });
}
