/// @docImport '../iban.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why an [Iban] refused its input. Sealed rather than an enum, because [IbanUnknownCountry] and [IbanInvalidLength]
/// carry values off the input.
///
/// 5, because ISO 13616 is a registry plus a checksum, and each has its own remedy.
@immutable
sealed class const IbanFailure() implements MintedFailure {
  @override
  String get typeName => 'Iban';
}

/// Under 4 characters, empty included, so the country and check digits aren't there yet.
final class const IbanTooShort() extends IbanFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'too short to identify a country';

  @override
  bool operator ==(Object other) => other is IbanTooShort;

  @override
  int get hashCode => (IbanTooShort).hashCode;

  @override
  String toString() => 'IbanTooShort()';
}

/// Something outside `A`-`Z` and `0`-`9` got through. Whitespace comes off first.
final class const IbanInvalidCharacters() extends IbanFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'contains characters outside A-Z and 0-9';

  @override
  bool operator ==(Object other) => other is IbanInvalidCharacters;

  @override
  int get hashCode => (IbanInvalidCharacters).hashCode;

  @override
  String toString() => 'IbanInvalidCharacters()';
}

/// [countryCode] isn't in the IBAN registry, so this is unsupported rather than mistyped.
final class const IbanUnknownCountry(
  /// The unrecognised leading 2 characters.
  final String countryCode,
) extends IbanFailure {
  /// Creates the failure.
  this;

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
final class const IbanInvalidLength({
  /// The length the registry fixes for this country.
  required final int expected,

  /// The length actually supplied.
  required final int actual,
}) extends IbanFailure {
  /// Creates the failure.
  this;

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

/// The mod-97 check digits don't match the rest. A character is mistyped.
final class const IbanChecksumFailed() extends IbanFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'failed the mod-97 check';

  @override
  bool operator ==(Object other) => other is IbanChecksumFailed;

  @override
  int get hashCode => (IbanChecksumFailed).hashCode;

  @override
  String toString() => 'IbanChecksumFailed()';
}
