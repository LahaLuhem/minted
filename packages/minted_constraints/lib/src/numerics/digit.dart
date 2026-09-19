/// @docImport 'digits.dart';
library;

/// A single decimal digit, `0`-`9`.
///
/// Where a validated whole exposes a digit-only part, that part is a [Digit] (or a [Digits] sequence),
/// so "these are digits" is a fact of the type rather than something every caller re-checks.
extension type const Digit._(int value) implements int {
  /// The [Digit] with numeric [value], or `null` unless it's in `0`-`9`.
  static Digit? tryFrom(int value) => value >= 0 && value < 10 ? ._(value) : null;

  /// The digit `0`.
  static const d0 = Digit._(0);

  /// The digit `1`.
  static const d1 = Digit._(1);

  /// The digit `2`.
  static const d2 = Digit._(2);

  /// The digit `3`.
  static const d3 = Digit._(3);

  /// The digit `4`.
  static const d4 = Digit._(4);

  /// The digit `5`.
  static const d5 = Digit._(5);

  /// The digit `6`.
  static const d6 = Digit._(6);

  /// The digit `7`.
  static const d7 = Digit._(7);

  /// The digit `8`.
  static const d8 = Digit._(8);

  /// The digit `9`.
  static const d9 = Digit._(9);
}
