// A validated IBAN is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

part of '../iban.dart';

/// The one gate parse and fromComponents both go through, so a diagnosis and an acceptance can't disagree.
IbanFailure? _failureFor(String normalised) {
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

const _checkDigitsStart = 2;
const _bbanStart = 4;
const _groupSize = 4;
