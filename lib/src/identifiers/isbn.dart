// A validated ISBN is ASCII digits, plus at most a trailing X before normalisation.
// ignore_for_file: avoid-substring

import '../numerics/digit.dart';
import '../shared/check_digits/isbn_check_digits.dart';
import '../shared/minted_format_exception.dart';
import '../shared/parse_outcome.dart';
import 'failures/isbn_failure.dart';

/// An ISBN (International Standard Book Number): validated for length, prefix, and the ISO 2108
/// check digit, mod-11 over the ten-digit form and GS1 mod-10 over the thirteen-digit one.
/// Standard: [ISO 2108](https://www.isbn-international.org/content/what-isbn).
///
/// Normalisation on parse: spaces and hyphens are stripped, a trailing `x` is upper-cased, and the
/// ten-digit form is folded into its thirteen-digit equivalent, so [value] is always thirteen
/// digits and the two spellings of one book compare equal. [isbn10] rebuilds the legacy form.
///
/// Not hyphenated: the group boundaries come from ISBN International's range table, not the digits.
extension type const Isbn._(String value) {
  /// Builds an [Isbn] from its GS1 [prefix] (`978` or `979`) and nine-digit [body], computing the
  /// check digit. Throws [MintedFormatException] when the parts don't form a valid ISBN. For
  /// assembling from a known-valid source.
  static Isbn fromComponents({required String prefix, required String body}) {
    final assembledIsbn = _withCheckDigit(_compact('$prefix$body'));
    final failure = _failureFor(assembledIsbn);

    return failure != null
        ? throw MintedFormatException.from(failure, '$prefix + $body')
        : ._(assembledIsbn);
  }

  /// Parses [input] as an ISBN, or returns `null` when it fails the length, character, prefix, or
  /// check-digit tests. Both generations are accepted; the result is always thirteen digits.
  static Isbn? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an ISBN, reporting the [IsbnFailure] that says which check failed.
  static ParseOutcome<IsbnFailure, Isbn> parse(String input) {
    final compactInput = _compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(_toIsbn13(compactInput)));
  }

  /// The three-digit GS1 prefix, `978` or `979`.
  String get prefix => value.substring(0, _prefixLength);

  /// The nine digits between the prefix and the check digit: registration group, registrant and
  /// publication, run together. Splitting them needs a range table this package does not carry.
  String get body => value.substring(_prefixLength, _checkDigitIndex);

  /// The final digit, the GS1 mod-10 check over the other twelve.
  // The last character of a validated ISBN-13 is always a digit, so tryParse cannot return null.
  Digit get checkDigit => .tryParse(value[_checkDigitIndex])!;

  /// The legacy ten-character form (mod-11 check digit, `X` for ten), or `null` for a `979` ISBN,
  /// which never had one.
  String? get isbn10 => prefix != _bookland978 ? null : '$body${isbn10CheckDigit(body)}';

  static String _compact(String input) => input.replaceAll(_separators, '').toUpperCase();

  static String _withCheckDigit(String twelveDigits) =>
      '$twelveDigits${isbn13CheckDigit(twelveDigits)}';

  // Itself when already thirteen digits, otherwise the 978-prefixed equivalent, whose check digit
  // is recomputed because the two generations use different algorithms.
  static String _toIsbn13(String compactInput) => compactInput.length == _length13
      ? compactInput
      : _withCheckDigit('$_bookland978${compactInput.substring(0, _isbn10BodyLength)}');

  // Why already-compacted input is not an ISBN, or null when it is one. The single gate parse and
  // fromComponents funnel through; widest check first, so the earliest wrong thing is named.
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

  // Only reached once the length is known to be 10 or 13; X is legal only as the ten-digit check.
  static bool _charsetHolds(String compactInput) => compactInput.length == _length10
      ? _tenDigitForm.hasMatch(compactInput)
      : _thirteenDigitForm.hasMatch(compactInput);

  static bool _prefixHolds(String compactInput) =>
      _booklandPrefixes.contains(compactInput.substring(0, _prefixLength)) &&
      !compactInput.startsWith(_ismnRange);

  static String _offendingPrefix(String compactInput) =>
      compactInput.startsWith(_ismnRange) ? _ismnRange : compactInput.substring(0, _prefixLength);

  static bool _checksumHolds(String compactInput) => compactInput.length == _length13
      ? compactInput.endsWith(isbn13CheckDigit(compactInput.substring(0, _checkDigitIndex)))
      : compactInput.endsWith(isbn10CheckDigit(compactInput.substring(0, _isbn10BodyLength)));

  static final _separators = RegExp(r'[\s-]+');
  static final _tenDigitForm = RegExp(r'^\d{9}[\dX]$');
  static final _thirteenDigitForm = RegExp(r'^\d{13}$');

  static const _length10 = 10;
  static const _length13 = 13;
  static const _prefixLength = 3;
  static const _checkDigitIndex = 12;
  static const _isbn10BodyLength = 9;
  // GS1's "Bookland" prefixes: the article-number range standing in for a country.
  static const _bookland978 = '978';
  static const _bookland979 = '979';
  static const _booklandPrefixes = {_bookland978, _bookland979};
  // ISO 10957 holds 979-0 for the ISMN, so printed music is carved out of the 979 range.
  static const _ismnRange = '9790';
}
