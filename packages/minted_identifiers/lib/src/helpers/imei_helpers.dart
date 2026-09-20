// A validated IMEI is ASCII digits only.
// ignore_for_file: avoid-substring

part of '../imei.dart';

String _withCheckDigit(String bodyDigits) => '$bodyDigits${luhnCheckDigit(bodyDigits)}';

// The one gate parse and fromComponents both go through. Widest check first, so the earliest wrong
// thing gets named.
ImeiFailure? _failureFor(String compactInput) => switch (compactInput) {
  _ when compactInput.length != _length => ImeiWrongLength(compactInput.length),
  _ when !digitsOnly.hasMatch(compactInput) => const ImeiInvalidCharacters(),
  _ when !_checksumHolds(compactInput) => const ImeiChecksumFailed(),
  _ => null,
};

bool _checksumHolds(String compactInput) =>
    compactInput.endsWith(luhnCheckDigit(compactInput.substring(0, _checkDigitIndex)));

const _length = 15;
// The 2004 revision folded the Final Assembly Code into the TAC, so there's nothing left to expose
// between the TAC and the serial.
const _tacLength = 8;
const _reportingBodyLength = 2;
const _checkDigitIndex = 14;
