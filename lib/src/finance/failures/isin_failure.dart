/// @docImport '../isin.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/minted_failure.dart';

/// Why an [Isin] refused its input. Sealed, not an enum, because [IsinWrongLength] and [IsinInvalidPrefix]
/// report values read from the input.
///
/// Four variants: ISO 6166 fixes a length, a charset, a two-letter prefix, and a check digit.
@immutable
sealed class IsinFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Isin';
}

/// Not twelve characters once whitespace is stripped, so this is not an ISIN.
final class IsinWrongLength extends IsinFailure {
  /// How many characters were left once whitespace was stripped.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected 12 characters, got $actualLength';

  @override
  bool operator ==(Object other) => other is IsinWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(IsinWrongLength, actualLength);

  @override
  String toString() => 'IsinWrongLength($actualLength)';
}

/// Something outside `A`-`Z` and `0`-`9` survived normalisation.
final class IsinInvalidCharacters extends IsinFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains characters outside A-Z and 0-9';

  @override
  bool operator ==(Object other) => other is IsinInvalidCharacters;

  @override
  int get hashCode => (IsinInvalidCharacters).hashCode;

  @override
  String toString() => 'IsinInvalidCharacters()';
}

/// The leading two characters are not both letters. ISO 6166 requires them, whether or not they name
/// a country: `XS` is Euroclear and Clearstream, and is as valid as `GB`.
final class IsinInvalidPrefix extends IsinFailure {
  /// The two leading characters, as given.
  final String prefix;

  /// Creates the failure.
  const new(this.prefix);

  @override
  String get message => '"$prefix" is not two letters';

  @override
  bool operator ==(Object other) => other is IsinInvalidPrefix && other.prefix == prefix;

  @override
  int get hashCode => Object.hash(IsinInvalidPrefix, prefix);

  @override
  String toString() => 'IsinInvalidPrefix($prefix)';
}

/// The check digit disagrees with the rest: a character is mistyped or transposed.
final class IsinChecksumFailed extends IsinFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'failed the Luhn check';

  @override
  bool operator ==(Object other) => other is IsinChecksumFailed;

  @override
  int get hashCode => (IsinChecksumFailed).hashCode;

  @override
  String toString() => 'IsinChecksumFailed()';
}
