import 'package:minted/internal.dart';

const _asciiUpperA = 0x41;
const _asciiUpperZ = 0x5A;

/// The value `A` maps to, and so the floor above which a value spells two digits rather than one.
const letterOffset = 10;

/// The value of a single alphanumeric character: `0`-`9` map to 0-9, `A`-`Z` to 10-35.
///
/// One convention, two standards: ISO 13616 folds these into IBAN's mod-97, and ISO 6166 spells them
/// out before running ISIN's Luhn. Sits beside [decimalValue] in `shared/encoding/` rather than in
/// `check_digits/`, because only one of its two callers is a check-digit algorithm.
int alphanumericValue(int codeUnit) {
  final digitValue = decimalValue(codeUnit);
  if (digitValue >= 0) return digitValue;

  // Both callers gate on `[A-Z0-9]` before reaching here: `Iban.fromComponents` and
  // `Isin.fromComponents` take typed parts, and `Isin`'s checksum runs after its charset check.
  assert(
    codeUnit >= _asciiUpperA && codeUnit <= _asciiUpperZ,
    'alphanumericValue was handed $codeUnit, which is outside A-Z and 0-9',
  );

  return codeUnit - _asciiUpperA + letterOffset;
}

/// [input] with every letter replaced by the two digits spelling its [alphanumericValue], which is
/// what ISO 6166 hands to Luhn. Digits are left alone, so the result varies in length.
String expandedAlphanumerics(String input) => input.codeUnits.map(alphanumericValue).join();
