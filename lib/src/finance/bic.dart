// A validated BIC is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

import '../shared/normalisation/normalisation.dart';
import '../shared/outcomes/parse_outcome.dart';
import '../shared/standards/iso_country_code.dart';
import 'failures/bic_failure.dart';

/// A BIC, better known as a SWIFT code: validated for structure and for a real ISO 3166-1 country.
/// Standard: [ISO 9362](https://en.wikipedia.org/wiki/ISO_9362).
///
/// Normalisation on parse: whitespace stripped, upper-cased, and the eight-character form folded to
/// eleven by appending the `XXX` primary office, so the two spellings of one office compare equal.
/// [bic8] rebuilds the short form.
///
/// ISO 9362 carries no checksum, so any well-formed code is accepted, held by an institution or not.
/// It also permits an [institutionCode] and [locationCode] wider than SWIFT itself issues;
/// [isSwiftRegistrable] reports that narrower shape rather than rejecting what the standard allows.
///
/// {@example /example/minted_example.dart#bic}
extension type const Bic._(String value) {
  /// Builds a [Bic] from its parts, [branchCode] defaulting to the `XXX` primary office, reporting
  /// the [BicFailure] when they don't form a valid BIC.
  static ParseOutcome<BicFailure, Bic> fromComponents({
    required String institutionCode,
    required String countryCode,
    required String locationCode,
    String branchCode = _primaryOfficeBranch,
  }) {
    final assembledBic = unspacedUpperCase('$institutionCode$countryCode$locationCode$branchCode');
    final failure = _failureFor(assembledBic);

    return failure != null
        ? ParseFailure(failure)
        : ParseSuccess(._(_withPrimaryOffice(assembledBic)));
  }

  /// Parses [input] as a BIC, or returns `null` when it fails the length, character, or country checks.
  static Bic? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a BIC, reporting the [BicFailure] that says which check failed.
  static ParseOutcome<BicFailure, Bic> parse(String input) {
    final compactInput = unspacedUpperCase(input);
    final failure = _failureFor(compactInput);

    return failure != null
        ? ParseFailure(failure)
        : ParseSuccess(._(_withPrimaryOffice(compactInput)));
  }

  /// The business party prefix (the first four characters): for a bank, its institution code.
  String get institutionCode => value.substring(0, _countryCodeStart);

  /// The ISO 3166-1 alpha-2 country code (the fifth and sixth characters).
  String get countryCode => value.substring(_countryCodeStart, _locationCodeStart);

  /// The business party suffix (the seventh and eighth): the city or entity within the country.
  /// By SWIFT convention its second character reads `0` for a test code, `1` for a passive
  /// participant and `2` for reverse billing, meanings ISO 9362 itself does not assign.
  String get locationCode => value.substring(_locationCodeStart, _branchCodeStart);

  /// The branch code (the last three characters), `XXX` for the primary office.
  String get branchCode => value.substring(_branchCodeStart);

  /// Whether this addresses the primary office rather than one of its branches.
  bool get isPrimaryOffice => branchCode == _primaryOfficeBranch;

  /// The eight-character short form, for the systems that write a BIC without its branch code.
  String get bic8 => value.substring(0, _branchCodeStart);

  /// Whether SWIFT could have issued this one. ISO 9362 allows digits in [institutionCode] and
  /// puts no restriction on [locationCode]; the registration authority still uses neither freedom.
  bool get isSwiftRegistrable => _swiftRegistrationForm.hasMatch(value);

  // The eight-character form addresses the primary office, which is what XXX spells at eleven.
  static String _withPrimaryOffice(String compactInput) =>
      compactInput.length == _bic8Length ? '$compactInput$_primaryOfficeBranch' : compactInput;

  // Why already-compacted input is not a BIC, or null when it is one. The single gate parse and
  // fromComponents funnel through; widest check first, so the earliest wrong thing is named.
  static BicFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when compactInput.length != _bic8Length && compactInput.length != _bic11Length =>
      BicWrongLength(compactInput.length),
    _ when !_alphanumeric.hasMatch(compactInput) => const BicInvalidCharacters(),
    // Digits landing in the country slot reach here too: they name no country either.
    _ when isoCountryCodeFor(_countryCodeOf(compactInput)) == null => BicUnknownCountry(
      _countryCodeOf(compactInput),
    ),
    _ => null,
  };

  static String _countryCodeOf(String compactInput) =>
      compactInput.substring(_countryCodeStart, _locationCodeStart);

  static final _alphanumeric = RegExp(r'^[A-Z0-9]+$');
  // The pre-2014 shape ISO 20022 retired and SWIFT still registers by, over the folded eleven.
  static final _swiftRegistrationForm = RegExp(r'^[A-Z]{6}[A-Z2-9][A-NP-Z0-9][A-Z0-9]{3}$');

  static const _bic8Length = 8;
  static const _bic11Length = 11;
  static const _countryCodeStart = 4;
  static const _locationCodeStart = 6;
  // The branch code is exactly what the short form leaves off, so it starts where that form ends.
  static const _branchCodeStart = _bic8Length;
  static const _primaryOfficeBranch = 'XXX';
}
