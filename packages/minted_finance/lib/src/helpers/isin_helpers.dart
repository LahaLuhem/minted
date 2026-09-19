// A validated ISIN is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

part of '../isin.dart';

String _withCheckDigit(String body) => '$body${luhnCheckDigit(expandedAlphanumerics(body))}';

// The one gate parse and fromComponents both go through. Widest check first, so the earliest wrong
// thing gets named.
IsinFailure? _failureFor(String compactInput) => switch (compactInput) {
  _ when compactInput.length != _length => IsinWrongLength(compactInput.length),
  _ when !_isinForm.hasMatch(compactInput) => const IsinInvalidCharacters(),
  _ when !_prefixForm.hasMatch(compactInput) => IsinInvalidPrefix(
    compactInput.substring(0, _prefixLength),
  ),
  _ when !_checksumHolds(compactInput) => const IsinChecksumFailed(),
  _ => null,
};

bool _checksumHolds(String compactInput) => compactInput.endsWith(
  luhnCheckDigit(expandedAlphanumerics(compactInput.substring(0, _checkDigitIndex))),
);

final _isinForm = RegExp(r'^[A-Z0-9]+$');
final _prefixForm = RegExp('^[A-Z]{$_prefixLength}');

const _length = 12;
const _prefixLength = 2;
const _checkDigitIndex = 11;
