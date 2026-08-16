import 'package:country_code/country_code.dart';

/// Whether [alpha2Code] names a country, case-insensitively.
///
/// Borrowed from `country_code` rather than carrying a table: a list owned here would ship a clock
/// (`APPENDIX.md#registry-data-ships-a-clock`). Matched on alpha-2 alone, so a three-letter code is
/// not a country here even though `country_code` resolves one.
///
/// [_kosovo] is the single addition, and the reason this is not a bare delegation.
bool isIsoCountryCode(String alpha2Code) {
  final upperCode = alpha2Code.toUpperCase();

  return upperCode == _kosovo || CountryCode.values.any((code) => code.alpha2 == upperCode);
}

/// ISO 3166 assigns Kosovo no code, but SWIFT's BIC and IBAN registries both use `XK`, so the
/// registry this validates against says yes where ISO says nothing.
const _kosovo = 'XK';
