// A validated IBAN is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

import 'dart:math' as math;

import 'package:iban_validator/iban_validator.dart';

import '../numerics/digit.dart';
import '../shared/check_digits/iban_check_digits.dart';
import '../shared/normalisation/normalisation.dart';
import '../shared/outcomes/minted_format_exception.dart';
import '../shared/outcomes/parse_outcome.dart';
import 'failures/iban_failure.dart';

/// An IBAN: validated for structure, country-specific length, and the mod-97 checksum (via `iban_validator`).
/// Standard: [ISO 13616](https://en.wikipedia.org/wiki/International_Bank_Account_Number).
///
/// Normalisation on parse: whitespace stripped and upper-cased, so [value] is the compact electronic form
/// and [formatted] rebuilds the grouped paper form.
/// Country coverage tracks `iban_validator`; see the README caveat.
///
/// {@example /example/minted_example.dart#iban}
extension type const Iban._(String value) {
  /// Builds an [Iban] from its [countryCode] (ISO 3166-1 alpha-2) and [bban], computing the mod-97 check digits.
  /// Throws [MintedFormatException] when the parts don't form a valid IBAN (unknown country,
  /// wrong BBAN length or charset). For assembling from a known-valid source.
  static Iban fromComponents({required String countryCode, required String bban}) {
    final upperCountry = countryCode.toUpperCase();
    final compactBban = unspacedUpperCase(bban);
    final assembledIban = '$upperCountry${ibanCheckDigits(upperCountry, compactBban)}$compactBban';
    final failure = _failureFor(assembledIban);

    return failure != null
        ? throw MintedFormatException.from(failure, '$countryCode + $bban')
        : ._(assembledIban);
  }

  /// Parses [input] as an IBAN, or returns `null` when it fails the structure,
  /// country, length, or mod-97 checks.
  static Iban? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an IBAN, reporting the [IbanFailure] that says which check failed.
  static ParseOutcome<IbanFailure, Iban> parse(String input) {
    final normalised = unspacedUpperCase(input);
    final failure = _failureFor(normalised);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalised));
  }

  /// The ISO 3166-1 alpha-2 country code (the first two characters).
  String get countryCode => value.substring(0, _checkDigitsStart);

  /// The two check digits (positions 3 and 4) as a `(first, second)` record of
  /// [Digit]s; read `.first.value` / `.second.value` for their numeric values.
  // Both positions are digits in a validated IBAN, so tryParse cannot return null here.
  ({Digit first, Digit second}) get checkDigits => (
    first: .tryParse(value[_checkDigitsStart])!,
    second: .tryParse(value[_checkDigitsStart + 1])!,
  );

  /// The Basic Bank Account Number: everything after the check digits (the bank-specific part,
  /// e.g. an account number plus a bank or branch code).
  String get bban => value.substring(_bbanStart);

  /// The IBAN in grouped "paper" form: space-separated blocks of four, for display.
  /// The stored [value] stays compact.
  String get formatted => Iterable.generate(
    (value.length / _groupSize).ceil(),
    (group) =>
        value.substring(group * _groupSize, math.min((group + 1) * _groupSize, value.length)),
  ).join(' ');

  // Why already-normalised input is not an IBAN, or null when it is one. The single gate tryParse,
  // parse, and fromComponents funnel through, so a diagnosis and an acceptance can't disagree.
  static IbanFailure? _failureFor(String normalised) {
    final validationResult = IbanValidator.validate(normalised);
    if (validationResult.isValid) return null;

    return switch (validationResult.error) {
      .emptyInput || .tooShort => const IbanTooShort(),
      .invalidCharacters => const IbanInvalidCharacters(),
      .unknownCountry => IbanUnknownCountry(normalised.substring(0, _checkDigitsStart)),
      // countryInfo is populated whenever the country is known, which invalidLength implies.
      .invalidLength => IbanInvalidLength(
        expected: validationResult.countryInfo!.ibanLength,
        actual: normalised.length,
      ),
      .checksumFailed => const IbanChecksumFailed(),
      // countryMismatch needs the countryCca2 argument we never pass, and an invalid result always
      // carries an error. Reaching either means the engine changed shape, so no test can get here.
      // coverage:ignore-start
      .countryMismatch || null => throw StateError('unreachable: no IBAN error'),
      // coverage:ignore-end
    };
  }

  static const _checkDigitsStart = 2;
  static const _bbanStart = 4;
  static const _groupSize = 4;
}
