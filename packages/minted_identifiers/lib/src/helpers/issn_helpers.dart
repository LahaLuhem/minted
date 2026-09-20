// A validated ISSN is ASCII digits, plus at most a trailing X.
// ignore_for_file: avoid-substring

part of '../issn.dart';

String _hyphenated(String compactInput) =>
    '${compactInput.substring(0, _groupSize)}$hyphen${compactInput.substring(_groupSize)}';

// The one gate parse and fromBody both go through. Widest check first, so the earliest wrong thing
// gets named.
IssnFailure? _failureFor(String compactInput) => switch (compactInput) {
  _ when compactInput.length != _length => IssnWrongLength(compactInput.length),
  _ when !_issnForm.hasMatch(compactInput) => const IssnInvalidCharacters(),
  _ when !_checksumHolds(compactInput) => const IssnChecksumFailed(),
  _ => null,
};

bool _checksumHolds(String compactInput) =>
    compactInput.endsWith(mod11CheckCharacter(compactInput.substring(0, _bodyLength)));

final _issnForm = RegExp(r'^\d{7}[\dX]$');

const _length = 8;
const _bodyLength = 7;
const _groupSize = 4;
const _checkCharacterIndex = 8; // past the hyphen, so one further than in the compact form
