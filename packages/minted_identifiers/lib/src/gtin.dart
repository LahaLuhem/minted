// A validated GTIN is ASCII digits only.
// ignore_for_file: avoid-substring

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'check_digits/gs1_check_digit.dart';
import 'failures/gtin_failure.dart';

part 'constants/gtin_constants.dart';
part 'helpers/gtin_helpers.dart';

/// A GTIN (Global Trade Item Number): the number inside an EAN-8, UPC-A, EAN-13 or ITF-14 barcode. Standard:
/// [GS1 GTIN](https://www.gs1.org/standards/id-keys/gtin).
///
/// Parsing strips spaces and hyphens and pads to 14 digits, so all 4 lengths of one item compare
/// equal. [shortestForm], [gtin13], [gtin12] and [gtin8] spell it back shorter.
///
/// No company-prefix split: that boundary lives in GS1's registry, not in the digits.
///
/// Named values: [GtinConstants].
///
/// {@example /example/minted_identifiers_example.dart#gtin}
extension type const Gtin._(String value) {
  /// Builds a [Gtin] from [bodyDigits], the number minus its check digit, working that digit out.
  static ParseOutcome<GtinFailure, Gtin> fromBody(Digits bodyDigits) {
    final assembledGtin = _withCheckDigit(bodyDigits.asString);
    final failure = _failureFor(assembledGtin);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(_toGtin14(assembledGtin)));
  }

  /// Parses [input], or `null` if it isn't a GTIN.
  static Gtin? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [GtinFailure] that says what went wrong.
  static ParseOutcome<GtinFailure, Gtin> parse(String input) {
    final compactInput = compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(_toGtin14(compactInput)));
  }

  /// The same number as a GTIN-13 (EAN-13), or `null` if it needs more digits than that.
  String? get gtin13 => _atLength(_length13);

  /// The same number as a GTIN-12 (UPC-A), or `null` if it needs more digits than that.
  String? get gtin12 => _atLength(_length12);

  /// The same number as a GTIN-8 (EAN-8), or `null` if it needs more digits than that.
  String? get gtin8 => _atLength(_length8);

  /// The shortest of the 4 lengths this fits, which is what the barcode carries. [value] is what
  /// a database column should hold.
  String get shortestForm => gtin8 ?? gtin12 ?? gtin13 ?? value;

  /// The last digit, the GS1 mod-10 check over the other 13.
  // A validated GTIN ends in a digit, so tryFrom cannot return null.
  Digit get checkDigit => .tryFrom(decimalValue(value.codeUnitAt(_checkDigitIndex)))!;

  // Null when dropping the leading digits would lose a significant one.
  String? _atLength(int length) => value.substring(0, _length14 - length).contains(_nonZeroDigit)
      ? null
      : value.substring(_length14 - length);
}
