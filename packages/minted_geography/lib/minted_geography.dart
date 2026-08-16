/// Geographic coordinates as well-modelled value types.
///
/// Every type is built on "parse, don't validate": build one through `parse`
/// (returning a `ParseOutcome`) or `tryParse` (returning `null`), never a public
/// constructor, so any instance that exists is guaranteed well-formed.
library;

export 'src/failures/geo_coordinate_failure.dart';
export 'src/geo_coordinate.dart';
