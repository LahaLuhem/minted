/// @docImport '../month.dart';
library;

import 'package:minted/minted.dart';

/// Why a [Month] refused its input. A closed set of 12 has one way to miss.
enum MonthFailure(@override final String message) implements MintedFailure {
  /// The input doesn't name a month in `1`-`12`.
  notAMonth('not a month number 1-12');

  @override
  String get typeName => 'Month';
}
