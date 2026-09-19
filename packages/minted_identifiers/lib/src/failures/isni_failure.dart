/// @docImport '../isni.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why an [Isni] refused its input. Sealed rather than an enum, because [IsniWrongLength] carries a
/// number off the input.
@immutable
sealed class IsniFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Isni';
}

/// Not 16 characters once separators come off.
final class IsniWrongLength extends IsniFailure {
  /// How many characters were left after separators came off.
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

/// Something outside `0`-`9` got through. `X` counts only as the last character, where it stands for
/// 10.
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

/// The check character doesn't match the rest. A character is mistyped or swapped.
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
