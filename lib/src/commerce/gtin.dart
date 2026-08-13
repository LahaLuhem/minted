// A validated GTIN is ASCII digits only.
// ignore_for_file: avoid-substring

import '../numerics/digit.dart';
import '../numerics/digits.dart';
import '../shared/check_digits/gs1_check_digit.dart';
import '../shared/normalisation/normalisation.dart';
import '../shared/outcomes/minted_format_exception.dart';
import '../shared/outcomes/parse_outcome.dart';
import 'failures/gtin_failure.dart';

/// A GTIN (Global Trade Item Number): validated for digits, one of the four GS1 lengths, and the
/// GS1 mod-10 check digit. The number inside an EAN-8, UPC-A, EAN-13 or ITF-14 barcode.
/// Standard: [GS1 GTIN](https://www.gs1.org/standards/id-keys/gtin).
///
/// Normalisation on parse: spaces and hyphens are stripped and the number is zero-padded to
/// fourteen digits, so all four lengths of one trade item compare equal. Padding cannot disturb the
/// check digit, because GS1 weights from the right. [shortestForm], [gtin13], [gtin12] and [gtin8]
/// spell it back shorter.
///
/// Not split into company prefix and item reference: that boundary comes from GS1's prefix
/// registry, not the digits.
///
/// {@example /example/minted_example.dart#gtin}
extension type const Gtin._(String value) {
  /// Builds a [Gtin] from [bodyDigits], the number without its check digit, computing that digit.
  /// Throws [MintedFormatException] when the parts don't form a valid GTIN. For assembling from a
  /// known-valid source.
  static Gtin fromBody(Digits bodyDigits) {
    final body = bodyDigits.asString;
    final assembledGtin = _withCheckDigit(body);
    final failure = _failureFor(assembledGtin);

    return failure != null
        ? throw MintedFormatException.from(failure, body)
        : ._(_toGtin14(assembledGtin));
  }

  /// Parses [input] as a GTIN, or returns `null` when it fails the length, character, or check-digit
  /// tests. All four lengths are accepted; the result is always fourteen digits.
  static Gtin? tryParse(String input) => parse(input).getOrNull();

  /// Parses [input] as a GTIN, reporting the [GtinFailure] that says which check failed.
  static ParseOutcome<GtinFailure, Gtin> parse(String input) {
    final compactInput = compact(input);
    final failure = _failureFor(compactInput);

    return failure != null ? ParseFailure(failure) : ParseSuccess(._(_toGtin14(compactInput)));
  }

  /// The same number as a GTIN-13 (EAN-13), or `null` when it needs all fourteen digits.
  String? get gtin13 => _atLength(_length13);

  /// The same number as a GTIN-12 (UPC-A), or `null` when it needs more digits than that.
  String? get gtin12 => _atLength(_length12);

  /// The same number as a GTIN-8 (EAN-8), or `null` when it needs more digits than that.
  String? get gtin8 => _atLength(_length8);

  /// The shortest of the four GS1 lengths this number fits, which is [value] when it needs all
  /// fourteen digits. What a barcode carries; [value] is what a database column should hold.
  String get shortestForm => gtin8 ?? gtin12 ?? gtin13 ?? value;

  /// The final digit, the GS1 mod-10 check over the other thirteen.
  // The last character of a validated GTIN is always a digit, so tryParse cannot return null.
  Digit get checkDigit => .tryParse(value[_checkDigitIndex])!;

  // The same number spelled at [length], or null when dropping the leading digits would lose a
  // significant one.
  String? _atLength(int length) => value.substring(0, _length14 - length).contains(_nonZeroDigit)
      ? null
      : value.substring(_length14 - length);

  static String _withCheckDigit(String bodyDigits) => '$bodyDigits${gs1CheckDigit(bodyDigits)}';

  // GS1's own rule for storing every length in one field. Lossless because the weights run from the
  // right, so the added zeros neither carry weight nor shift another digit's.
  static String _toGtin14(String compactInput) => compactInput.padLeft(_length14, zeroPad);

  // Why already-compacted input is not a GTIN, or null when it is one. The single gate parse and
  // fromBody funnel through; widest check first, so the earliest wrong thing is named.
  static GtinFailure? _failureFor(String compactInput) => switch (compactInput) {
    _ when !_lengths.contains(compactInput.length) => GtinWrongLength(compactInput.length),
    _ when !digitsOnly.hasMatch(compactInput) => const GtinInvalidCharacters(),
    _ when !_checksumHolds(compactInput) => const GtinChecksumFailed(),
    _ => null,
  };

  static bool _checksumHolds(String compactInput) =>
      compactInput.endsWith(gs1CheckDigit(compactInput.substring(0, compactInput.length - 1)));

  static final _nonZeroDigit = RegExp('[^$zeroPad]');

  // GTIN-8, GTIN-12 (UPC-A), GTIN-13 (EAN-13) and GTIN-14. GS1 defines no others.
  static const _length8 = 8;
  static const _length12 = 12;
  static const _length13 = 13;
  static const _length14 = 14;
  static const _lengths = {_length8, _length12, _length13, _length14};
  static const _checkDigitIndex = 13;
}
