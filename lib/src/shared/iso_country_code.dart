import 'package:collection/collection.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// The ISO 3166-1 alpha-2 country [alpha2Code] names, case-insensitively, or `null` for none.
///
/// Borrowed from `phone_numbers_parser` rather than carrying a table: 245 codes, `XK` included.
IsoCode? isoCountryCodeFor(String alpha2Code) {
  final upperCode = alpha2Code.toUpperCase();

  return IsoCode.values.firstWhereOrNull((code) => code.name == upperCode);
}
