import 'package:collection/collection.dart';

import 'digit_values.dart';

const _modulus = 11;
const _leadingWeight = 10; // each later position counts for one less
const _tenValue = 10;
const _tenGlyph = 'X'; // ten has to fit in one character, so ISO 2108 spells it X

/// The ISO 2108 mod-11 check character for [nineDigits], everything before an ISBN-10's check
/// character, assumed already separator-free. `0`-`9`, or `X` where the value is ten.
///
/// Only the ten-digit form uses this; ISBN-13 shares GS1's mod-10 (`gs1_check_digit.dart`).
String isbn10CheckDigit(String nineDigits) {
  final weightedSum = nineDigits.codeUnits
      .mapIndexed((position, codeUnit) => decimalValue(codeUnit) * (_leadingWeight - position))
      .sum;
  final checkValue = (_modulus - weightedSum % _modulus) % _modulus;

  return checkValue == _tenValue ? _tenGlyph : checkValue.toString();
}
