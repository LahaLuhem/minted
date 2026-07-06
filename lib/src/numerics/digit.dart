/// @docImport '../contact/phone_number.dart';
/// @docImport '../finance/iban.dart';
/// @docImport 'digits.dart';
library;

import '../shared/minted_format_exception.dart';

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
  static Digit? tryParse(String input) {
    if (input.length != 1) return null;

    final parsedValue = int.tryParse(input);

    return parsedValue == null ? null : tryFrom(parsedValue);
  }

  /// Parses [input] as a single decimal digit, throwing [MintedFormatException]
  /// unless it is exactly one character in `0`-`9`.
  static Digit parse(String input) =>
      tryParse(input) ??
      (throw MintedFormatException.of('Digit', input, 'not a single decimal digit'));

  /// The [Digit] with numeric [value], or `null` unless it is in `0`-`9`.
  static Digit? tryFrom(int value) => value >= 0 && value < _radix ? Digit._(value) : null;

  /// The [Digit] with numeric [value], throwing [MintedFormatException] unless
  /// it is in `0`-`9`.
  static Digit from(int value) =>
      tryFrom(value) ?? (throw MintedFormatException.of('Digit', '$value', 'not a digit in 0-9'));

  static const _radix = 10;
}
