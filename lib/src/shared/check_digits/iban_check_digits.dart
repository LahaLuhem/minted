import '../digit_values.dart';

const _asciiUpperA = 0x41;
const _asciiUpperZ = 0x5A;
const _letterOffset = 10; // 'A' converts to 10, per ISO 13616.
const _modulus = 97;
const _decimalShift = 10; // fold in one digit
const _twoDigitShift = 100; // a converted letter is two digits
const _checkDigitLength = 2;

/// The two ISO 7064 mod-97-10 check digits for an IBAN with [countryCode] and [bban] (ISO 13616),
/// both assumed already upper-cased and separator-free.
///
/// The digits are chosen so the assembled IBAN satisfies the mod-97 check
String ibanCheckDigits(String countryCode, String bban) {
  final mod97Input = '$bban${countryCode}00';

  return (_modulus + 1 - _mod97(mod97Input)).toString().padLeft(_checkDigitLength, '0');
}

int _mod97(String alphanumeric) => alphanumeric.codeUnits
    .map(_alphanumericValue)
    .fold(
      0,
      // a digit shifts the remainder one decimal place, a converted letter two, because
      // `A`-`Z` map to the two-digit values 10-35
      (remainder, characterValue) => characterValue < _letterOffset
          ? (remainder * _decimalShift + characterValue) % _modulus
          : (remainder * _twoDigitShift + characterValue) % _modulus,
    );

/// The mod-97 value of a single character: `0`-`9` map to 0-9, `A`-`Z` to 10-35.
/// Any other character yields -1, so an invalid assembled IBAN fails validation downstream rather than here.
int _alphanumericValue(int codeUnit) {
  final digitValue = decimalValue(codeUnit);
  if (digitValue >= 0) return digitValue;
  if (codeUnit >= _asciiUpperA && codeUnit <= _asciiUpperZ) {
    return codeUnit - _asciiUpperA + _letterOffset;
  }

  return -1;
}
