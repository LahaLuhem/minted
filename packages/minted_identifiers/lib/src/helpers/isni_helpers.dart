// A validated ISNI is ASCII digits, plus at most a trailing X.
// ignore_for_file: avoid-substring

part of '../isni.dart';

// The one gate parse and fromBody both go through. Widest check first, so the earliest wrong thing
// gets named.
IsniFailure? _failureFor(String compactInput) => switch (compactInput) {
  _ when compactInput.length != _length => IsniWrongLength(compactInput.length),
  _ when !_isniForm.hasMatch(compactInput) => const IsniInvalidCharacters(),
  _ when !_checksumHolds(compactInput) => const IsniChecksumFailed(),
  _ => null,
};

bool _checksumHolds(String compactInput) => compactInput.endsWith(
  doublingMod11CheckCharacter(compactInput.substring(0, _checkCharacterIndex)),
);

final _isniForm = RegExp(r'^\d{15}[\dX]$');

const _length = 16;
const _groupSize = 4;
const _checkCharacterIndex = 15;
// ORCID's block as published: 0000-0001-5000-0000 through 0000-0003-5000-0001.
const _orcidBlockStart = '0000000150000000';
const _orcidBlockEnd = '0000000350000001';
