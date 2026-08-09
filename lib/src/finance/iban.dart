// A validated IBAN is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

import 'dart:math' as math;

import 'package:iban_validator/iban_validator.dart';
import 'package:meta/meta.dart';

import '../numerics/digit.dart';
import '../shared/check_digits.dart';
import '../shared/minted_failure.dart';
import '../shared/minted_format_exception.dart';

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

    final failure = _failureFor(assembled);
    if (failure != null) {
      throw MintedFormatException.from(failure, '$countryCode + $bban');
    }

    return ._(assembled);
  }

  /// Parses [input] as an IBAN, or returns `null` when it fails the structure,
  /// country, length, or mod-97 checks.
  static Iban? tryParse(String input) {
    final normalised = _normalise(input);
    if (_failureFor(normalised) != null) return null;

    return ._(normalised);
  }

  /// Parses [input] as an IBAN, throwing [MintedFormatException] carrying the [IbanFailure] that
  /// says which check failed.
  static Iban parse(String input) {
    final normalised = _normalise(input);

    final failure = _failureFor(normalised);
    if (failure != null) throw MintedFormatException.from(failure, input);

    return ._(normalised);
  }

  /// The ISO 3166-1 alpha-2 country code (the first two characters).
  String get countryCode => value.substring(0, _checkDigitsStart);

  /// The two check digits (positions 3 and 4) as a `(first, second)` record of
  /// [Digit]s; read `.first.value` / `.second.value` for their numeric values.
  ({Digit first, Digit second}) get checkDigits => (
    first: Digit.parse(value[_checkDigitsStart]),
    second: Digit.parse(value[_checkDigitsStart + 1]),
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

  static String _normalise(String input) => input.replaceAll(_whitespace, '').toUpperCase();

  // Why already-normalised input is not an IBAN, or null when it is one. The single gate tryParse,
  // parse, and fromComponents funnel through, so a diagnosis and an acceptance can't disagree.
  static IbanFailure? _failureFor(String normalised) {
    final result = IbanValidator.validate(normalised);
    if (result.isValid) return null;

    return switch (result.error) {
      IbanValidationError.emptyInput || IbanValidationError.tooShort => const IbanTooShort(),
      IbanValidationError.invalidCharacters => const IbanInvalidCharacters(),
      IbanValidationError.unknownCountry => IbanUnknownCountry(
        normalised.substring(0, _checkDigitsStart),
      ),
      // countryInfo is populated whenever the country is known, which invalidLength implies.
      IbanValidationError.invalidLength => IbanInvalidLength(
        expected: result.countryInfo!.ibanLength,
        actual: normalised.length,
      ),
      IbanValidationError.checksumFailed => const IbanChecksumFailed(),
      // countryMismatch needs the countryCca2 argument we never pass, and an invalid result always
      // carries an error. Reaching either means the engine changed shape.
      IbanValidationError.countryMismatch || null => throw StateError('unreachable: no IBAN error'),
    };
  }

  static final _whitespace = RegExp(r'\s+');
  static const _checkDigitsStart = 2;
  static const _bbanStart = 4;
  static const _groupSize = 4;
}

/// Why an [Iban] refused its input. Sealed, not an enum, because [IbanUnknownCountry] and
/// [IbanInvalidLength] report values read from the input.
///
/// Five variants because ISO 13616 is a registry plus a checksum, so it has independent things to
/// fail against, each with its own remedy.
@immutable
sealed class IbanFailure implements MintedFailure {
  const IbanFailure();

  @override
  String get typeName => 'Iban';
}

/// Under four characters, so the country and check digits aren't there to inspect yet. Keep typing.
final class IbanTooShort extends IbanFailure {
  /// The failure for input too short to analyse, empty included.
  const IbanTooShort();

  @override
  String get message => 'too short to identify a country';

  @override
  bool operator ==(Object other) => other is IbanTooShort;

  @override
  int get hashCode => (IbanTooShort).hashCode;

  @override
  String toString() => 'IbanTooShort()';
}

/// Something outside `A`-`Z` and `0`-`9` survived normalisation (whitespace is stripped first).
final class IbanInvalidCharacters extends IbanFailure {
  /// The failure for input holding a character no IBAN may contain.
  const IbanInvalidCharacters();

  @override
  String get message => 'contains characters outside A-Z and 0-9';

  @override
  bool operator ==(Object other) => other is IbanInvalidCharacters;

  @override
  int get hashCode => (IbanInvalidCharacters).hashCode;

  @override
  String toString() => 'IbanInvalidCharacters()';
}

/// [countryCode] is not in the IBAN registry, so this is unsupported rather than mistyped.
final class IbanUnknownCountry extends IbanFailure {
  /// The unrecognised leading two characters.
  final String countryCode;

  /// The failure for a country outside the registry, carrying the code that missed.
  const IbanUnknownCountry(this.countryCode);

  @override
  String get message => '"$countryCode" is not a recognised country code';

  @override
  bool operator ==(Object other) => other is IbanUnknownCountry && other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(IbanUnknownCountry, countryCode);

  @override
  String toString() => 'IbanUnknownCountry($countryCode)';
}

/// The country is known and fixes the length at [expected], but the input is [actual] long.
final class IbanInvalidLength extends IbanFailure {
  /// The length the registry fixes for this country.
  final int expected;

  /// The length actually supplied.
  final int actual;

  /// The failure for a length the country's registry entry rules out.
  const IbanInvalidLength({required this.expected, required this.actual});

  @override
  String get message => 'expected $expected characters for this country, got $actual';

  @override
  bool operator ==(Object other) =>
      other is IbanInvalidLength && other.expected == expected && other.actual == actual;

  @override
  int get hashCode => Object.hash(expected, actual);

  @override
  String toString() => 'IbanInvalidLength(expected: $expected, actual: $actual)';
}

/// The mod-97 check digits disagree with the rest of the number: a character is mistyped.
final class IbanChecksumFailed extends IbanFailure {
  /// The failure for a structurally sound IBAN whose check digits don't match.
  const IbanChecksumFailed();

  @override
  String get message => 'failed the mod-97 check';

  @override
  bool operator ==(Object other) => other is IbanChecksumFailed;

  @override
  int get hashCode => (IbanChecksumFailed).hashCode;

  @override
  String toString() => 'IbanChecksumFailed()';
}
