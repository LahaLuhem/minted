/// @docImport '../geohash.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [Geohash] refused its input. Sealed rather than an enum, so the character variant hands the
/// offender back.
@immutable
sealed class const GeohashFailure() implements MintedFailure {
  @override
  String get typeName => 'Geohash';
}

/// The input held no geohash: empty, or nothing but whitespace.
final class const GeohashEmpty() extends GeohashFailure {
  /// Creates the failure.
  this;

  @override
  String get message => 'an empty string is not a geohash';

  @override
  bool operator ==(Object other) => other is GeohashEmpty;

  @override
  int get hashCode => (GeohashEmpty).hashCode;

  @override
  String toString() => 'GeohashEmpty()';
}

/// A character outside the geohash alphabet, which omits `a`, `i`, `l` and `o`.
final class const GeohashInvalidCharacter(
  /// The first offending character.
  final String character,
) extends GeohashFailure {
  /// Creates the failure.
  this;

  @override
  String get message => '"$character" is not a geohash character';

  @override
  bool operator ==(Object other) =>
      other is GeohashInvalidCharacter && other.character == character;

  @override
  int get hashCode => Object.hash(GeohashInvalidCharacter, character);

  @override
  String toString() => 'GeohashInvalidCharacter($character)';
}
