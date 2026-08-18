import 'package:checks/checks.dart';
import 'package:minted/minted.dart';
import 'package:minted_geography/minted_geography.dart';

import 'support/bdd.dart';

// NaturalNumber declares only tryFrom, so every call site would otherwise carry the bang.
Geohash _geohash({required GeoCoordinate coordinate, required int precision}) =>
    Geohash.from(coordinate: coordinate, precision: NaturalNumber.tryFrom(precision)!);

void main() {
  final eiffelTower = GeoCoordinate.from(latitude: 48.8577, longitude: 2.295).getOrThrow();

  feature('Geohash', () {
    // Acceptance and normalisation in one table: the canonical form doubles as the expected outcome.
    // A String means "accepted and normalised to this"; null means "rejected".
    scenarioOutline<({String input, String? canonical})>(
      'tryParse takes the alphabet, at any length, in either case',
      examples: {
        'a five-character published vector': (input: 'ezs42', canonical: 'ezs42'),
        'an eleven-character published vector': (input: 'u4pruydqqvj', canonical: 'u4pruydqqvj'),
        'upper case folds to the alphabet own case': (input: 'EZS42', canonical: 'ezs42'),
        'surrounding whitespace is trimmed': (input: '  ezs42\n', canonical: 'ezs42'),
        'one character is a legal cell, a wide one': (input: 's', canonical: 's'),
        // No cap: nothing readable in the standard fixes one, and this decodes exactly.
        'thirteen characters, past what tooling emits': (
          input: 'ezs42e44yx967',
          canonical: 'ezs42e44yx967',
        ),
        // The four base32 dropped, one row each, because a shape-only check accepts them all.
        'the letter a': (input: 'ezsa2', canonical: null),
        'the letter i': (input: 'ezsi2', canonical: null),
        'the letter l': (input: 'ezsl2', canonical: null),
        'the letter o': (input: 'ezso2', canonical: null),
        'punctuation': (input: 'ezs-42', canonical: null),
        'inner whitespace is not cosmetic grouping': (input: 'ezs 42', canonical: null),
        'an empty string': (input: '', canonical: null),
        'whitespace only': (input: '   ', canonical: null),
      },
      outline: (example) {
        check(Geohash.tryParse(example.input)?.value).equals(example.canonical);
      },
    );

    // Two remedies from one door: supply a geohash, or fix a character.
    scenarioOutline<({String input, GeohashFailure failure})>(
      'parse names the character that broke it, not just the shape',
      examples: {
        'an empty string has no character to name': (input: '', failure: const GeohashEmpty()),
        'whitespace trims down to empty': (input: ' \t ', failure: const GeohashEmpty()),
        'a letter base32 dropped': (input: 'ezsa2', failure: const GeohashInvalidCharacter('a')),
        'the first offender is the one reported': (
          input: 'ezsai2',
          failure: const GeohashInvalidCharacter('a'),
        ),
        'punctuation': (input: 'ezs-42', failure: const GeohashInvalidCharacter('-')),
      },
      outline: (example) =>
          check(Geohash.parse(example.input).reasonOrNull).equals(example.failure),
    );

    scenario('from encodes the published vectors', () {
      check(
        _geohash(
          coordinate: GeoCoordinate.from(latitude: 42.6, longitude: -5.6).getOrThrow(),
          precision: 5,
        ).value,
      ).equals('ezs42');
      check(
        _geohash(
          coordinate: GeoCoordinate.from(latitude: 57.64911, longitude: 10.40744).getOrThrow(),
          precision: 11,
        ).value,
      ).equals('u4pruydqqvj');
    });

    // What routing from through parse would have proven, since it builds the string itself.
    scenario('every from output parses back to itself', () {
      for (final precision in [1, 2, 5, 8, 12, 20]) {
        final encoded = _geohash(coordinate: eiffelTower, precision: precision);

        check(encoded.precision).equals(precision);
        check(Geohash.tryParse(encoded.value)).equals(encoded);
      }
    });

    scenario('a coarser geohash is a prefix of a finer one for the same point', () {
      check(_geohash(coordinate: eiffelTower, precision: 5).value).equals('u09tu');
      check(_geohash(coordinate: eiffelTower, precision: 9).value.startsWith('u09tu')).isTrue();
    });

    // The headline claim: a geohash is a cell, so the round trip through one point is not identity.
    scenario('the centre is a point in the cell, not the point encoded', () {
      final cell = _geohash(coordinate: eiffelTower, precision: 5);

      check(cell.centre == eiffelTower).isFalse();
      check(cell.centre.iso6709).equals('+48.84521484375+002.30712890625/');
      check(_geohash(coordinate: cell.centre, precision: 5)).equals(cell);
    });

    scenario('the north-east corner of the grid is all z', () {
      check(
        _geohash(
          coordinate: GeoCoordinate.from(latitude: 90, longitude: 180).getOrThrow(),
          precision: 6,
        ).value,
      ).equals('zzzzzz');
    });

    // GeoCoordinate folds -180 onto +180, so the south-west corner cannot be handed to from at all.
    // The all-zero cell is reachable only by parsing, and its centre sits just inside it.
    scenario('the west spelling of the antimeridian arrives already folded', () {
      check(
        _geohash(
          coordinate: GeoCoordinate.from(latitude: -90, longitude: -180).getOrThrow(),
          precision: 6,
        ).value,
      ).equals('pbpbpb');
      check(Geohash.tryParse('000000')!.centre.iso6709)
          .equals('-89.99725341796875-179.9945068359375/');
    });

    // The alphabet is ASCII-ascending on purpose, so a database can range-query on the text.
    scenario('plain string order is spatial order', () {
      final sorted = ['ezs42', 'ezs41', 'u4pruy', '0', 'zzz', 'ezt']..sort();

      check(sorted).deepEquals(['0', 'ezs41', 'ezs42', 'ezt', 'u4pruy', 'zzz']);
    });

    scenario('equal geohashes are equal by value, case and padding folded away', () {
      check(Geohash.tryParse('EZS42 ')).equals(Geohash.tryParse('ezs42'));
      check(Geohash.tryParse('EZS42 ').hashCode).equals(Geohash.tryParse('ezs42').hashCode);
    });

    scenario('a caller who asserts the string gets the throw back through getOrThrow', () {
      check(() => Geohash.parse('ezsa2').getOrThrow())
          .throws<MintedFormatError>()
          .has((error) => error.failure, 'failure')
          .equals(const GeohashInvalidCharacter('a'));
    });
  });
}
