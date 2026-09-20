// A validated ISBN is ASCII digits, plus at most a trailing X before normalisation.
// ignore_for_file: avoid-substring

part of '../isbn.dart';

String _withCheckDigit(String twelveDigits) => '$twelveDigits${gs1CheckDigit(twelveDigits)}';

// 13 digits already stays put. Otherwise prefix 978 and redo the check digit, since the 2
// generations use different maths.
String _toIsbn13(String compactInput) => compactInput.length == _length13
    ? compactInput
    : _withCheckDigit('$bookland978${compactInput.substring(0, _isbn10BodyLength)}');

// The one gate parse and fromComponents both go through. Widest check first, so the earliest wrong
// thing gets named.
IsbnFailure? _failureFor(String compactInput) => switch (compactInput) {
  _ when compactInput.length != _length10 && compactInput.length != _length13 => IsbnWrongLength(
    compactInput.length,
  ),
  _ when !_charsetHolds(compactInput) => const IsbnInvalidCharacters(),
  _ when compactInput.length == _length13 && !_prefixHolds(compactInput) => IsbnInvalidPrefix(
    _offendingPrefix(compactInput),
  ),
  _ when !_checksumHolds(compactInput) => const IsbnChecksumFailed(),
  _ => null,
};

// Only reached once the length is 10 or 13. X is legal only as the 10-digit check.
bool _charsetHolds(String compactInput) => compactInput.length == _length10
    ? _tenDigitForm.hasMatch(compactInput)
    : _thirteenDigitForm.hasMatch(compactInput);

bool _prefixHolds(String compactInput) =>
    booklandPrefixes.contains(compactInput.substring(0, _prefixLength)) &&
    !compactInput.startsWith(ismnRange);

String _offendingPrefix(String compactInput) =>
    compactInput.startsWith(ismnRange) ? ismnRange : compactInput.substring(0, _prefixLength);

bool _checksumHolds(String compactInput) => compactInput.length == _length13
    ? compactInput.endsWith(gs1CheckDigit(compactInput.substring(0, _checkDigitIndex)))
    : compactInput.endsWith(mod11CheckCharacter(compactInput.substring(0, _isbn10BodyLength)));

final _tenDigitForm = RegExp(r'^\d{9}[\dX]$');
final _thirteenDigitForm = RegExp(r'^\d{13}$');

const _length10 = 10;
const _length13 = 13;
const _prefixLength = 3;
const _checkDigitIndex = 12;
const _isbn10BodyLength = 9;
