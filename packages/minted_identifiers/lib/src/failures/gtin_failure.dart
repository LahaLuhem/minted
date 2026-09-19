/// @docImport '../gtin.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [Gtin] refused its input. Sealed rather than an enum, because [GtinWrongLength] carries a number
/// off the input.
@immutable
sealed class GtinFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Gtin';
}

/// The digit count is none of GS1's 4 lengths.
final class GtinWrongLength extends GtinFailure {
  /// How many digits were left after separators came off.
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

/// Something outside `0`-`9` got through. Spaces and hyphens come off first.
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

/// The check digit doesn't match the rest. A digit is mistyped or swapped.
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
