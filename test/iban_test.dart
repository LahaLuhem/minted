import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:test/test.dart';

void main() {
  // Registry-valid examples, including Oman (mandated 2024/2025) to show the
  // country table tracks recent adoptions rather than a frozen snapshot.
  const validIbans = [
    'GB29NWBK60161331926819',
    'DE75512108001245126199',
    'OM040280000012345678901',
  ];

  group('Iban.tryParse', () {
    for (final valid in validIbans) {
      test('accepts $valid', () {
        check(Iban.tryParse(valid)).isNotNull();
      });
    }

    test('strips spaces and upper-cases to the compact form', () {
      check(Iban.parse('gb29 nwbk 6016 1331 9268 19').value).equals('GB29NWBK60161331926819');
    });

    for (final invalid in const [
      'GB29NWBK60161331926818', // corrupted final digit: mod-97 fails
      'GB29NWBK6016133192681', // too short for GB
      'ZZ00NWBK60161331926819', // unknown country
      'GB29 NWBK', // far too short
      '',
    ]) {
      test('rejects "$invalid"', () {
        check(Iban.tryParse(invalid)).isNull();
      });
    }
  });

  group('Iban equality and normalisation', () {
    test('grouped and compact forms are equal', () {
      check(Iban.parse('gb29 nwbk 6016 1331 9268 19')).equals(Iban.parse('GB29NWBK60161331926819'));
    });
  });

  group('Iban helpers', () {
    final iban = Iban.parse('GB29NWBK60161331926819');

    test('exposes the country code', () {
      check(iban.countryCode).equals('GB');
    });

    test('exposes the check digits', () {
      check(iban.checkDigits).equals('29');
    });

    test('exposes the BBAN', () {
      check(iban.bban).equals('NWBK60161331926819');
    });

    test('rebuilds the grouped paper form', () {
      check(iban.formatted).equals('GB29 NWBK 6016 1331 9268 19');
    });
  });

  group('Iban.parse', () {
    test('throws MintedFormatException on a bad checksum', () {
      check(() => Iban.parse('GB29NWBK60161331926818')).throws<MintedFormatException>();
    });
  });
}
