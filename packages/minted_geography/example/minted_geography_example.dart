// This example prints to stdout so it runs standalone via `dart run`.
// ignore_for_file: avoid_print

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
}
