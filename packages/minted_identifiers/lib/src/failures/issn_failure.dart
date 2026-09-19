/// @docImport '../issn.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why an [Issn] refused its input. Sealed rather than an enum, because [IssnWrongLength] carries a
/// number off the input.
@immutable
sealed class IssnFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Issn';
}

/// Not 8 characters once the hyphen and any spaces come off.
final class IssnWrongLength extends IssnFailure {
  /// How many characters were left after separators came off.
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

/// Something outside `0`-`9` got through. `X` counts only as the last character, where it stands for
/// 10.
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

/// The check character doesn't match the rest. A character is mistyped or swapped.
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
