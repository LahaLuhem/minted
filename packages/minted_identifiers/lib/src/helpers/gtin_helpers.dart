// A validated GTIN is ASCII digits only.
// ignore_for_file: avoid-substring

part of '../gtin.dart';

String _withCheckDigit(String bodyDigits) => '$bodyDigits${gs1CheckDigit(bodyDigits)}';

// GS1's own rule for keeping every length in one field. Safe because the weights run from the right,
// so the added zeros change nothing.
String _toGtin14(String compactInput) => compactInput.padLeft(_length14, zeroPad);

// The one gate parse and fromBody both go through. Widest check first, so the earliest wrong thing
// gets named.
GtinFailure? _failureFor(String compactInput) => switch (compactInput) {
  _ when !_lengths.contains(compactInput.length) => GtinWrongLength(compactInput.length),
  _ when !digitsOnly.hasMatch(compactInput) => const GtinInvalidCharacters(),
  _ when !_checksumHolds(compactInput) => const GtinChecksumFailed(),
  _ => null,
};

bool _checksumHolds(String compactInput) =>
    compactInput.endsWith(gs1CheckDigit(compactInput.substring(0, compactInput.length - 1)));

final _nonZeroDigit = RegExp('[^$zeroPad]');

// GS1 defines no other lengths.
const _length8 = 8;
const _length12 = 12;
const _length13 = 13;
const _length14 = 14;
const _lengths = {_length8, _length12, _length13, _length14};
const _checkDigitIndex = 13;
