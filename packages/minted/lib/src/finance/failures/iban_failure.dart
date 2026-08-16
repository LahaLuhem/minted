/// @docImport '../iban.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/outcomes/minted_failure.dart';

/// Why an [Iban] refused its input. Sealed, not an enum, because [IbanUnknownCountry] and
/// [IbanInvalidLength] report values read from the input.
///
/// Five variants because ISO 13616 is a registry plus a checksum, so it has independent things to
/// fail against, each with its own remedy.
@immutable
sealed class IbanFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Iban';
}

/// Under four characters (empty included), so the country and check digits aren't there to inspect
/// yet. Keep typing.
final class IbanTooShort extends IbanFailure {
  /// Creates the failure.
  const new();

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
  /// Creates the failure.
  const new();

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

  /// Creates the failure.
  const new(this.countryCode);

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

  /// Creates the failure.
  const new({required this.expected, required this.actual});

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
  /// Creates the failure.
  const new();

  @override
  String get message => 'failed the mod-97 check';

  @override
  bool operator ==(Object other) => other is IbanChecksumFailed;

  @override
  int get hashCode => (IbanChecksumFailed).hashCode;

  @override
  String toString() => 'IbanChecksumFailed()';
}
