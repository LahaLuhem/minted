/// @docImport '../weekday.dart';
library;

import '../../shared/minted_failure.dart';

/// Why a [Weekday] refused its input. One variant: a closed set of seven has one way to miss.
enum WeekdayFailure implements MintedFailure {
  /// The input does not name a weekday in `1`-`7`.
  notAWeekday('not a weekday number 1-7');

  new(this.message);

  @override
  final String message;

  @override
  String get typeName => 'Weekday';
}
