/// @docImport '../issn.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why an [Issn] refused its input. Sealed, not an enum, because [IssnWrongLength] reports a value
/// read from the input.
///
/// Three variants: ISO 3297 gives an ISSN a charset, one length, and a check character.
@immutable
sealed class IssnFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Issn';
}

/// Not eight characters once the hyphen and any spaces are stripped, so this is not an ISSN.
final class IssnWrongLength extends IssnFailure {
  /// How many characters were left once separators were stripped.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected 8 characters, got $actualLength';

  @override
  bool operator ==(Object other) => other is IssnWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(IssnWrongLength, actualLength);

  @override
  String toString() => 'IssnWrongLength($actualLength)';
}

/// Something outside `0`-`9` survived normalisation (the hyphen and spaces are stripped first). `X`
/// counts only as the final character, where it stands for the value ten.
final class IssnInvalidCharacters extends IssnFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains characters outside 0-9 (X only as the check character)';

  @override
  bool operator ==(Object other) => other is IssnInvalidCharacters;

  @override
  int get hashCode => (IssnInvalidCharacters).hashCode;

  @override
  String toString() => 'IssnInvalidCharacters()';
}

/// The check character disagrees with the rest of the number: a character is mistyped or transposed.
final class IssnChecksumFailed extends IssnFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'failed the mod-11 check';

  @override
  bool operator ==(Object other) => other is IssnChecksumFailed;

  @override
  int get hashCode => (IssnChecksumFailed).hashCode;

  @override
  String toString() => 'IssnChecksumFailed()';
}
