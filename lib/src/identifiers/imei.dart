// A validated IMEI is ASCII digits only.
// ignore_for_file: avoid-substring

import '../numerics/digit.dart';
import '../numerics/digits.dart';
import '../shared/check_digits/luhn_check_digit.dart';
import '../shared/encoding/digit_values.dart';
import '../shared/normalisation/normalisation.dart';
import '../shared/outcomes/parse_outcome.dart';
import 'failures/imei_failure.dart';

/// An IMEI (International Mobile Equipment Identity): validated for digits, the fifteen-digit
/// length, and the Luhn check digit. Identifies one piece of mobile equipment, not its subscriber.
/// Standard: [3GPP TS 23.003](https://www.3gpp.org/DynaReport/23003.htm).
///
/// Normalisation on parse: spaces and hyphens are stripped, so a printed IMEI and its compact form
/// compare equal. [formatted] rebuilds the printed grouping.
///
/// Rendered in full rather than masked: an IMEI is not a credential, and the systems holding one display
/// it. Why that differs from a card number: `APPENDIX.md#imei-value-type`.
///
/// {@example /example/minted_example.dart#imei}
extension type const Imei._(String value) {
  /// Builds an [Imei] from its [tac] and [serialNumber], computing the Luhn check digit, reporting
  /// the [ImeiFailure] when the parts don't form a valid IMEI.
  static ParseOutcome<ImeiFailure, Imei> fromComponents({
    required Digits tac,
    required Digits serialNumber,
  }) {
    final assembledImei = _withCheckDigit('${tac.asString}${serialNumber.asString}');
    final failure = _failureFor(assembledImei);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(assembledImei));
  }

  /// Parses [input] as an IMEI, or returns `null` when it fails the length, character, or Luhn tests.
  static Imei? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as an IMEI, reporting the [ImeiFailure] that says which check failed.
  static ParseOutcome<ImeiFailure, Imei> parse(String input) {
    final compactInput = compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(compactInput));
  }

  /// The eight-digit Type Allocation Code: which model of equipment this is, not which unit.
  String get tac => value.substring(0, _tacLength);

  /// The two leading digits of [tac], naming the body that allocated it (`35` is BABT, `01` PTCRB).
  String get reportingBodyIdentifier => value.substring(0, _reportingBodyLength);

  /// The six digits the manufacturer assigns to one unit of the model [tac] names.
  String get serialNumber => value.substring(_tacLength, _checkDigitIndex);

  /// The final digit, the Luhn check over the other fourteen.
  // The last character of a validated IMEI is always a digit, so tryParse cannot return null.
  Digit get checkDigit => .tryFrom(decimalValue(value.codeUnitAt(_checkDigitIndex)))!;

  /// The printed grouping, as a settings screen and the box both show it, e.g. `35-209900-176148-1`.
  String get formatted =>
      '$reportingBodyIdentifier-${value.substring(_reportingBodyLength, _tacLength)}'
      '-$serialNumber-${checkDigit.value}';

  static String _withCheckDigit(String bodyDigits) => '$bodyDigits${luhnCheckDigit(bodyDigits)}';

  // Why already-compacted input is not an IMEI, or null when it is one. The single gate parse and
  // fromComponents funnel through; widest check first, so the earliest wrong thing is named.
  static ImeiFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when compactInput.length != _length => ImeiWrongLength(compactInput.length),
    _ when !digitsOnly.hasMatch(compactInput) => const ImeiInvalidCharacters(),
    _ when !_checksumHolds(compactInput) => const ImeiChecksumFailed(),
    _ => null,
  };

  static bool _checksumHolds(String compactInput) =>
      compactInput.endsWith(luhnCheckDigit(compactInput.substring(0, _checkDigitIndex)));

  static const _length = 15;
  // The 2004 revision folded the two-digit Final Assembly Code into the TAC, so there is no separate
  // part between the TAC and the serial to expose.
  static const _tacLength = 8;
  static const _reportingBodyLength = 2;
  static const _checkDigitIndex = 14;
}
