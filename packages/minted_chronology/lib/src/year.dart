/// @docImport 'date.dart';
library;

import 'package:minted_constraints/minted_constraints.dart';

part 'constants/year_constants.dart';

/// A calendar year, `0000` to `9999`.
///
/// Every year is a [Uint], and `implements Uint` lets one go wherever a `Uint` is wanted, never the
/// reverse. `int` still comes through, by way of `Uint`.
///
/// The range is what [Date] renders as `YYYY`, not a claim about history: the calendar is proleptic,
/// so year `0000` parses like any other.
///
/// Named values: [YearConstants].
extension type const Year._(int value) implements Uint {
  /// The [Year] with numeric [value], or `null` unless it's in `0000`-`9999`.
  static Year? tryFrom(int value) =>
      value < YearConstants.min || value > YearConstants.max ? null : ._(value);
}
