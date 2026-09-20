/// @docImport 'digits.dart';
library;

part '../constants/digit_constants.dart';

/// A single decimal digit, `0`-`9`.
///
/// Where a validated whole exposes a digit-only part, that part is a [Digit] (or a [Digits] sequence),
/// so "these are digits" is a fact of the type rather than something every caller re-checks.
///
/// Named values: [DigitConstants].
extension type const Digit._(int value) implements int {
  /// The [Digit] with numeric [value], or `null` unless it's in `0`-`9`.
  static Digit? tryFrom(int value) => value >= 0 && value < 10 ? ._(value) : null;
}
