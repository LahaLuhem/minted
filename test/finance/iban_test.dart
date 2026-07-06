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
      check(Iban.parse('gb29 nwbk 6016 1331 9268 19')).equals(Iban.parse('GB29NWBK60161331926819'));
    });

    scenario('an IBAN exposes its country code, check digits, and BBAN', () {
      final parsedIban = Iban.parse('GB29NWBK60161331926819');

      check(parsedIban.countryCode).equals('GB');
      check(parsedIban.checkDigits).equals((first: Digit.from(2), second: Digit.from(9)));
      check(parsedIban.bban).equals('NWBK60161331926819');
    });

    scenario('an IBAN rebuilds the grouped paper form', () {
      check(Iban.parse('GB29NWBK60161331926819').formatted).equals('GB29 NWBK 6016 1331 9268 19');
    });

    scenario('Iban.parse throws MintedFormatException on a bad checksum', () {
      check(() => Iban.parse('GB29NWBK60161331926818')).throws<MintedFormatException>();
    });

    scenario('fromComponents computes the check digits and assembles a valid IBAN', () {
      check(
        Iban.fromComponents(countryCode: 'GB', bban: 'NWBK60161331926819').value,
      ).equals('GB29NWBK60161331926819');
    });

    scenario('fromComponents throws MintedFormatException on a wrong-length BBAN', () {
      check(
        () => Iban.fromComponents(countryCode: 'GB', bban: 'TOOSHORT'),
      ).throws<MintedFormatException>();
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
        check(
          Iban.fromComponents(countryCode: example.countryCode, bban: example.bban).value,
        ).equals(example.iban);
      },
    );

    scenario('fromComponents normalises a lower-case, spaced input', () {
      check(
        Iban.fromComponents(countryCode: 'gb', bban: 'nwbk 6016 1331 9268 19').value,
      ).equals('GB29NWBK60161331926819');
    });

    scenario('fromComponents error carries the components as its source', () {
      check(() => Iban.fromComponents(countryCode: 'GB', bban: 'TOOSHORT'))
          .throws<MintedFormatException>()
          .has((error) => error.source as String?, 'source')
          .equals('GB + TOOSHORT');
    });
  });
}
