/// The extent of the coordinate space, for the types that bound it or subdivide it.
///
/// Public within `lib/src/` and never re-exported: top-level `_` names are library-private in Dart,
/// so sharing them at all means dropping the underscore.
library;

/// The largest latitude magnitude, reached at either pole.
const double maxLatitude = 90;

/// The largest longitude magnitude, reached at the antimeridian.
const double maxLongitude = 180;
