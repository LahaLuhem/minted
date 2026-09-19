/// @docImport '../isbn.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

import '../standards/isbn_prefixes.dart';

/// Why an [Isbn] refused its input. Sealed rather than an enum, because [IsbnWrongLength] and [IsbnInvalidPrefix]
/// carry values off the input.
@immutable
sealed class IsbnFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Isbn';
}

/// Neither 10 nor 13 characters, so it's neither generation.
final class IsbnWrongLength extends IsbnFailure {
  /// How many characters were left after separators came off.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected 10 or 13 digits, got $actualLength';

  @override
  bool operator ==(Object other) => other is IsbnWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(IsbnWrongLength, actualLength);

  @override
  String toString() => 'IsbnWrongLength($actualLength)';
}

/// Something outside `0`-`9` got through. `X` counts only as the 10-digit form's last character, where
/// it stands for 10.
final class IsbnInvalidCharacters extends IsbnFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains characters outside 0-9 (X only as the ISBN-10 check digit)';

  @override
  bool operator ==(Object other) => other is IsbnInvalidCharacters;

  @override
  int get hashCode => (IsbnInvalidCharacters).hashCode;

  @override
  String toString() => 'IsbnInvalidCharacters()';
}

/// 13 digits, but [prefix] isn't a range ISO 2108 gives to books. Some other GS1 article number
/// in the same shape.
final class IsbnInvalidPrefix extends IsbnFailure {
  /// The leading digits naming the range: 3 for a GS1 prefix, or `9790`, which needs a 4th to
  /// tell apart.
  final String prefix;

  /// Creates the failure.
  const new(this.prefix);

  @override
  String get message => prefix == ismnRange
      ? '"$prefix" is the ISMN range for printed music, not an ISBN'
      : '"$prefix" is not an ISBN prefix (expected 978 or 979)';

  @override
  bool operator ==(Object other) => other is IsbnInvalidPrefix && other.prefix == prefix;

  @override
  int get hashCode => Object.hash(IsbnInvalidPrefix, prefix);

  @override
  String toString() => 'IsbnInvalidPrefix($prefix)';
}

/// The check digit doesn't match the rest. A character is mistyped or swapped.
final class IsbnChecksumFailed extends IsbnFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'failed the check-digit test';

  @override
  bool operator ==(Object other) => other is IsbnChecksumFailed;

  @override
  int get hashCode => (IsbnChecksumFailed).hashCode;

  @override
  String toString() => 'IsbnChecksumFailed()';
}
