/// @docImport '../weekday.dart';
library;

import '../../shared/outcomes/minted_failure.dart';

/// Why a [Weekday] refused its input. One variant: a closed set of seven has one way to miss.
@Deprecated(
  'Weekday.tryFrom returns null instead, so nothing produces this. Removed in 2.0.0 (#44).',
)
enum WeekdayFailure implements MintedFailure {
  /// The input does not name a weekday in `1`-`7`.
  notAWeekday('not a weekday number 1-7');

  @Deprecated(
    'Weekday.tryFrom returns null instead, so nothing produces this. Removed in 2.0.0 (#44).',
  )
  new(this.message);

  @override
  final String message;

  @override
  String get typeName => 'Weekday';
}
