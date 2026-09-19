// A validated BIC is ASCII [A-Z0-9] only.
// ignore_for_file: avoid-substring

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'failures/bic_failure.dart';
import 'standards/iso_country_code.dart';

part 'helpers/bic_helpers.dart';

/// A BIC, better known as a SWIFT code. Standard: [ISO 9362](https://en.wikipedia.org/wiki/ISO_9362)
/// .
///
/// Parsing strips whitespace, upper-cases, and folds the 8-character form to 11 by adding the
/// `XXX` primary office, so both spellings of one office compare equal. [bic8] rebuilds the short form.
///
/// There's no checksum, so any well-formed code gets in, held by an institution or not. ISO 9362 also
/// allows an [institutionCode] and [locationCode] wider than SWIFT itself issues, and [isSwiftRegistrable]
/// reports that narrower shape rather than refusing what the standard allows.
///
/// {@example /example/minted_finance_example.dart#bic}
extension type const Bic._(String value) {
  /// Builds a [Bic] from its parts, a null [branchCode] meaning the `XXX` primary office.
  // Nullable rather than defaulted: a default must be const, and a constraint type has tryFrom.
  static ParseOutcome<BicFailure, Bic> fromComponents({
    required AsciiAlphanumerics institutionCode,
    required AsciiLetters countryCode,
    required AsciiAlphanumerics locationCode,
    AsciiAlphanumerics? branchCode,
  }) {
    // The parts cannot carry whitespace, so only case folds here.
    final assembledBic =
        '${institutionCode.value}${countryCode.value}${locationCode.value}'
                '${branchCode?.value ?? _primaryOfficeBranch}'
            .toUpperCase();
    final failure = _failureFor(assembledBic);

    return failure != null
        ? ParseFailure(failure)
        : ParseSuccess(._(_withPrimaryOffice(assembledBic)));
  }

  /// Parses [input], or `null` if it isn't a BIC.
  static Bic? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [BicFailure] that says what went wrong.
  static ParseOutcome<BicFailure, Bic> parse(String input) {
    final compactInput = unspacedUpperCase(input);
    final failure = _failureFor(compactInput);

    return failure != null
        ? ParseFailure(failure)
        : ParseSuccess(._(_withPrimaryOffice(compactInput)));
  }

  /// The business party prefix (the first 4 characters): for a bank, its institution code.
  // A validated BIC is `[A-Z0-9]` throughout, so no slice can be refused.
  AsciiAlphanumerics get institutionCode => .tryFrom(value.substring(0, _countryCodeStart))!;

  /// The ISO 3166-1 alpha-2 country code (the 5th and 6th characters).
  // Alpha-2 codes are letters, and parse refuses an unknown country.
  AsciiLetters get countryCode => .tryFrom(value.substring(_countryCodeStart, _locationCodeStart))!;

  /// The business party suffix, the 7th and 8th: the city or entity within the country. By SWIFT
  /// convention its 2nd character reads `0` for a test code, `1` for a passive participant and `2`
  /// for reverse billing, none of which ISO 9362 itself assigns.
  AsciiAlphanumerics get locationCode =>
      .tryFrom(value.substring(_locationCodeStart, _branchCodeStart))!;

  /// The branch code (the last 3 characters), `XXX` for the primary office.
  AsciiAlphanumerics get branchCode => .tryFrom(value.substring(_branchCodeStart))!;

  /// Whether this addresses the primary office rather than one of its branches.
  bool get isPrimaryOffice => branchCode.value == _primaryOfficeBranch;

  /// The 8-character short form, for the systems that write a BIC without its branch code.
  AsciiAlphanumerics get bic8 => .tryFrom(value.substring(0, _branchCodeStart))!;

  /// Whether SWIFT could have issued this one. ISO 9362 allows digits in [institutionCode] and puts
  /// no bound on [locationCode], and the registration authority uses neither freedom.
  bool get isSwiftRegistrable => _swiftRegistrationForm.hasMatch(value);

  // Habits, not standards: ISO 9362 names no code, and `BANK` is no institution.

  /// A German example code.
  static const exampleDe = Bic._('BANKDEFFXXX');

  /// A Belgian one, for an example needing both ends of a payment.
  static const exampleBe = Bic._('BANKBEBBXXX');
}
