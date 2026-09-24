part of '../plus_code.dart';

// The 8 digits a code carries before the separator, and the most that padding can replace.
const _paddedDigitCount = 8;
const _separator = '+';
const _padding = '0';

// Upper case is the case the standard writes codes in, so it doubles as the canonical form.
String _normalised(String input) => input.trim().toUpperCase();

PlusCode _encode(GeoCoordinate coordinate, int digits) =>
    PlusCode._(olc.PlusCode.encode(_latLng(coordinate), codeLength: digits).toString());

olc.LatLng _latLng(GeoCoordinate coordinate) =>
    olc.LatLng(coordinate.latitude, coordinate.longitude);

// isValid is the only predicate of the engine's worth trusting: isFull and isShort skip the validity
// check and answer true for codes the standard refuses. Why: `APPENDIX.md#plus-code-value-type`.
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

// A full code carries all 8 leading digits, so anything with fewer before the separator is short.
// Only reached for a code isValid has already accepted.
bool _isShort(String candidate) => candidate.indexOf(_separator) < _paddedDigitCount;

// Padding stands in for digits rather than carrying one, so it never counts towards precision.
int _significantDigits(String code) {
  final [head, tail] = code.split(_separator);

  return head.replaceAll(RegExp('$_padding+\$'), '').length + tail.length;
}
