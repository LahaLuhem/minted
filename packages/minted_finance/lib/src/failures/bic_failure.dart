/// @docImport '../bic.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [Bic] refused its input. Sealed rather than an enum, because [BicWrongLength] and [BicUnknownCountry]
/// carry values off the input.
///
/// 2 fewer than IBAN needs: ISO 9362 has no checksum and no per-country length.
@immutable
sealed class BicFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Bic';
}

/// Neither 8 nor 11 characters, so it's a BIC of neither length.
final class BicWrongLength extends BicFailure {
  /// How many characters were left after whitespace came off.
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

/// Something outside `A`-`Z` and `0`-`9` got through. Whitespace comes off first.
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

/// [countryCode] is no ISO 3166-1 alpha-2 code, so positions 5 and 6 are mistyped. Digits landing there
/// arrive here too, naming no country either.
final class BicUnknownCountry extends BicFailure {
  /// The unrecognised 5th and 6th characters.
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
