const _asciiZero = 0x30;
const _asciiNine = 0x39;
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
  final rearranged = '$bban${countryCode}00';

  return (_modulus + 1 - _mod97(rearranged)).toString().padLeft(_checkDigitLength, '0');
}

int _mod97(String alphanumeric) {
  var remainder = 0;
  for (final codeUnit in alphanumeric.codeUnits) {
    final value = _digitValue(codeUnit);
    remainder = value < _letterOffset
        ? (remainder * _decimalShift + value) % _modulus
        : (remainder * _twoDigitShift + value) % _modulus;
  }

  return remainder;
}

/// The mod-97 value of a single character: `0`-`9` map to 0-9, `A`-`Z` to 10-35.
/// Any other character yields -1, so an invalid assembled IBAN fails validation downstream rather than here.
int _digitValue(int codeUnit) {
  if (codeUnit >= _asciiZero && codeUnit <= _asciiNine) return codeUnit - _asciiZero;
  if (codeUnit >= _asciiUpperA && codeUnit <= _asciiUpperZ) {
    return codeUnit - _asciiUpperA + _letterOffset;
  }

  return -1;
}
