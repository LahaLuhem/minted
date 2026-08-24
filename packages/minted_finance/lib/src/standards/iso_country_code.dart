import 'package:country_code/country_code.dart';

/// Whether [alpha2Code] names a country, case-insensitively.
///
/// Borrowed rather than tabulated: a list owned here would ship a clock
/// (`/APPENDIX.md#registry-data-ships-a-clock`). Alpha-2 only, so `GBR` is not a country here even
/// though `country_code` resolves it. [_kosovo] is the one addition.
bool isIsoCountryCode(String alpha2Code) {
  final upperCode = alpha2Code.toUpperCase();

  return upperCode == _kosovo || CountryCode.values.any((code) => code.alpha2 == upperCode);
}

/// ISO 3166 assigns Kosovo no code, but SWIFT issues `XK` BICs and IBANs against it.
const _kosovo = 'XK';
