/// @docImport 'digits.dart';
library;

/// A single decimal digit, `0`-`9`.
///
/// A building-block value type. Where a validated whole exposes a digit-only
/// part, that part is a [Digit] (or a [Digits] sequence) so "these are digits"
/// is a fact of the type, not an assumption every caller re-checks: an IBAN's
/// check digits and a phone number's national number both read as [Digit]s,
/// over in `minted_finance` and `minted_contact`.
///
/// [value] is the numeric value (`0`-`9`); the string form is `value.toString()`
/// or interpolation (`'$digit'`). No parse door: decimal notation is how numbers
/// are written, not a published format a `Digit` could validate against.
extension type const Digit._(int value) implements int {
  /// The [Digit] with numeric [value], or `null` unless it is in `0`-`9`.
  static Digit? tryFrom(int value) => value >= 0 && value < _radix ? ._(value) : null;

  static const _radix = 10;
}
