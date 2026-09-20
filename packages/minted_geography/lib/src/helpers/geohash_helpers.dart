part of '../geohash.dart';

// The one gate parse goes through.
GeohashFailure? _failureFor(String normalisedInput) {
  if (normalisedInput.isEmpty) return const GeohashEmpty();

  final offendingCharacter = _nonAlphabetCharacter.firstMatch(normalisedInput)?.group(0);

  return offendingCharacter == null ? null : GeohashInvalidCharacter(offendingCharacter);
}

// The cell [geohashValue] narrows to. Only ever reached from a parsed value, so indexOf can't answer
// -1.
List<({double low, double high})> _cellOf(String geohashValue) {
  final intervals = _wholeEarth();
  var bit = 0;

  for (final codeUnit in geohashValue.codeUnits) {
    final characterValue = _alphabetCodeUnits.indexOf(codeUnit);

    for (var mask = _highestCharacterBit; mask > 0; mask >>= 1) {
      final axis = bit % _axisCount;
      final interval = intervals[axis];
      final middle = _middleOf(interval);

      intervals[axis] = characterValue & mask == 0
          ? (low: interval.low, high: middle)
          : (low: middle, high: interval.high);
      bit++;
    }
  }

  return intervals;
}

// Both axes at full extent, longitude first because it takes the 1st bit. Fresh per call: the walk
// narrows it in place.
List<({double low, double high})> _wholeEarth() => [
  (low: -maxLongitude, high: maxLongitude),
  (low: -maxLatitude, high: maxLatitude),
];

// Exact in binary: every bound is ±90 or ±180 times a dyadic rational, so halving never rounds.
double _middleOf(({double low, double high}) interval) => (interval.low + interval.high) / 2;

// The 36 alphanumerics less the 4 letters that read as digits, leaving 32. ASCII-ascending on purpose,
// which is what makes string order spatial order.
const _alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';

final _alphabetCodeUnits = _alphabet.codeUnits;
final _nonAlphabetCharacter = RegExp('[^$_alphabet]');

const _bitsPerCharacter = 5;
const _highestCharacterBit = 1 << (_bitsPerCharacter - 1);

// Longitude takes the 1st bit and the 2 alternate, so a bit index's parity picks its axis.
const _axisCount = 2;
const _longitudeAxis = 0;
const _latitudeAxis = 1;
