/// @docImport '../geohash.dart';
library;

import 'package:meta/meta.dart';
import 'package:minted/minted.dart';

/// Why a [Geohash] refused its input. Sealed, not an enum, so the character variant reports the
/// offender back. Two remedies: supply a geohash, or fix a character.
@immutable
sealed class GeohashFailure implements MintedFailure {
  const new();

  @override
  String get typeName => 'Geohash';
}

/// The input held no geohash: empty, or nothing but whitespace.
final class GeohashEmpty extends GeohashFailure {
  /// Creates the failure.
  const new();

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
final class GeohashInvalidCharacter extends GeohashFailure {
  /// The first offending character.
  final String character;

  /// Creates the failure.
  const new(this.character);

  @override
  String get message => "'$character' is not a geohash character";

  @override
  bool operator ==(Object other) =>
      other is GeohashInvalidCharacter && other.character == character;

  @override
  int get hashCode => Object.hash(GeohashInvalidCharacter, character);

  @override
  String toString() => 'GeohashInvalidCharacter($character)';
}
