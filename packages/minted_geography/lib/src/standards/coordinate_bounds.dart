/// The extent of the coordinate space, plus the one range check and the one diagnosis over it, for
/// the types that bound it or subdivide it.
///
/// Public within `lib/src/` and never re-exported: top-level `_` names are library-private in Dart,
/// so sharing them at all means dropping the underscore.
///
/// @docImport '../geo_coordinate.dart';
library;

import '../failures/geo_coordinate_failure.dart';

/// The largest latitude magnitude, reached at either pole.
const double maxLatitude = 90;

/// The largest longitude magnitude, reached at the antimeridian.
const double maxLongitude = 180;

/// Whether [degrees] is within `±bound`. A positive test, so a `NaN` falls out as outside.
bool isWithinBound(num degrees, double bound) => degrees >= -bound && degrees <= bound;

/// Why [latitude] or [longitude] leaves its range, or null when neither does. Shared by the text
/// doors, so a [GeoCoordinate] and a box diagnose the same degree the same way.
GeoCoordinateFailure? degreesFailure({required double latitude, required double longitude}) {
  if (!isWithinBound(latitude, maxLatitude)) return GeoCoordinateLatitudeOutOfRange(latitude);

  return isWithinBound(longitude, maxLongitude)
      ? null
      : GeoCoordinateLongitudeOutOfRange(longitude);
}
