// A validated IBAN is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

import 'dart:math' as math;

import 'package:iban_validator/iban_validator.dart';
import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'check_digits/iban_check_digits.dart';
import 'failures/iban_failure.dart';

/// An IBAN (International Bank Account Number).
/// Standard: [ISO 13616](https://en.wikipedia.org/wiki/International_Bank_Account_Number).
///
/// Parsing strips whitespace and upper-cases, so [value] is the compact electronic form and [formatted]
/// rebuilds the grouped paper one. Country coverage tracks `iban_validator`, and the README carries
/// the caveat.
///
/// {@example /example/minted_finance_example.dart#iban}
extension type const Iban._(String value) {
  /// Builds an [Iban] from its [countryCode] (ISO 3166-1 alpha-2) and [bban], working the mod-97 check
  /// digits out.
  static ParseOutcome<IbanFailure, Iban> fromComponents({
    required AsciiLetters countryCode,
    required AsciiAlphanumerics bban,
  }) {
    // The parts cannot carry whitespace, so only case folds here.
    final upperCountry = countryCode.value.toUpperCase();
    final compactBban = bban.value.toUpperCase();
    final assembledIban = '$upperCountry${ibanCheckDigits(upperCountry, compactBban)}$compactBban';
    final failure = _failureFor(assembledIban);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(assembledIban));
  }

  /// Parses [input], or `null` if it isn't an IBAN.
  static Iban? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [IbanFailure] that says what went wrong.
  static ParseOutcome<IbanFailure, Iban> parse(String input) {
    final normalised = unspacedUpperCase(input);
    final failure = _failureFor(normalised);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(normalised));
  }

  /// The ISO 3166-1 alpha-2 country code (the first 2 characters).
  // Alpha-2 codes are letters, and parse refuses an unknown country.
  AsciiLetters get countryCode => .tryFrom(value.substring(0, _checkDigitsStart))!;

  /// The 2 check digits, positions 3 and 4.
  // Both positions are digits in a validated IBAN, so tryParse cannot return null here.
  ({Digit first, Digit second}) get checkDigits => (
    first: .tryFrom(decimalValue(value.codeUnitAt(_checkDigitsStart)))!,
    second: .tryFrom(decimalValue(value.codeUnitAt(_checkDigitsStart + 1)))!,
  );

  /// The Basic Bank Account Number: the bank-specific part after the check digits, usually an account
  /// number plus a bank or branch code.
  // A validated IBAN is `[A-Z0-9]` throughout, so no slice can be refused.
  AsciiAlphanumerics get bban => .tryFrom(value.substring(_bbanStart))!;

  /// The grouped paper form, blocks of 4, for display. [value] stays compact.
  String get formatted => Iterable.generate(
    (value.length / _groupSize).ceil(),
    (group) =>
        value.substring(group * _groupSize, math.min((group + 1) * _groupSize, value.length)),
  ).join(' ');

  // The one gate parse and fromComponents both go through, so a diagnosis and an acceptance can't disagree.
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
      // carries an error. Reaching either means the engine changed shape, so no test reaches here.
      // coverage:ignore-start
      .countryMismatch || null => throw StateError('unreachable: no IBAN error'),
      // coverage:ignore-end
    };
  }

  static const _checkDigitsStart = 2;
  static const _bbanStart = 4;
  static const _groupSize = 4;
}
