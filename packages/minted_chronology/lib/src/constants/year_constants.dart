part of '../year.dart';

/// The [Year] bounds, plus the 2 years [DateConstants] is built from.
abstract final class YearConstants() {
  /// Unused: the class is a namespace, never an instance.
  this;

  /// The earliest year, `0000`.
  static const min = Year._(0);

  /// The latest, `9999`.
  static const max = Year._(9999);

  /// The year POSIX's Epoch falls in.
  static const unixEpoch = Year._(1970);

  /// The year the Gregorian calendar began.
  static const gregorianStart = Year._(1582);
}
