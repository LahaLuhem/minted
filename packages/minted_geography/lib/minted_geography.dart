/// Geographic coordinates as well-modelled value types.
///
/// Every type is built on "parse, don't validate": no public constructor, so an instance that exists
/// is well-formed. `parse` reports why it refused, where `tryParse` just hands back `null`.
library;

export 'src/failures/geo_bounds_failure.dart';
export 'src/failures/geo_coordinate_failure.dart';
export 'src/failures/geohash_failure.dart';
export 'src/geo_bounds.dart';
export 'src/geo_coordinate.dart';
export 'src/geohash.dart';
export 'src/latitude.dart';
export 'src/longitude.dart';
