part of '../plus_code.dart';

const _digitsBeforeSeparator = 8;
const _separator = '+';
const _padding = '0';

// Upper case is what the standard writes, so it doubles as the canonical form.
String _normalised(String input) => input.trim().toUpperCase();

PlusCode _encode(GeoCoordinate coordinate, int digits) =>
    PlusCode._(olc.PlusCode.encode(_latLng(coordinate), codeLength: digits).toString());

olc.LatLng _latLng(GeoCoordinate coordinate) =>
    olc.LatLng(coordinate.latitude, coordinate.longitude);

// The engine's isFull and isShort say yes to codes the standard refuses, so only isValid is asked.
// Why: `APPENDIX.md#plus-code-value-type`.
PlusCodeFailure? _fullFailureFor(String candidate) => switch (candidate) {
  _ when !olc.PlusCode.unverified(candidate).isValid => const PlusCodeMalformed(),
  _ when _isShort(candidate) => PlusCodeNotFull(candidate),
  _ => null,
};

PlusCodeFailure? _shortFailureFor(String candidate) => switch (candidate) {
  _ when !olc.PlusCode.unverified(candidate).isValid => const PlusCodeMalformed(),
  _ when !_isShort(candidate) => PlusCodeNotShort(candidate),
  _ => null,
};

// Only sound for a code isValid has already accepted.
bool _isShort(String candidate) => candidate.indexOf(_separator) < _digitsBeforeSeparator;

// Padding stands in for digits rather than being one, so it never counts.
int _significantDigits(String code) {
  final [head, tail] = code.split(_separator);

  return head.replaceAll(RegExp('$_padding+\$'), '').length + tail.length;
}
