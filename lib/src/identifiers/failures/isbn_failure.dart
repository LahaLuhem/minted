/// @docImport '../isbn.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/isbn_prefixes.dart';
import '../../shared/minted_failure.dart';

/// Why an [Isbn] refused its input. Sealed, not an enum, because [IsbnWrongLength] and [IsbnInvalidPrefix]
/// report values read from the input.
///
/// Four variants because ISO 2108 is a prefix range plus a check digit, so it has independent things
/// to fail against, each with its own remedy.
@immutable
sealed class IsbnFailure implements MintedFailure {
  const IsbnFailure();

  @override
  String get typeName => 'Isbn';
}

/// Neither ten nor thirteen characters survived normalisation, so this is not an ISBN of either generation.
/// Count again, or keep typing.
final class IsbnWrongLength extends IsbnFailure {
  /// How many characters were left once separators were stripped.
  final int actualLength;

  /// Creates the failure.
  const IsbnWrongLength(this.actualLength);

  @override
  String get message => 'expected 10 or 13 digits, got $actualLength';

  @override
  bool operator ==(Object other) => other is IsbnWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(IsbnWrongLength, actualLength);

  @override
  String toString() => 'IsbnWrongLength($actualLength)';
}

/// Something outside `0`-`9` survived normalisation (spaces and hyphens are stripped first). `X` counts
/// only as the last character of the ten-digit form, where it stands for the value ten.
final class IsbnInvalidCharacters extends IsbnFailure {
  /// Creates the failure.
  const IsbnInvalidCharacters();

  @override
  String get message => 'contains characters outside 0-9 (X only as the ISBN-10 check digit)';

  @override
  bool operator ==(Object other) => other is IsbnInvalidCharacters;

  @override
  int get hashCode => (IsbnInvalidCharacters).hashCode;

  @override
  String toString() => 'IsbnInvalidCharacters()';
}

/// Thirteen digits, but [prefix] is not a range ISO 2108 gives to books: this is some other GS1 article
/// number wearing the same shape.
final class IsbnInvalidPrefix extends IsbnFailure {
  /// The leading digits that identify the range: three for a GS1 prefix, or `9790`, the one range
  /// that needs a fourth digit to tell apart.
  final String prefix;

  /// Creates the failure.
  const IsbnInvalidPrefix(this.prefix);

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

/// The check digit disagrees with the rest of the number: a character is mistyped or transposed.
final class IsbnChecksumFailed extends IsbnFailure {
  /// Creates the failure.
  const IsbnChecksumFailed();

  @override
  String get message => 'failed the check-digit test';

  @override
  bool operator ==(Object other) => other is IsbnChecksumFailed;

  @override
  int get hashCode => (IsbnChecksumFailed).hashCode;

  @override
  String toString() => 'IsbnChecksumFailed()';
}
