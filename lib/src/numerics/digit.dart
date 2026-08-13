/// @docImport '../contact/phone_number.dart';
/// @docImport '../finance/iban.dart';
/// @docImport 'digits.dart';
library;

import '../shared/outcomes/minted_format_exception.dart';
import '../shared/outcomes/parse_outcome.dart';
import 'failures/digit_failure.dart';

/// A single decimal digit, `0`-`9`.
///
/// A building-block value type. Where a validated whole exposes a digit-only
/// part, that part is a [Digit] (or a [Digits] sequence) so "these are digits"
/// is a fact of the type, not an assumption every caller re-checks: an [Iban]'s
/// check digits and a [PhoneNumber]'s national number both read as [Digit]s.
///
/// [value] is the numeric value (`0`-`9`); the string form is `value.toString()`
/// or interpolation (`'$digit'`).
extension type const Digit._(int value) {
  /// Parses [input] as a single decimal digit, or returns `null` unless it is
  /// exactly one character in `0`-`9`.
  @Deprecated('Decode the text yourself, then use Digit.tryFrom. Removed in 2.0.0 (#44).')
  static Digit? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a single decimal digit, reporting [DigitFailure] unless
  /// it is exactly one character in `0`-`9`.
  @Deprecated('Decode the text yourself, then use Digit.tryFrom. Removed in 2.0.0 (#44).')
  static ParseOutcome<DigitFailure, Digit> parse(String input) {
    final parsedValue = input.length != 1 ? null : int.tryParse(input);
    final parsedDigit = parsedValue == null ? null : tryFrom(parsedValue);

    return parsedDigit == null
        ? const ParseFailure(DigitFailure.notADigit)
        : ParseSuccess(parsedDigit);
  }

  /// The [Digit] with numeric [value], or `null` unless it is in `0`-`9`.
  static Digit? tryFrom(int value) => value >= 0 && value < _radix ? ._(value) : null;

  /// The [Digit] with numeric [value], throwing [MintedFormatException] unless
  /// it is in `0`-`9`.
  @Deprecated('Use Digit.tryFrom. Removed in 2.0.0 (#44).')
  static Digit from(int value) =>
      tryFrom(value) ?? (throw MintedFormatException.from(DigitFailure.notADigit, '$value'));

  static const _radix = 10;
}
