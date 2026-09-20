// A validated ISIN is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'encoding/alphanumeric_values.dart';
import 'failures/isin_failure.dart';
import 'standards/iso_country_code.dart';

part 'constants/isin_constants.dart';
part 'helpers/isin_helpers.dart';

/// An ISIN (International Securities Identification Number).
/// Standard: [ISO 6166](https://www.iso.org/standard/78502.html).
///
/// Parsing strips whitespace and upper-cases the letters.
///
/// The check digit is Luhn, but over the number with every letter first replaced by the 2 digits of
/// its value (`A`=10 … `Z`=35), so an ISIN with letters in its [nsin] weighs more characters than it
/// shows.
///
/// [prefix] need not name a country: `XS` is Euroclear and Clearstream, `EU` is supranational, and both
/// are as valid as `GB`. [hasCountryPrefix] reports the narrower fact.
///
/// Named values: [IsinConstants].
///
/// {@example /example/minted_finance_example.dart#isin}
extension type const Isin._(String value) {
  /// Builds an [Isin] from its 2-letter [prefix] and 9-character [nsin], working the check digit
  /// out.
  static ParseOutcome<IsinFailure, Isin> fromComponents({
    required AsciiLetters prefix,
    required AsciiAlphanumerics nsin,
  }) {
    // The parts cannot carry whitespace, so only case folds here.
    final assembledIsin = _withCheckDigit('${prefix.value}${nsin.value}'.toUpperCase());
    final failure = _failureFor(assembledIsin);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(assembledIsin));
  }

  /// Parses [input], or `null` if it isn't an ISIN.
  static Isin? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [IsinFailure] that says what went wrong.
  static ParseOutcome<IsinFailure, Isin> parse(String input) {
    final compactInput = unspacedUpperCase(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(compactInput));
  }

  /// The 2 leading letters: the numbering agency's country, or `XS` / `EU` where none applies.
  // parse refuses anything but 2 letters here.
  AsciiLetters get prefix => .tryFrom(value.substring(0, _prefixLength))!;

  /// Whether [prefix] names a real ISO 3166-1 country. `false` for `XS` and `EU`, which are valid ISINs
  /// all the same.
  bool get hasCountryPrefix => isIsoCountryCode(prefix.value);

  /// The 9-character National Securities Identifying Number, which for a US or Canadian security
  /// is its CUSIP.
  // A validated ISIN is `[A-Z0-9]` throughout, so no slice can be refused.
  AsciiAlphanumerics get nsin => .tryFrom(value.substring(_prefixLength, _checkDigitIndex))!;

  /// The last digit, the Luhn check over the expanded number.
  // A validated ISIN ends in a digit, so tryFrom cannot return null.
  Digit get checkDigit => .tryFrom(decimalValue(value.codeUnitAt(_checkDigitIndex)))!;

  // ISO 6166 defines no test ISIN, so an all-zero NSIN is the nearest thing.
}
