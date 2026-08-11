// A validated ISIN is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

import '../numerics/digit.dart';
import '../shared/alphanumeric_values.dart';
import '../shared/check_digits/luhn_check_digit.dart';
import '../shared/iso_country_code.dart';
import '../shared/minted_format_exception.dart';
import '../shared/normalisation.dart';
import '../shared/parse_outcome.dart';
import 'failures/isin_failure.dart';

/// An ISIN (International Securities Identification Number): validated for the twelve-character
/// length, the `A-Z0-9` charset, a two-letter prefix, and the ISO 6166 check digit.
/// Standard: [ISO 6166](https://www.iso.org/standard/78502.html).
///
/// Normalisation on parse: whitespace is stripped and letters are upper-cased.
///
/// The check digit is Luhn, but over the number with every letter first replaced by the two digits
/// of its value (`A`=10 … `Z`=35), so an ISIN with letters in its [nsin] weighs more characters
/// than it shows.
///
/// [prefix] is not required to name a country: `XS` is Euroclear and Clearstream, `EU` is
/// supranational, and both are as valid as `GB`. [hasCountryPrefix] reports the narrower fact
/// instead of `parse` refusing what the standard allows.
extension type const Isin._(String value) {
  /// Builds an [Isin] from its two-letter [prefix] and nine-character [nsin], computing the check
  /// digit. Throws [MintedFormatException] when the parts don't form a valid ISIN.
  // Both parts are alphanumeric, so they stay `String` where a digits-only part would be `Digits`.
  static Isin fromComponents({required String prefix, required String nsin}) {
    final assembledIsin = _withCheckDigit(_compact('$prefix$nsin'));
    final failure = _failureFor(assembledIsin);

    return failure != null
        ? throw MintedFormatException.from(failure, '$prefix + $nsin')
        : ._(assembledIsin);
  }

  /// Parses [input] as an ISIN, or returns `null` when it fails the length, character, prefix, or
  /// check-digit tests.
  static Isin? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an ISIN, reporting the [IsinFailure] that says which check failed.
  static ParseOutcome<IsinFailure, Isin> parse(String input) {
    final compactInput = _compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(compactInput));
  }

  /// The two leading letters: the numbering agency's country, or `XS` / `EU` where none applies.
  String get prefix => value.substring(0, _prefixLength);

  /// Whether [prefix] names a real ISO 3166-1 country. `false` for `XS` and `EU`, which are valid
  /// ISINs all the same.
  bool get hasCountryPrefix => isoCountryCodeFor(prefix) != null;

  /// The nine-character National Securities Identifying Number, which for a US or Canadian security
  /// is its CUSIP.
  String get nsin => value.substring(_prefixLength, _checkDigitIndex);

  /// The final digit, the Luhn check over the expanded number.
  // The last character of a validated ISIN is always a digit, so tryParse cannot return null.
  Digit get checkDigit => .tryParse(value[_checkDigitIndex])!;

  static String _compact(String input) => input.replaceAll(whitespace, '').toUpperCase();

  static String _withCheckDigit(String body) =>
      '$body${luhnCheckDigit(expandedAlphanumerics(body))}';

  // Why already-compacted input is not an ISIN, or null when it is one. The single gate parse and
  // fromComponents funnel through; widest check first, so the earliest wrong thing is named.
  static IsinFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when compactInput.length != _length => IsinWrongLength(compactInput.length),
    _ when !_isinForm.hasMatch(compactInput) => const IsinInvalidCharacters(),
    _ when !_prefixForm.hasMatch(compactInput) => IsinInvalidPrefix(
      compactInput.substring(0, _prefixLength),
    ),
    _ when !_checksumHolds(compactInput) => const IsinChecksumFailed(),
    _ => null,
  };

  static bool _checksumHolds(String compactInput) => compactInput.endsWith(
    luhnCheckDigit(expandedAlphanumerics(compactInput.substring(0, _checkDigitIndex))),
  );

  static final _isinForm = RegExp(r'^[A-Z0-9]+$');
  static final _prefixForm = RegExp('^[A-Z]{$_prefixLength}');

  static const _length = 12;
  static const _prefixLength = 2;
  static const _checkDigitIndex = 11;
}
