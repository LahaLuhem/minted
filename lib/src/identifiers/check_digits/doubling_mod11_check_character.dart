import '../../shared/encoding/digit_values.dart';

const _modulus = 11;
const _doublingFactor = 2;
const _checkOffset = 12; // one more than the modulus, so a zero remainder yields a zero check
const _tenValue = 10;
const _tenGlyph = 'X'; // ten has to fit in one character

/// The ISO 7064 MOD 11-2 check character for [bodyDigits], assumed already separator-free. `0`-`9`,
/// or `X` where the value is ten.
///
/// Not interchangeable with `mod11_check_character.dart` despite the shared modulus and `X`: this
/// doubles a running total where that one weights by position, and they agree on nothing.
/// Why: `APPENDIX.md#isni-value-type`.
String doublingMod11CheckCharacter(String bodyDigits) {
  final total = bodyDigits.codeUnits.fold(
    0,
    (runningTotal, codeUnit) => (runningTotal + decimalValue(codeUnit)) * _doublingFactor,
  );
  final checkValue = (_checkOffset - total % _modulus) % _modulus;

  return checkValue == _tenValue ? _tenGlyph : checkValue.toString();
}
