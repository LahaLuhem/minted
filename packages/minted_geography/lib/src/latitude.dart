/// @docImport 'geo_coordinate.dart';
library;

import 'package:minted/internal.dart';

import 'longitude.dart';
import 'standards/coordinate_bounds.dart';

/// A latitude in decimal degrees, `-90` to `90`. Negative is south of the equator.
///
/// A door taking one cannot be handed an impossible degree, nor a [Longitude]: the swap is the bug
/// no range check catches, and this is where it stops compiling. A negative zero is cleared.
///
/// [value] is the degrees; the string form is `value.toString()`.
extension type const Latitude._(double value) {
  /// The [Latitude] of [degrees], or `null` outside `-90` to `90`. A `NaN` is outside, the bound
  /// being written as a positive test.
  static Latitude? tryFrom(num degrees) =>
      !isWithinBound(degrees, maxLatitude) ? null : ._(positiveZeroed(degrees.toDouble()));
}
