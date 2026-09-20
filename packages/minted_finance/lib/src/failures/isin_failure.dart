/// @docImport '../isin.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why an [Isin] refused its input. Sealed rather than an enum, because [IsinWrongLength] and [IsinInvalidPrefix]
/// carry values off the input.
@immutable
sealed class const IsinFailure() implements MintedFailure {
  @override
  String get typeName => 'Isin';
}

/// Not 12 characters once whitespace comes off.
final class const IsinWrongLength(
  /// How many characters were left after whitespace came off.
  final int actualLength,
) extends IsinFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'expected 12 characters, got $actualLength';

  @override
  bool operator ==(Object other) => other is IsinWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(IsinWrongLength, actualLength);

  @override
  String toString() => 'IsinWrongLength($actualLength)';
}

/// Something outside `A`-`Z` and `0`-`9` got through.
final class const IsinInvalidCharacters() extends IsinFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'contains characters outside A-Z and 0-9';

  @override
  bool operator ==(Object other) => other is IsinInvalidCharacters;

  @override
  int get hashCode => (IsinInvalidCharacters).hashCode;

  @override
  String toString() => 'IsinInvalidCharacters()';
}

/// The leading 2 characters aren't both letters. ISO 6166 wants letters whether or not they name a
/// country: `XS` is Euroclear and Clearstream, and as valid as `GB`.
final class const IsinInvalidPrefix(
  /// The 2 leading characters, as given.
  final String prefix,
) extends IsinFailure {
  /// Creates the failure.
  this;

  @override
  String get message => '"$prefix" is not two letters';

  @override
  bool operator ==(Object other) => other is IsinInvalidPrefix && other.prefix == prefix;

  @override
  int get hashCode => Object.hash(IsinInvalidPrefix, prefix);

  @override
  String toString() => 'IsinInvalidPrefix($prefix)';
}

/// The check digit doesn't match the rest. A character is mistyped or swapped.
final class const IsinChecksumFailed() extends IsinFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'failed the Luhn check';

  @override
  bool operator ==(Object other) => other is IsinChecksumFailed;

  @override
  int get hashCode => (IsinChecksumFailed).hashCode;

  @override
  String toString() => 'IsinChecksumFailed()';
}
