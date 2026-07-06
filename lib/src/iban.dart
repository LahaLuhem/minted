// A validated IBAN is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

import 'dart:math' as math;

import 'package:iban_validator/iban_validator.dart';

import 'shared/check_digits.dart';
import 'shared/minted_format_exception.dart';

/// An IBAN: validated for structure, country-specific length, and the mod-97 checksum (via `iban_validator`).
/// Standard: [ISO 13616](https://en.wikipedia.org/wiki/International_Bank_Account_Number).
///
/// Normalisation on parse: whitespace stripped and upper-cased, so [value] is the compact electronic form
/// and [formatted] rebuilds the grouped paper form.
/// Country coverage tracks `iban_validator`; see the README caveat.
extension type const Iban._(String value) {
  /// Builds an [Iban] from its [countryCode] (ISO 3166-1 alpha-2) and [bban], computing the mod-97 check digits.
  /// Throws [MintedFormatException] when the parts don't form a valid IBAN (unknown country,
  /// wrong BBAN length or charset). For assembling from a known-valid source.
  static Iban fromComponents({required String countryCode, required String bban}) {
    final upperCountry = countryCode.toUpperCase();
    final compactBban = bban.replaceAll(_whitespace, '').toUpperCase();
    final assembled = '$upperCountry${ibanCheckDigits(upperCountry, compactBban)}$compactBban';

    return tryParse(assembled) ??
        (throw MintedFormatException.of(
          'Iban',
          '$countryCode + $bban',
          'those components do not form a valid IBAN',
        ));
  }

  /// Parses [input] as an IBAN, or returns `null` when it fails the structure,
  /// country, length, or mod-97 checks.
  static Iban? tryParse(String input) {
    final normalised = input.replaceAll(_whitespace, '').toUpperCase();
    if (!IbanValidator.isValid(normalised)) return null;

    return Iban._(normalised);
  }

  /// Parses [input] as an IBAN, throwing [MintedFormatException] when it fails any check.
  static Iban parse(String input) =>
      tryParse(input) ??
      (throw MintedFormatException.of('Iban', input, 'failed IBAN structure or mod-97 check'));

  /// The ISO 3166-1 alpha-2 country code (the first two characters).
  String get countryCode => value.substring(0, _checkDigitsStart);

  /// The two check digits (the third and fourth characters).
  String get checkDigits => value.substring(_checkDigitsStart, _bbanStart);

  /// The Basic Bank Account Number: everything after the check digits (the bank-specific part,
  /// e.g. an account number plus a bank or branch code).
  String get bban => value.substring(_bbanStart);

  /// The IBAN in grouped "paper" form: space-separated blocks of four, for display.
  /// The stored [value] stays compact.
  String get formatted => [
    for (var offset = 0; offset < value.length; offset += _groupSize)
      value.substring(offset, math.min(offset + _groupSize, value.length)),
  ].join(' ');

  static final _whitespace = RegExp(r'\s+');
  static const _checkDigitsStart = 2;
  static const _bbanStart = 4;
  static const _groupSize = 4;
}
