// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

import 'package:minted_constraints/minted_constraints.dart';
import 'package:minted_geography/minted_geography.dart';

void main() {
  // `GeoCoordinate` names the pair, because a swapped latitude and longitude is a type bug no range
  // check catches. ISO 6709 picks the unit by field width, and all three widths fold to degrees.
  // #region geo
  final eiffelTower = GeoCoordinate.tryParse('+48.8577+002.295/')!;
  print(eiffelTower.latitude); // 48.8577
  print(eiffelTower.iso6709); // +48.8577+002.295/  (canonical form)
  print(eiffelTower.sexagesimal); // 48°51′27.72″N 2°17′42″E  (display form)
  print(GeoCoordinate.tryParse('+5012-00010/')?.latitude); // 50.2  (degrees and minutes)
  print(GeoCoordinate.tryParse('+46+2/')); // null (an unpadded longitude is a different location)
  // #endregion

  // `Geohash` names a cell, not a point, so the round trip through one coordinate is not identity.
  // #region geohash
  final cell = Geohash.from(coordinate: eiffelTower, precision: NaturalNumber.tryFrom(5)!);
  print(cell.value); // u09tu  (canonical form: trimmed, lower-cased)
  print(cell.centre.iso6709); // +48.84521484375+002.30712890625/  (the cell centre, not the tower)
  print(Geohash.from(coordinate: cell.centre, precision: NaturalNumber.tryFrom(5)!)); // u09tu
  print(Geohash.tryParse('ezsa2')); // null ('a' is not in the geohash alphabet)
  // #endregion

  // `GeoBounds` keeps the antimeridian crossing a fact rather than a convention: west past east is
  // how RFC 7946 §5.2 writes it, and a `west <= east` check would refuse the box outright.
  // #region bounds
  final fiji = GeoBounds.tryParse('170,-45,-170,-35')!;
  print(fiji.crossesAntimeridian); // true
  print(fiji.contains(GeoCoordinate.tryFrom(latitude: -40, longitude: 179)!)); // true
  print(fiji.contains(GeoCoordinate.tryFrom(latitude: -40, longitude: 0)!)); // false (the long way)
  print(GeoBounds.tryParse('[-180, -90, 180, 90]')?.bbox); // -180.0,-90.0,180.0,90.0 (the world)
  // #endregion
}
