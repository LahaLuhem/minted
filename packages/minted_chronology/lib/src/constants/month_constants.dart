// A Month erases to its int, so the lint offers an unrelated int constant in its place.
// ignore_for_file: use_named_constants

part of '../month.dart';

/// Every [Month].
abstract final class MonthConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// January, month `1`.
  static const january = Month._(1);

  /// February, month `2`.
  static const february = Month._(2);

  /// March, month `3`.
  static const march = Month._(3);

  /// April, month `4`.
  static const april = Month._(4);

  /// May, month `5`.
  static const may = Month._(5);

  /// June, month `6`.
  static const june = Month._(6);

  /// July, month `7`.
  static const july = Month._(7);

  /// August, month `8`.
  static const august = Month._(8);

  /// September, month `9`.
  static const september = Month._(9);

  /// October, month `10`.
  static const october = Month._(10);

  /// November, month `11`.
  static const november = Month._(11);

  /// December, month `12`.
  static const december = Month._(12);
}
