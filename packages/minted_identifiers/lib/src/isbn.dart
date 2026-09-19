// A validated ISBN is ASCII digits, plus at most a trailing X before normalisation.
// ignore_for_file: avoid-substring

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'check_digits/gs1_check_digit.dart';
import 'check_digits/mod11_check_character.dart';
import 'failures/isbn_failure.dart';
import 'standards/isbn_prefixes.dart';

/// An ISBN (International Standard Book Number).
/// Standard: [ISO 2108](https://www.isbn-international.org/content/what-isbn).
///
/// Parsing strips spaces and hyphens, upper-cases a trailing `x`, and folds the 10-digit form into
/// the 13-digit one, so both spellings of a book compare equal. [isbn10] rebuilds the old form.
///
/// No hyphens in [value]: the group boundaries come from ISBN International's range table, not from
/// the digits.
///
/// {@example /example/minted_identifiers_example.dart#isbn}
extension type const Isbn._(String value) {
  /// Builds an [Isbn] from its GS1 [prefix] (`978` or `979`) and 9-digit [body], working the check
  /// digit out.
  static ParseOutcome<IsbnFailure, Isbn> fromComponents({
    required Digits prefix,
    required Digits body,
  }) {
    final assembledIsbn = _withCheckDigit('${prefix.asString}${body.asString}');
    final failure = _failureFor(assembledIsbn);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(assembledIsbn));
  }

  /// Parses [input], or `null` if it isn't an ISBN. Either generation is fine.
  static Isbn? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [IsbnFailure] that says what went wrong.
  static ParseOutcome<IsbnFailure, Isbn> parse(String input) {
    final compactInput = compactUpperCase(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(_toIsbn13(compactInput)));
  }

  /// The 3-digit GS1 prefix, `978` or `979`.
  // A validated ISBN is all digits, so none of these 3 tryFroms can return null.
  Digits get prefix => .tryFrom(decimalValues(value, 0, _prefixLength))!;

  /// The 9 digits between the prefix and the check digit: group, registrant and publication, run
  /// together. Splitting them needs a range table this package doesn't carry.
  Digits get body => .tryFrom(decimalValues(value, _prefixLength, _checkDigitIndex))!;

  /// The last digit, the GS1 mod-10 check over the other 12.
  Digit get checkDigit => .tryFrom(decimalValue(value.codeUnitAt(_checkDigitIndex)))!;

  /// The old 10-character form, whose check digit can be `X`. `null` for a `979` ISBN, which never
  /// had one.
  String? get isbn10 {
    if (prefix.asString != bookland978) return null;

    final bodyText = body.asString;

    return '$bodyText${mod11CheckCharacter(bodyText)}';
  }

  static String _withCheckDigit(String twelveDigits) =>
      '$twelveDigits${gs1CheckDigit(twelveDigits)}';

  // 13 digits already stays put. Otherwise prefix 978 and redo the check digit, since the 2
  // generations use different maths.
  static String _toIsbn13(String compactInput) => compactInput.length == _length13
      ? compactInput
      : _withCheckDigit('$bookland978${compactInput.substring(0, _isbn10BodyLength)}');

  // The one gate parse and fromComponents both go through. Widest check first, so the earliest wrong
  // thing gets named.
  static IsbnFailure? _failureFor(String compactInput) => switch (compactInput) {
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
  static bool _charsetHolds(String compactInput) => compactInput.length == _length10
      ? _tenDigitForm.hasMatch(compactInput)
      : _thirteenDigitForm.hasMatch(compactInput);

  static bool _prefixHolds(String compactInput) =>
      booklandPrefixes.contains(compactInput.substring(0, _prefixLength)) &&
      !compactInput.startsWith(ismnRange);

  static String _offendingPrefix(String compactInput) =>
      compactInput.startsWith(ismnRange) ? ismnRange : compactInput.substring(0, _prefixLength);

  static bool _checksumHolds(String compactInput) => compactInput.length == _length13
      ? compactInput.endsWith(gs1CheckDigit(compactInput.substring(0, _checkDigitIndex)))
      : compactInput.endsWith(mod11CheckCharacter(compactInput.substring(0, _isbn10BodyLength)));

  static final _tenDigitForm = RegExp(r'^\d{9}[\dX]$');
  static final _thirteenDigitForm = RegExp(r'^\d{13}$');

  static const _length10 = 10;
  static const _length13 = 13;
  static const _prefixLength = 3;
  static const _checkDigitIndex = 12;
  static const _isbn10BodyLength = 9;
}
