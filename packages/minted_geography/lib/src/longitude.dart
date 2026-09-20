/// @docImport 'geo_coordinate.dart';
library;

import 'package:minted/internal.dart';

import 'latitude.dart';
import 'standards/coordinate_bounds.dart';

/// A longitude in decimal degrees, `-180` to `180`. Negative is west of the prime meridian.
///
/// A door taking one can't be handed an impossible degree, nor a [Latitude]. The swap is the bug no
/// range check catches, and this is where it stops compiling. A negative zero is cleared.
///
/// `-180` is kept as written: the same meridian as `+180` for a point, but a different edge for a box,
/// so that fold belongs to [GeoCoordinate].
extension type const Longitude._(double value) implements double {
  /// The [Longitude] of [degrees], or `null` outside `-180` to `180`. A `NaN` is outside, the bound
  /// being written as a positive test.
  static Longitude? tryFrom(num degrees) =>
      !isWithinBound(degrees, maxLongitude) ? null : ._(positiveZeroed(degrees.toDouble()));

  /// The western bound, kept distinct from [max] as the class dartdoc explains.
  static const min = Longitude._(-maxLongitude);

  /// The eastern bound.
  static const max = Longitude._(maxLongitude);
}
