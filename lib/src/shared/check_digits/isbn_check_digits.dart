import 'package:collection/collection.dart';

import 'digit_values.dart';

const _gs1Modulus = 10;
const _gs1PlainWeight = 1; // weights alternate, and a 12-digit body starts on the plain one
const _gs1TripledWeight = 3;
const _isbn10Modulus = 11;
const _isbn10LeadingWeight = 10; // each later position counts for one less
const _isbn10TenValue = 10;
const _isbn10TenGlyph = 'X'; // ten has to fit in one character, so ISO 2108 spells it X

/// The GS1 mod-10 check digit for [twelveDigits], everything before an ISBN-13's check digit
/// (ISO 2108), assumed already separator-free.
///
/// Alternating from the left matches GS1's right-to-left rule only at twelve digits. Mod-10 also
/// misses a transposition of two adjacent digits differing by 5.
String isbn13CheckDigit(String twelveDigits) {
  final weightedSum = twelveDigits.codeUnits
      .mapIndexed(
        (position, codeUnit) =>
            decimalValue(codeUnit) * (position.isEven ? _gs1PlainWeight : _gs1TripledWeight),
      )
      .sum;

  return ((_gs1Modulus - weightedSum % _gs1Modulus) % _gs1Modulus).toString();
}

/// The ISO 2108 mod-11 check character for [nineDigits], everything before an ISBN-10's check
/// character, assumed already separator-free. `0`-`9`, or `X` where the value is ten.
String isbn10CheckDigit(String nineDigits) {
  final weightedSum = nineDigits.codeUnits
      .mapIndexed(
        (position, codeUnit) => decimalValue(codeUnit) * (_isbn10LeadingWeight - position),
      )
      .sum;
  final checkValue = (_isbn10Modulus - weightedSum % _isbn10Modulus) % _isbn10Modulus;

  return checkValue == _isbn10TenValue ? _isbn10TenGlyph : checkValue.toString();
}
