/// @docImport '../month.dart';
library;

import '../../shared/minted_failure.dart';

/// Why a [Month] refused its input. One variant: a closed set of twelve has one way to miss.
enum MonthFailure implements MintedFailure {
  /// The input does not name a month in `1`-`12`.
  notAMonth('not a month number 1-12');

  new(this.message);

  @override
  final String message;

  @override
  String get typeName => 'Month';
}
