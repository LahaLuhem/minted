/// @docImport '../gtin.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [Gtin] refused its input. Sealed, not an enum, because [GtinWrongLength] reports a value
/// read from the input.
///
/// Three variants: GS1 gives a GTIN a digit charset, four permitted lengths, and a check digit.
@immutable
sealed class GtinFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Gtin';
}

/// The digit count is none of the four GS1 lengths, so this is not a GTIN of any form.
final class GtinWrongLength extends GtinFailure {
  /// How many digits were left once separators were stripped.
  final int actualLength;

  /// Creates the failure.
  const new(this.actualLength);

  @override
  String get message => 'expected 8, 12, 13 or 14 digits, got $actualLength';

  @override
  bool operator ==(Object other) => other is GtinWrongLength && other.actualLength == actualLength;

  @override
  int get hashCode => Object.hash(GtinWrongLength, actualLength);

  @override
  String toString() => 'GtinWrongLength($actualLength)';
}

/// Something outside `0`-`9` survived normalisation (spaces and hyphens are stripped first).
final class GtinInvalidCharacters extends GtinFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'contains characters outside 0-9';

  @override
  bool operator ==(Object other) => other is GtinInvalidCharacters;

  @override
  int get hashCode => (GtinInvalidCharacters).hashCode;

  @override
  String toString() => 'GtinInvalidCharacters()';
}

/// The check digit disagrees with the rest of the number: a digit is mistyped or transposed.
final class GtinChecksumFailed extends GtinFailure {
  /// Creates the failure.
  const new();

  @override
  String get message => 'failed the GS1 mod-10 check';

  @override
  bool operator ==(Object other) => other is GtinChecksumFailed;

  @override
  int get hashCode => (GtinChecksumFailed).hashCode;

  @override
  String toString() => 'GtinChecksumFailed()';
}
