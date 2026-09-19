// A validated BIC is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

part of '../bic.dart';

// The 8-character form addresses the primary office, which is what XXX spells at 11.
String _withPrimaryOffice(String compactInput) =>
    compactInput.length != _bic8Length ? compactInput : '$compactInput$_primaryOfficeBranch';

// The one gate parse and fromComponents both go through. Widest check first, so the earliest wrong
// thing gets named.
BicFailure? _failureFor(String compactInput) => switch (compactInput) {
  _ when compactInput.length != _bic8Length && compactInput.length != _bic11Length =>
    BicWrongLength(compactInput.length),
  _ when !_alphanumeric.hasMatch(compactInput) => const BicInvalidCharacters(),
  // Digits landing in the country slot reach here too: they name no country either.
  _ when !isIsoCountryCode(_countryCodeOf(compactInput)) => BicUnknownCountry(
    _countryCodeOf(compactInput),
  ),
  _ => null,
};

String _countryCodeOf(String compactInput) =>
    compactInput.substring(_countryCodeStart, _locationCodeStart);

final _alphanumeric = RegExp(r'^[A-Z0-9]+$');
// The pre-2014 shape ISO 20022 retired and SWIFT still registers by, over the folded 11.
final _swiftRegistrationForm = RegExp(r'^[A-Z]{6}[A-Z2-9][A-NP-Z0-9][A-Z0-9]{3}$');

const _bic8Length = 8;
const _bic11Length = 11;
const _countryCodeStart = 4;
const _locationCodeStart = 6;
// The branch code is exactly what the short form leaves off, so it starts where that form ends.
const _branchCodeStart = _bic8Length;
const _primaryOfficeBranch = 'XXX';
