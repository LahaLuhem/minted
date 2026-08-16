/// Calendar dates and durations as well-modelled value types.
///
/// Every type is built on "parse, don't validate": build one through `parse`
/// (returning a `ParseOutcome`) or `tryParse` (returning `null`), never a public
/// constructor, so any instance that exists is guaranteed well-formed.
library;

export 'src/date.dart';
export 'src/failures/date_failure.dart';
export 'src/failures/iso8601_duration_failure.dart';
export 'src/failures/month_failure.dart';
export 'src/iso8601_duration.dart';
export 'src/month.dart';
export 'src/weekday.dart';
