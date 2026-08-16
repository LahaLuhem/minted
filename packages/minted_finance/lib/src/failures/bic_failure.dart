/// @docImport '../bic.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [Bic] refused its input. Sealed, not an enum, because [BicWrongLength] and [BicUnknownCountry]
/// report values read from the input.
///
/// Three variants where IBAN has five: ISO 9362 has no checksum and no per-country length, so there
/// are only the shape and the country registry to fail against.
@immutable
sealed class BicFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Bic';
}

/// Neither eight nor eleven characters survived normalisation, so this is a BIC of neither length.
final class BicWrongLength extends BicFailure {
  /// How many characters were left once whitespace was stripped.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected 8 or 11 characters, got $actualLength';

  @override
  bool operator ==(Object other) => other is BicWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(BicWrongLength, actualLength);

  @override
  String toString() => 'BicWrongLength($actualLength)';
}

/// Something outside `A`-`Z` and `0`-`9` survived normalisation (whitespace is stripped first).
final class BicInvalidCharacters extends BicFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains characters outside A-Z and 0-9';

  @override
  bool operator ==(Object other) => other is BicInvalidCharacters;

  @override
  int get hashCode => (BicInvalidCharacters).hashCode;

  @override
  String toString() => 'BicInvalidCharacters()';
}

/// [countryCode] is not an ISO 3166-1 alpha-2 code, so positions 5 and 6 are mistyped. Digits
/// landing there arrive here too, since they cannot name a country either.
final class BicUnknownCountry extends BicFailure {
  /// The unrecognised fifth and sixth characters.
  final String countryCode;

  /// Creates the failure.
  const new(this.countryCode);

  @override
  String get message => '"$countryCode" is not a recognised country code';

  @override
  bool operator ==(Object other) => other is BicUnknownCountry && other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(BicUnknownCountry, countryCode);

  @override
  String toString() => 'BicUnknownCountry($countryCode)';
}
