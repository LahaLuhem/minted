// A validated IMEI is ASCII digits only.
// ignore_for_file: avoid-substring

import 'package:minted/internal.dart';
import 'package:minted/minted.dart';
import 'package:minted_constraints/minted_constraints.dart';

import 'failures/imei_failure.dart';

part 'constants/imei_constants.dart';
part 'helpers/imei_helpers.dart';

/// An IMEI (International Mobile Equipment Identity): names one piece of mobile kit, not its subscriber.
/// Standard: [3GPP TS 23.003](https://www.3gpp.org/DynaReport/23003.htm).
///
/// Parsing strips spaces and hyphens, so a printed IMEI and its compact form compare equal. [formatted]
/// puts the grouping back.
///
/// Shown in full, never masked. An IMEI isn't a credential. Why that differs from a card number:
/// `APPENDIX.md#imei-value-type`.
///
/// Named values: [ImeiConstants].
///
/// {@example /example/minted_identifiers_example.dart#imei}
extension type const Imei._(String value) {
  /// Builds an [Imei] from its [tac] and [serialNumber], working the Luhn check digit out.
  static ParseOutcome<ImeiFailure, Imei> fromComponents({
    required Digits tac,
    required Digits serialNumber,
  }) {
    final assembledImei = _withCheckDigit('${tac.asString}${serialNumber.asString}');
    final failure = _failureFor(assembledImei);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(assembledImei));
  }

  /// Parses [input], or `null` if it isn't an IMEI.
  static Imei? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input], reporting the [ImeiFailure] that says what went wrong.
  static ParseOutcome<ImeiFailure, Imei> parse(String input) {
    final compactInput = compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(compactInput));
  }

  /// The 8-digit Type Allocation Code: which model this is, not which unit.
  // A validated IMEI is all digits, so none of these 4 tryFroms can return null.
  Digits get tac => .tryFrom(decimalValues(value, 0, _tacLength))!;

  /// The first 2 digits of [tac], naming who allocated it (`35` is BABT, `01` PTCRB).
  Digits get reportingBodyIdentifier => .tryFrom(decimalValues(value, 0, _reportingBodyLength))!;

  /// The 6 digits the manufacturer gives one unit of the model [tac] names.
  Digits get serialNumber => .tryFrom(decimalValues(value, _tacLength, _checkDigitIndex))!;

  /// The last digit, the Luhn check over the other 14.
  Digit get checkDigit => .tryFrom(decimalValue(value.codeUnitAt(_checkDigitIndex)))!;

  /// The printed grouping, like `35-209900-176148-1`.
  String get formatted =>
      '${reportingBodyIdentifier.asString}-'
      '${value.substring(_reportingBodyLength, _tacLength)}'
      '-${serialNumber.asString}-${checkDigit.value}';

  // GSMA TS.06 §9 keeps the `00` prefix for test equipment, which cannot be supplied to the market.
}
