import 'digit_values.dart';

const _asciiUpperA = 0x41;
const _asciiUpperZ = 0x5A;

/// The value `A` maps to, and so the floor above which a value spells two digits rather than one.
const letterOffset = 10;

/// The value of a single alphanumeric character: `0`-`9` map to 0-9, `A`-`Z` to 10-35. Anything
/// else yields -1, so junk fails validation downstream rather than throwing here.
///
/// One convention, two standards: ISO 13616 folds these into IBAN's mod-97, and ISO 6166 spells
/// them out before running ISIN's Luhn. Sits beside [decimalValue] in `shared/` rather than in
/// `check_digits/`, because only one of its two callers is a check-digit algorithm.
int alphanumericValue(int codeUnit) {
  final digitValue = decimalValue(codeUnit);
  if (digitValue >= 0) return digitValue;
  if (codeUnit >= _asciiUpperA && codeUnit <= _asciiUpperZ) {
    return codeUnit - _asciiUpperA + letterOffset;
  }

  return -1;
}

/// [input] with every letter replaced by the two digits spelling its [alphanumericValue], which is
/// what ISO 6166 hands to Luhn. Digits are left alone, so the result varies in length.
///
/// An unrecognised character survives unchanged rather than becoming `-1`, so the caller's charset
/// check still sees it and rejects the input for the right reason.
String expandedAlphanumerics(String input) => input.codeUnits.map(_expandedCodeUnit).join();

String _expandedCodeUnit(int codeUnit) {
  final value = alphanumericValue(codeUnit);

  return value < 0 ? String.fromCharCode(codeUnit) : '$value';
}
