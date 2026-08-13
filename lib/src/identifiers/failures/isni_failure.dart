/// @docImport '../isni.dart';
library;

import 'package:meta/meta.dart';

import '../../shared/outcomes/minted_failure.dart';

/// Why an [Isni] refused its input. Sealed, not an enum, because [IsniWrongLength] reports a value
/// read from the input.
///
/// Three variants: ISO 27729 fixes a length, a charset, and a check character.
@immutable
sealed class IsniFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Isni';
}

/// Not sixteen characters once separators are stripped, so this is not an ISNI.
final class IsniWrongLength extends IsniFailure {
  /// How many characters were left once separators were stripped.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected 16 characters, got $actualLength';

  @override
  bool operator ==(Object other) => other is IsniWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(IsniWrongLength, actualLength);

  @override
  String toString() => 'IsniWrongLength($actualLength)';
}

/// Something outside `0`-`9` survived normalisation. `X` counts only as the final character, where
/// it stands for the value ten.
final class IsniInvalidCharacters extends IsniFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains characters outside 0-9 (X only as the check character)';

  @override
  bool operator ==(Object other) => other is IsniInvalidCharacters;

  @override
  int get hashCode => (IsniInvalidCharacters).hashCode;

  @override
  String toString() => 'IsniInvalidCharacters()';
}

/// The check character disagrees with the rest: a character is mistyped or transposed.
final class IsniChecksumFailed extends IsniFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'failed the ISO 7064 MOD 11-2 check';

  @override
  bool operator ==(Object other) => other is IsniChecksumFailed;

  @override
  int get hashCode => (IsniChecksumFailed).hashCode;

  @override
  String toString() => 'IsniChecksumFailed()';
}
